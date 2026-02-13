import 'dart:convert';
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
enum OutputFormat { plain, xml, markdown }

class FileInfo {
  final String path;
  final int size;
  final FileType type;
  bool isSelected = true;
  
  FileInfo(this.path, this.size, this.type);

  String get fileName => p.basename(path);
  
  // Rough token estimate: ~4 chars per token for code/text
  int get estimatedTokens => type == FileType.text ? (size / 4).ceil() : 0;
  
  String get statString {
    if (size < 1024) return "$size B";
    if (size < 1024 * 1024) return "${(size / 1024).toStringAsFixed(1)} KB";
    return "${(size / (1024 * 1024)).toStringAsFixed(1)} MB";
  }
}

// -----------------------------------------------------------------------------
// 1. SETTINGS SERVICE (Persistence Logic)
// -----------------------------------------------------------------------------
class SettingsService {
  static const String _configFileName = ".exclusion_settings.json";

  // Load Global App Settings
  static Future<void> loadGlobalSettings(AppState state) async {
    final prefs = await SharedPreferences.getInstance();
    
    int themeIdx = prefs.getInt('themeMode') ?? 1; // Default Dark
    state._themeMode = ThemeMode.values[themeIdx];
    
    state._useGlass = prefs.getBool('useGlass') ?? true;
    
    int flavorIdx = prefs.getInt('flavor') ?? 0;
    state._flavor = ThemeFlavor.values[flavorIdx];
    
    // Check if we have a last opened folder
    String? lastPath = prefs.getString('lastFolder');
    if (lastPath != null && Directory(lastPath).existsSync()) {
      state.selectedPath = lastPath;
    }
  }

  static Future<void> saveGlobalTheme(AppState state) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('themeMode', state.themeMode.index);
    await prefs.setBool('useGlass', state.useGlass);
    await prefs.setInt('flavor', state.flavor.index);
  }

  // Load Project-Specific Config (or fall back to global defaults)
  static Future<void> loadProjectConfig(AppState state) async {
    final prefs = await SharedPreferences.getInstance();

    // 1. Try to load from .exclusion_settings.json in the project root
    if (state.selectedPath != null) {
      final file = File(p.join(state.selectedPath!, _configFileName));
      if (await file.exists()) {
        try {
          final content = await file.readAsString();
          final Map<String, dynamic> data = jsonDecode(content);
          
          if (data.containsKey('projectType')) state.projectType = ProjectType.values[data['projectType']];
          if (data.containsKey('outputFormat')) state.outputFormat = OutputFormat.values[data['outputFormat']];
          if (data.containsKey('useGitIgnore')) state.useGitIgnore = data['useGitIgnore'];
          if (data.containsKey('excludedFolderNames')) state.excludedFolderNames = List<String>.from(data['excludedFolderNames']);
          if (data.containsKey('excludedPatterns')) state.excludedPatterns = List<String>.from(data['excludedPatterns']);
          if (data.containsKey('excludedFiles')) state.excludedFiles = List<String>.from(data['excludedFiles']);
          
          return; // Loaded successfully, skip fallback
        } catch (e) {
          debugPrint("Failed to load project config: $e");
        }
      }
    }

    // 2. Fallback: Load from SharedPreferences (Global Defaults)
    int projIdx = prefs.getInt('projectType') ?? 0;
    state.projectType = ProjectType.values[projIdx];
    
    int fmtIdx = prefs.getInt('outputFormat') ?? 1;
    if (fmtIdx < OutputFormat.values.length) state.outputFormat = OutputFormat.values[fmtIdx];
    
    state.useGitIgnore = prefs.getBool('useGitIgnore') ?? true;
    state.excludedFolderNames = prefs.getStringList('excludedFolders') ?? List.from(AppState.defaultFolders);
    state.excludedPatterns = prefs.getStringList('excludedPatterns') ?? List.from(AppState.defaultPatterns);
    state.excludedFiles = prefs.getStringList('excludedFiles') ?? [];
  }

  static Future<void> saveProjectConfig(AppState state) async {
    final prefs = await SharedPreferences.getInstance();

    // Always update global fallback/cache
    await prefs.setInt('projectType', state.projectType.index);
    await prefs.setInt('outputFormat', state.outputFormat.index);
    await prefs.setBool('useGitIgnore', state.useGitIgnore);
    if (state.selectedPath != null) await prefs.setString('lastFolder', state.selectedPath!);
    await prefs.setStringList('excludedFolders', state.excludedFolderNames);
    await prefs.setStringList('excludedPatterns', state.excludedPatterns);
    await prefs.setStringList('excludedFiles', state.excludedFiles);

    // Save to local project file
    if (state.selectedPath != null) {
      final data = {
        'projectType': state.projectType.index,
        'outputFormat': state.outputFormat.index,
        'useGitIgnore': state.useGitIgnore,
        'excludedFolderNames': state.excludedFolderNames,
        'excludedPatterns': state.excludedPatterns,
        'excludedFiles': state.excludedFiles,
      };
      
      try {
        final file = File(p.join(state.selectedPath!, _configFileName));
        await file.writeAsString(jsonEncode(data));
      } catch (e) {
        debugPrint("Failed to save local config: $e");
      }
    }
  }
}

