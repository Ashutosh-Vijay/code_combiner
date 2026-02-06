import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:fluent_ui/fluent_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme.dart'; 

enum FileType { text, binary }
enum ProjectType { standard, muleSoft, python, react }

class FileInfo {
  final String path;
  final int size;
  final FileType type;
  bool isSelected = true;
  
  FileInfo(this.path, this.size, this.type);

  String get fileName => p.basename(path);
  
  int get estimatedTokens => type == FileType.text ? (size / 4).ceil() : 0;
  
  String get statString {
    if (size < 1024) return "$size B";
    if (size < 1024 * 1024) return "${(size / 1024).toStringAsFixed(1)} KB";
    return "${(size / (1024 * 1024)).toStringAsFixed(1)} MB";
  }
}

class AppState extends ChangeNotifier {
  String? selectedPath;
  List<FileInfo> files = [];
  bool isScanning = false;
  bool isProcessing = false;
  
  // -- Settings --
  ProjectType projectType = ProjectType.standard;
  bool wrapInXml = true;
  
  // Theme Settings
  ThemeMode _themeMode = ThemeMode.dark;
  bool _useGlass = true;
  ThemeFlavor _flavor = ThemeFlavor.standard;

  // -- Exclusions State --
  bool useGitIgnore = true;
  
  // CONSTANTS for Defaults
  static const List<String> defaultFolders = [
    '.git', '.vscode', '.idea', '.gradle', 
    'node_modules', 'build', 'dist', '.next', 
    'windows', 'android', 'ios', 'linux', 'macos', 'web',
    '__pycache__', 'coverage'
  ];

  static const List<String> defaultPatterns = [
    '*.png', '*.jpg', '*.jpeg', '*.gif', '*.ico', '*.svg', 
    '*.pdf', '*.zip', '*.tar', '*.gz', '*.7z', '*.rar', 
    '*.lock', '*.mp4', '*.mp3', '*.wav', '*.exe', '*.dll', '*.so', '*.dylib', '*.bin'
  ];

  List<String> excludedFolderNames = List.from(defaultFolders);
  List<String> excludedPatterns = List.from(defaultPatterns);
  List<String> excludedFiles = [];

  // -- Search State --
  String _searchFilter = "";

  ThemeMode get themeMode => _themeMode;
  bool get useGlass => _useGlass;
  ThemeFlavor get flavor => _flavor;

  // -- Data Access --
  
  // Returns filtered list for UI rendering
  List<FileInfo> get filteredFiles {
    if (_searchFilter.isEmpty) return files;
    final lowerTerm = _searchFilter.toLowerCase();
    return files.where((f) {
      return f.path.toLowerCase().contains(lowerTerm);
    }).toList();
  }

  // -- Stats --
  int get selectedCount => files.where((f) => f.isSelected).length;

  int get totalTokens => files
      .where((f) => f.isSelected)
      .fold(0, (sum, f) => sum + f.estimatedTokens);

  String get totalSize {
    int bytes = files.where((f) => f.isSelected).fold(0, (sum, f) => sum + f.size);
    if (bytes < 1024 * 1024) return "${(bytes / 1024).toStringAsFixed(1)} KB";
    return "${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB";
  }

  // --- PERSISTENCE ---
  
  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Theme
    int themeIdx = prefs.getInt('themeMode') ?? 1; // 1 = dark
    _themeMode = ThemeMode.values[themeIdx];
    
    _useGlass = prefs.getBool('useGlass') ?? true;
    
    int flavorIdx = prefs.getInt('flavor') ?? 0;
    _flavor = ThemeFlavor.values[flavorIdx];

    // Config
    int projIdx = prefs.getInt('projectType') ?? 0;
    projectType = ProjectType.values[projIdx];
    
    wrapInXml = prefs.getBool('wrapInXml') ?? true;
    useGitIgnore = prefs.getBool('useGitIgnore') ?? true;

    // Exclusions
    excludedFolderNames = prefs.getStringList('excludedFolders') ?? List.from(defaultFolders);
    excludedPatterns = prefs.getStringList('excludedPatterns') ?? List.from(defaultPatterns);
    excludedFiles = prefs.getStringList('excludedFiles') ?? [];

    // FIXED: Load Last Opened Folder
    String? lastPath = prefs.getString('lastFolder');
    if (lastPath != null && Directory(lastPath).existsSync()) {
      selectedPath = lastPath;
      // Auto-scan on boot so you see files immediately
      scanFiles(); 
    }

    notifyListeners();
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    await prefs.setInt('themeMode', _themeMode.index);
    await prefs.setBool('useGlass', _useGlass);
    await prefs.setInt('flavor', _flavor.index);
    await prefs.setInt('projectType', projectType.index);
    await prefs.setBool('wrapInXml', wrapInXml);
    await prefs.setBool('useGitIgnore', useGitIgnore);
    
    // FIXED: Save Current Folder
    if (selectedPath != null) {
      await prefs.setString('lastFolder', selectedPath!);
    }
    
    await prefs.setStringList('excludedFolders', excludedFolderNames);
    await prefs.setStringList('excludedPatterns', excludedPatterns);
    await prefs.setStringList('excludedFiles', excludedFiles);
  }

  // -- Actions --

  void setSearchFilter(String val) {
    _searchFilter = val;
    notifyListeners();
  }

  void resetExclusionsToDefault() {
    excludedFolderNames = List.from(defaultFolders);
    excludedPatterns = List.from(defaultPatterns);
    excludedFiles.clear();
    useGitIgnore = true;
    _saveSettings();
    notifyListeners();
    if (selectedPath != null) scanFiles();
  }

  void toggleAllFiles(bool selected) {
    // We toggle ALL files, not just filtered ones, or users might get confused.
    // Alternatively, change to filteredFiles if you only want to select visible ones.
    // For now, global toggle is safer context-wise.
    for (var f in files) {
      f.isSelected = selected;
    }
    notifyListeners();
  }

  void excludeUnselectedFiles() {
    final unselected = files.where((f) => !f.isSelected).toList();
    if (unselected.isEmpty) return;

    for (var f in unselected) {
      if (!excludedFiles.contains(f.path)) {
        excludedFiles.insert(0, f.path);
      }
    }
    _saveSettings();
    scanFiles();
  }

  void addExcludedFolder(String folder) {
    if (!excludedFolderNames.contains(folder)) {
      excludedFolderNames.insert(0, folder);
      _saveSettings();
      notifyListeners();
      if (selectedPath != null) scanFiles();
    }
  }

  Future<void> pickExcludedFolder() async {
    String? path = await FilePicker.platform.getDirectoryPath();
    if (path != null) {
      String name = p.basename(path);
      addExcludedFolder(name);
    }
  }

  void removeExcludedFolder(String folder) {
    excludedFolderNames.remove(folder);
    _saveSettings();
    notifyListeners();
    if (selectedPath != null) scanFiles();
  }

  void addExcludedPattern(String pattern) {
    if (!excludedPatterns.contains(pattern)) {
      excludedPatterns.insert(0, pattern);
      _saveSettings();
      notifyListeners();
      if (selectedPath != null) scanFiles();
    }
  }

  void removeExcludedPattern(String pattern) {
    excludedPatterns.remove(pattern);
    _saveSettings();
    notifyListeners();
    if (selectedPath != null) scanFiles();
  }

  Future<void> pickExcludedFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result != null) {
      String path = result.files.single.path!;
      if (!excludedFiles.contains(path)) {
        excludedFiles.insert(0, path);
        _saveSettings();
        notifyListeners();
        if (selectedPath != null) scanFiles();
      }
    }
  }

  void removeExcludedFile(String path) {
    excludedFiles.remove(path);
    _saveSettings();
    notifyListeners();
    if (selectedPath != null) scanFiles();
  }

  void toggleGitIgnore(bool val) {
    useGitIgnore = val;
    _saveSettings();
    notifyListeners();
    if (selectedPath != null) scanFiles();
  }

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    _saveSettings();
    notifyListeners();
  }

  void toggleGlass(bool value) {
    _useGlass = value;
    _saveSettings();
    notifyListeners();
  }

  void setThemeFlavor(ThemeFlavor flavor) {
    _flavor = flavor;
    if (flavor == ThemeFlavor.pitchBlack) {
      _useGlass = false;
    } else {
      _useGlass = true;
    }
    _saveSettings();
    notifyListeners();
  }

  void setProjectType(ProjectType type) {
    projectType = type;
    _saveSettings();
    notifyListeners();
    if (selectedPath != null) scanFiles();
  }

  void setPathFromDrop(String path) {
    selectedPath = path;
    // Auto-save when path changes via drop
    _saveSettings();
    notifyListeners();
    scanFiles();
  }

  void toggleXml(bool val) {
    wrapInXml = val;
    _saveSettings();
    notifyListeners();
  }

  void removeFile(FileInfo file) {
    files.remove(file);
    notifyListeners();
  }

  void toggleFileSelection(FileInfo file, bool selected) {
    file.isSelected = selected;
    notifyListeners();
  }

  Future<void> pickFolder() async {
    String? result = await FilePicker.platform.getDirectoryPath();
    if (result != null) {
      selectedPath = result;
      // Auto-save when path changes via picker
      _saveSettings();
      notifyListeners();
      scanFiles();
    }
  }

  Future<void> scanFiles() async {
    if (selectedPath == null) return;
    isScanning = true;
    notifyListeners();

    try {
      files = await compute(_scanWorker, _ScanArgs(
        selectedPath!, 
        projectType,
        excludedFolderNames,
        excludedPatterns,
        excludedFiles,
        useGitIgnore
      ));
    } catch (e) {
      debugPrint("Error scanning: $e");
    }

    isScanning = false;
    notifyListeners();
  }

  Future<void> copyToClipboard(BuildContext context) async {
    if (selectedPath == null || files.isEmpty) return;
    isProcessing = true;
    notifyListeners();

    try {
      final filesToProcess = files.where((f) => f.isSelected).toList();
      final content = await compute(_generateStringWorker, _ProcessArgs(filesToProcess, wrapInXml));
      
      await Clipboard.setData(ClipboardData(text: content));
      
      if (!context.mounted) return;
      _showDialog(context, "Copied!", "Copied ${filesToProcess.length} files to clipboard.\n(${content.length} characters)");
    } catch (e) {
      if (!context.mounted) return;
      _showDialog(context, "Error", e.toString());
    }

    isProcessing = false;
    notifyListeners();
  }

  Future<void> generateOutput(BuildContext context) async {
    if (selectedPath == null || files.isEmpty) return;
    
    final filesToProcess = files.where((f) => f.isSelected).toList();
    String? outputFile = await FilePicker.platform.saveFile(
      dialogTitle: 'Save Context File',
      fileName: 'context.txt',
    );

    if (outputFile == null) return;

    isProcessing = true;
    notifyListeners();

    try {
      final content = await compute(_generateStringWorker, _ProcessArgs(filesToProcess, wrapInXml));
      final file = File(outputFile);
      await file.writeAsString(content);
      
      if (!context.mounted) return;
      _showDialog(context, "Success", "Saved to: $outputFile");
    } catch (e) {
      if (!context.mounted) return;
      _showDialog(context, "Error", e.toString());
    }

    isProcessing = false;
    notifyListeners();
  }
  
  void _showDialog(BuildContext context, String title, String body) {
    showDialog(
      context: context,
      builder: (context) => ContentDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          Button(child: const Text('Ok'), onPressed: () => Navigator.pop(context)),
        ],
      ),
    );
  }
}