// -----------------------------------------------------------------------------
// 2. FILE SERVICE (Heavy Lifting)
// -----------------------------------------------------------------------------
class FileService {
  static Future<List<FileInfo>> scan(AppState state) async {
    if (state.selectedPath == null) return [];
    return await compute(_scanWorker, _ScanArgs(
      state.selectedPath!, 
      state.projectType,
      state.excludedFolderNames,
      state.excludedPatterns,
      state.excludedFiles,
      state.useGitIgnore
    ));
  }

  // Legacy String Generator (RAM Heavy) - Only for Clipboard
  static Future<String> generateContent(List<FileInfo> files, OutputFormat format) async {
    return await compute(_generateStringWorker, _ProcessArgs(files, format));
  }

  // New Stream Generator (Disk Safe) - For Saving Files
  static Future<void> streamToDisk(List<FileInfo> files, OutputFormat format, String outputPath, {String? prependData}) async {
    await compute(_streamToDiskWorker, _StreamSaveArgs(files, format, outputPath, prependData: prependData));
  }

  static Future<String> generateTree(List<FileInfo> files, String rootPath) async {
    return await compute(_generateTreeWorker, _TreeArgs(files, rootPath));
  }
}

// -----------------------------------------------------------------------------
// 3. APP STATE (The Manager)
// -----------------------------------------------------------------------------
class AppState extends ChangeNotifier {
  String? selectedPath;
  List<FileInfo> files = [];
  bool isScanning = false;
  bool isProcessing = false;
  
  // -- App Settings --
  ThemeMode _themeMode = ThemeMode.dark;
  bool _useGlass = true;
  ThemeFlavor _flavor = ThemeFlavor.standard;

  // -- Project Config --
  ProjectType projectType = ProjectType.standard;
  OutputFormat outputFormat = OutputFormat.xml;
  bool useGitIgnore = true;
  
  // Defaults
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

  // --- ACTIONS ---
  
  Future<void> loadSettings() async {
    await SettingsService.loadGlobalSettings(this);
    if (selectedPath != null) {
      await SettingsService.loadProjectConfig(this);
      scanFiles();
    }
    notifyListeners();
  }

  void _save() {
    SettingsService.saveProjectConfig(this);
    notifyListeners(); // Notify listeners to update UI
  }

  void setSearchFilter(String val) {
    _searchFilter = val;
    notifyListeners();
  }

  void resetExclusionsToDefault() {
    excludedFolderNames = List.from(defaultFolders);
    excludedPatterns = List.from(defaultPatterns);
    excludedFiles.clear();
    useGitIgnore = true;
    _save();
    if (selectedPath != null) scanFiles();
  }

  void toggleAllFiles(bool selected) {
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
    _save();
    scanFiles();
  }

  void addExcludedFolder(String folder) {
    if (!excludedFolderNames.contains(folder)) {
      excludedFolderNames.insert(0, folder);
      _save();
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
    _save();
    if (selectedPath != null) scanFiles();
  }

  void addExcludedPattern(String pattern) {
    if (!excludedPatterns.contains(pattern)) {
      excludedPatterns.insert(0, pattern);
      _save();
      if (selectedPath != null) scanFiles();
    }
  }

  void removeExcludedPattern(String pattern) {
    excludedPatterns.remove(pattern);
    _save();
    if (selectedPath != null) scanFiles();
  }

  Future<void> pickExcludedFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result != null) {
      String path = result.files.single.path!;
      if (!excludedFiles.contains(path)) {
        excludedFiles.insert(0, path);
        _save();
        if (selectedPath != null) scanFiles();
      }
    }
  }

  void removeExcludedFile(String path) {
    excludedFiles.remove(path);
    _save();
    if (selectedPath != null) scanFiles();
  }

  void toggleGitIgnore(bool val) {
    useGitIgnore = val;
    _save();
    if (selectedPath != null) scanFiles();
  }

  // Global Settings Actions
  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    SettingsService.saveGlobalTheme(this);
    notifyListeners();
  }

  void toggleGlass(bool value) {
    _useGlass = value;
    SettingsService.saveGlobalTheme(this);
    notifyListeners();
  }

  void setThemeFlavor(ThemeFlavor flavor) {
    _flavor = flavor;
    if (flavor == ThemeFlavor.pitchBlack) {
      _useGlass = false;
    } else {
      _useGlass = true;
    }
    SettingsService.saveGlobalTheme(this);
    notifyListeners();
  }

  // Project Settings Actions
  void setProjectType(ProjectType type) {
    projectType = type;
    _save();
    if (selectedPath != null) scanFiles();
  }

  void setPathFromDrop(String path) {
    selectedPath = path;
    // Load config specific to this new path
    SettingsService.loadProjectConfig(this).then((_) {
      _save(); 
      scanFiles();
    });
  }

  void setOutputFormat(OutputFormat format) {
    outputFormat = format;
    _save();
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
      await SettingsService.loadProjectConfig(this);
      _save();
      scanFiles();
    }
  }

  Future<void> scanFiles() async {
    if (selectedPath == null) return;
    isScanning = true;
    notifyListeners();

    try {
      files = await FileService.scan(this);
    } catch (e) {
      debugPrint("Error scanning: $e");
    }

    isScanning = false;
    notifyListeners();
  }

  Future<void> copyFileTree(BuildContext context) async {
    if (selectedPath == null || files.isEmpty) return;
    final selectedFiles = files.where((f) => f.isSelected).toList();
    if (selectedFiles.isEmpty) return;

    try {
      final tree = await FileService.generateTree(selectedFiles, selectedPath!);
      await Clipboard.setData(ClipboardData(text: tree));
      if (!context.mounted) return;
      _showDialog(context, "Tree Copied", "File tree copied to clipboard.");
    } catch (e) {
      if (!context.mounted) return;
      _showDialog(context, "Error", e.toString());
    }
  }

  Future<void> copyToClipboard(BuildContext context) async {
    if (selectedPath == null || files.isEmpty) return;
    isProcessing = true;
    notifyListeners();

    try {
      final filesToProcess = files.where((f) => f.isSelected).toList();
      final tree = await FileService.generateTree(filesToProcess, selectedPath!);
      final content = await FileService.generateContent(filesToProcess, outputFormat);
      final fullOutput = "$tree\n\n$content";
      
      await Clipboard.setData(ClipboardData(text: fullOutput));
      
      if (!context.mounted) return;
      _showDialog(context, "Copied!", "Context copied to clipboard.\n(${fullOutput.length} chars, includes file tree)");
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
    
    // Smart Naming based on format
    String ext = outputFormat == OutputFormat.markdown ? "md" : (outputFormat == OutputFormat.xml ? "xml" : "txt");
    
    String? outputFile = await FilePicker.platform.saveFile(
      dialogTitle: 'Save Context File',
      fileName: 'context.$ext',
    );

    if (outputFile == null) return;

    isProcessing = true;
    notifyListeners();

    try {
      // 1. Generate Tree (Small enough to keep in RAM)
      final tree = await FileService.generateTree(filesToProcess, selectedPath!);
      
      // 2. Stream Content + Tree to Disk (Memory Safe)
      await FileService.streamToDisk(filesToProcess, outputFormat, outputFile, prependData: tree);
      
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

// -----------------------------------------------------------------------------
// WORKERS (Isolates) & HELPERS
// -----------------------------------------------------------------------------

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
  final OutputFormat format; 
  _ProcessArgs(this.files, this.format);
}

class _StreamSaveArgs {
  final List<FileInfo> files;
  final OutputFormat format;
  final String outputPath;
  final String? prependData;
  _StreamSaveArgs(this.files, this.format, this.outputPath, {this.prependData});
}

class _TreeArgs {
  final List<FileInfo> files;
  final String rootPath;
  _TreeArgs(this.files, this.rootPath);
}

Future<List<FileInfo>> _scanWorker(_ScanArgs args) async {
  final dir = Directory(args.dir);
  List<FileInfo> results = [];
  bool isWindows = Platform.isWindows;
  
  // Convert basic wildcard patterns to Regex
  // e.g. "*.log" -> r"^.*\.log$"
  List<RegExp> regexPatterns = args.excludedPatterns.map((p) {
    String pattern = RegExp.escape(p).replaceAll(r'\*', '.*').replaceAll(r'\?', '.');
    return RegExp('^$pattern\$', caseSensitive: false);
  }).toList();

  Set<String> ignoredDirNames = args.excludedFolders
      .map((e) => isWindows ? e.toLowerCase() : e)
      .toSet();
      
  Set<String> ignoredFilePaths = args.excludedFiles
      .map((e) => isWindows ? e.toLowerCase() : e)
      .toSet();

  // Add default tech stacks
  if (args.type == ProjectType.muleSoft) {
    ignoredDirNames.addAll(['target', '.mvn', 'catalog']);
  } else if (args.type == ProjectType.python) {
    ignoredDirNames.addAll(['venv', '.venv', 'env', '__pycache__', 'htmlcov', '.pytest_cache']);
  }

  // --- GITIGNORE PARSING (Regex Edition) ---
  if (args.useGitIgnore) {
    final gitIgnoreFile = File(p.join(args.dir, '.gitignore'));
    if (gitIgnoreFile.existsSync()) {
      try {
        final lines = gitIgnoreFile.readAsLinesSync();
        for (var line in lines) {
          line = line.trim();
          if (line.isEmpty || line.startsWith('#')) continue;
          
          // Handle directory markers
          if (line.endsWith('/')) {
            String dirName = line.substring(0, line.length - 1);
            if (dirName.startsWith('/')) dirName = dirName.substring(1);
            ignoredDirNames.add(isWindows ? dirName.toLowerCase() : dirName);
            continue;
          }

          // Handle simple files vs patterns
          if (!line.contains('*') && !line.contains('?')) {
             if (line.startsWith('/')) line = line.substring(1);
             ignoredDirNames.add(isWindows ? line.toLowerCase() : line); // Treat as folder or file name
          } else {
             // It's a pattern, add to regex list
             String pattern = RegExp.escape(line).replaceAll(r'\*', '.*').replaceAll(r'\?', '.');
             regexPatterns.add(RegExp('^$pattern\$', caseSensitive: false));
          }
        }
      } catch (e) {
        debugPrint("GitIgnore Parse Error: $e");
      }
    }
  }

  // Helper: Binary Check (Null Byte)
  bool isBinary(File f) {
    try {
      // Read small chunk to check for null bytes
      final bytes = f.openSync().readSync(1024); // Only read 1KB
      if (bytes.contains(0)) return true;
      return false;
    } catch (e) {
      return true; // If we can't read it, treat as binary/skip
    }
  }

  if (dir.existsSync()) {
    // Recursive List
    try {
      await for (var entity in dir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          try {
            String fullPath = entity.path;
            String comparePath = isWindows ? fullPath.toLowerCase() : fullPath;
            
            // 1. Exact File Exclusion
            if (ignoredFilePaths.contains(comparePath)) continue;

            String relPath = p.relative(fullPath, from: args.dir);
            List<String> parts = p.split(relPath);

            // 2. Folder Exclusion (Any part of the path matches an ignored folder)
            bool isIgnored = parts.any((part) {
              String pName = isWindows ? part.toLowerCase() : part;
              return ignoredDirNames.contains(pName);
            });
            if (isIgnored) continue;

            String name = p.basename(fullPath);
            
            // 3. Pattern Matching (User + GitIgnore Regex)
            bool patternMatched = false;
            for (var reg in regexPatterns) {
               if (reg.hasMatch(name)) { patternMatched = true; break; }
            }
            if (patternMatched) continue;
            
            // 4. Config File
            if (name == ".exclusion_settings.json") continue;

            // 5. Binary Check
            FileType type = isBinary(entity) ? FileType.binary : FileType.text;
            
            results.add(FileInfo(fullPath, entity.lengthSync(), type));
          } catch (e) {
            // Found a locked file or permission error? Skip it, don't crash.
            debugPrint("Skipping file due to error: $e");
          }
        }
      }
    } catch (e) {
      debugPrint("Fatal Error during scan: $e");
    }
  }
  
  // Sort for clean tree
  results.sort((a, b) => a.path.compareTo(b.path));
  return results;
}

Future<String> _generateStringWorker(_ProcessArgs args) async {
  final buffer = StringBuffer();
  if (args.format == OutputFormat.xml) buffer.writeln("<codebase>");

  for (var fileInfo in args.files) {
    final file = File(fileInfo.path);
    final displayPath = fileInfo.path; 
    
    if (args.format == OutputFormat.xml) {
      buffer.writeln('<file path="$displayPath">');
      buffer.writeln("<![CDATA[");
    } else if (args.format == OutputFormat.markdown) {
      buffer.writeln("### File: $displayPath");
      String ext = p.extension(displayPath).replaceAll('.', '');
      if (ext.isEmpty) ext = "text";
      buffer.writeln("```$ext");
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
    
    if (args.format == OutputFormat.xml) {
      buffer.writeln("]]>");
      buffer.writeln('</file>');
    } else if (args.format == OutputFormat.markdown) {
      buffer.writeln("```\n");
    } else {
      buffer.writeln("\n\n");
    }
  }
  
  if (args.format == OutputFormat.xml) buffer.writeln("</codebase>");
  return buffer.toString();
}

Future<void> _streamToDiskWorker(_StreamSaveArgs args) async {
  final file = File(args.outputPath);
  final sink = file.openWrite(); // Open stream
  
  // 1. Write Header / Tree
  if (args.prependData != null) {
      sink.writeln(args.prependData);
      sink.writeln("\n\n");
  }

  if (args.format == OutputFormat.xml) sink.writeln("<codebase>");

  // 2. Stream Files One by One
  for (var fileInfo in args.files) {
    final inputFile = File(fileInfo.path);
    final displayPath = fileInfo.path; 
    
    // Formatting Header
    if (args.format == OutputFormat.xml) {
      sink.writeln('<file path="$displayPath">');
      sink.writeln("<![CDATA[");
    } else if (args.format == OutputFormat.markdown) {
      sink.writeln("### File: $displayPath");
      String ext = p.extension(displayPath).replaceAll('.', '');
      if (ext.isEmpty) ext = "text";
      sink.writeln("```$ext");
    } else {
      sink.writeln("=" * 80);
      sink.writeln("File: $displayPath");
      sink.writeln("=" * 80);
    }

    // Write Content
    if (fileInfo.type == FileType.binary) {
      sink.writeln("[Binary file - content not included]");
    } else {
      try {
        // Stream reading (Don't load whole file to RAM)
        await inputFile.openRead()
            .transform(utf8.decoder) // Decode to string
            .forEach((chunk) {
              sink.write(chunk); // Write chunk immediately
            });
      } catch (e) {
        sink.writeln("[Error reading file: $e]");
      }
    }
    
    // Formatting Footer
    if (args.format == OutputFormat.xml) {
      sink.writeln("]]>");
      sink.writeln('</file>');
    } else if (args.format == OutputFormat.markdown) {
      sink.writeln("```\n");
    } else {
      sink.writeln("\n\n");
    }
  }
  
  if (args.format == OutputFormat.xml) sink.writeln("</codebase>");
  
  await sink.flush();
  await sink.close();
}

Future<String> _generateTreeWorker(_TreeArgs args) async {
  final buffer = StringBuffer();
  buffer.writeln("Project Tree:");
  final paths = args.files.map((f) => p.relative(f.path, from: args.rootPath)).toList();
  paths.sort();
  for (var path in paths) {
    int depth = p.split(path).length - 1;
    String indent = "  " * depth;
    buffer.writeln("$indent- $path");
  }
  return buffer.toString();
}