// -- Isolates --

class _ScanArgs {
  final String dir;
  final ProjectType type;
  final List<String> excludedFolders;
  final List<String> excludedPatterns;
  final List<String> excludedFiles;
  final bool useGitIgnore;

  _ScanArgs(this.dir, this.type, this.excludedFolders, this.excludedPatterns, this.excludedFiles, this.useGitIgnore);
}

class _ProcessArgs {
  final List<FileInfo> files;
  final bool wrapXml;
  _ProcessArgs(this.files, this.wrapXml);
}

Future<List<FileInfo>> _scanWorker(_ScanArgs args) async {
  final dir = Directory(args.dir);
  List<FileInfo> results = [];
  
  bool isWindows = Platform.isWindows;
  
  Set<String> ignoredDirNames = args.excludedFolders
      .map((e) => isWindows ? e.toLowerCase() : e)
      .toSet();
      
  Set<String> ignoredFilePaths = args.excludedFiles
      .map((e) => isWindows ? e.toLowerCase() : e)
      .toSet();

  if (args.type == ProjectType.muleSoft) {
    ignoredDirNames.addAll(['target', '.mvn', 'catalog']);
  } else if (args.type == ProjectType.python) {
    ignoredDirNames.addAll(['venv', '.venv', 'env', '__pycache__', 'htmlcov', '.pytest_cache']);
  }

  bool matchesPattern(String fileName, List<String> patterns) {
    String name = isWindows ? fileName.toLowerCase() : fileName;
    for (var pat in patterns) {
      String p = isWindows ? pat.toLowerCase() : pat;
      if (p.startsWith('*.')) {
        if (name.endsWith(p.substring(1))) return true;
      } else if (p.startsWith('*')) {
        if (name.endsWith(p.substring(1))) return true;
      } else if (p == name) {
        return true;
      }
    }
    return false;
  }

  if (args.useGitIgnore) {
    final gitIgnoreFile = File(p.join(args.dir, '.gitignore'));
    if (gitIgnoreFile.existsSync()) {
      try {
        final lines = gitIgnoreFile.readAsLinesSync();
        for (var line in lines) {
          line = line.trim();
          if (line.isEmpty || line.startsWith('#')) continue;
          String clean = line.replaceAll('/', '');
          if (!clean.contains('*')) {
             ignoredDirNames.add(isWindows ? clean.toLowerCase() : clean);
          }
        }
      } catch (_) {}
    }
  }

  if (dir.existsSync()) {
    await for (var entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        String fullPath = entity.path;
        String comparePath = isWindows ? fullPath.toLowerCase() : fullPath;
        
        if (ignoredFilePaths.contains(comparePath)) continue;

        String relPath = p.relative(fullPath, from: args.dir);
        List<String> parts = p.split(relPath);

        bool isIgnored = parts.any((part) {
          String pName = isWindows ? part.toLowerCase() : part;
          return ignoredDirNames.contains(pName);
        });
        
        if (isIgnored) continue;

        String name = p.basename(fullPath);
        if (matchesPattern(name, args.excludedPatterns)) continue;

        const binaryExts = {
          '.ico', '.png', '.jpg', '.jpeg', '.gif', '.svg', '.bmp',
          '.exe', '.dll', '.so', '.dylib', '.bin',
          '.zip', '.tar', '.gz', '.7z', '.rar',
          '.pdf', '.doc', '.docx', '.xls', '.xlsx', '.ppt',
          '.pyc', '.pyo', '.pyd', '.class', '.jar', '.war',
          '.db', '.sqlite', '.ds_store', 'thumbs.db'
        };
        
        String ext = p.extension(fullPath).toLowerCase();
        FileType type = binaryExts.contains(ext) ? FileType.binary : FileType.text;
        
        results.add(FileInfo(fullPath, entity.lengthSync(), type));
      }
    }
  }
  results.sort((a, b) => a.path.compareTo(b.path));
  return results;
}

Future<String> _generateStringWorker(_ProcessArgs args) async {
  final buffer = StringBuffer();
  
  if (args.wrapXml) buffer.writeln("<codebase>");

  for (var fileInfo in args.files) {
    final file = File(fileInfo.path);
    final displayPath = fileInfo.path; 
    
    if (args.wrapXml) {
      buffer.writeln('<file path="$displayPath">');
      buffer.writeln("<![CDATA[");
    } else {
      buffer.writeln("=" * 80);
      buffer.writeln("File: $displayPath");
      buffer.writeln("=" * 80);
    }

    if (fileInfo.type == FileType.binary) {
      buffer.writeln("[Binary file - content not included]");
    } else {
      try {
        buffer.write(await file.readAsString());
      } catch (e) {
        buffer.writeln("[Error reading file: $e]");
      }
    }
    
    if (args.wrapXml) {
      buffer.writeln("]]>");
      buffer.writeln('</file>');
    } else {
      buffer.writeln("\n\n");
    }
  }
  
  if (args.wrapXml) buffer.writeln("</codebase>");
  return buffer.toString();
}