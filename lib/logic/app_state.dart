import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:fluent_ui/fluent_ui.dart';
import '../theme.dart'; // Import for ThemeFlavor

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

  ThemeMode get themeMode => _themeMode;
  bool get useGlass => _useGlass;
  ThemeFlavor get flavor => _flavor;

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

  // -- Actions --

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    notifyListeners();
  }

  void toggleGlass(bool value) {
    _useGlass = value;
    notifyListeners();
  }

  void setThemeFlavor(ThemeFlavor flavor) {
    _flavor = flavor;
    // Auto-disable glass for pitch black, enable for others
    if (flavor == ThemeFlavor.pitchBlack) {
      _useGlass = false;
    } else {
      _useGlass = true;
    }
    notifyListeners();
  }

  void setProjectType(ProjectType type) {
    projectType = type;
    notifyListeners();
    if (selectedPath != null) scanFiles();
  }

  void setPathFromDrop(String path) {
    selectedPath = path;
    notifyListeners();
    scanFiles();
  }

  void toggleXml(bool val) {
    wrapInXml = val;
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
      notifyListeners();
      scanFiles();
    }
  }

  Future<void> scanFiles() async {
    if (selectedPath == null) return;
    isScanning = true;
    notifyListeners();

    try {
      files = await compute(_scanWorker, _ScanArgs(selectedPath!, projectType));
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
  _ScanArgs(this.dir, this.type);
}

class _ProcessArgs {
  final List<FileInfo> files;
  final bool wrapXml;
  _ProcessArgs(this.files, this.wrapXml);
}

Future<List<FileInfo>> _scanWorker(_ScanArgs args) async {
  final dir = Directory(args.dir);
  List<FileInfo> results = [];
  
  const binaryExts = {
    '.ico', '.png', '.jpg', '.jpeg', '.gif', '.svg', '.bmp',
    '.exe', '.dll', '.so', '.dylib', '.bin',
    '.zip', '.tar', '.gz', '.7z', '.rar',
    '.pdf', '.doc', '.docx', '.xls', '.xlsx', '.ppt',
    '.pyc', '.pyo', '.pyd',
    '.class', '.jar', '.war',
    '.db', '.sqlite',
    '.ds_store', 'thumbs.db'
  };

  List<String> ignoredDirs = ['.git', '.vscode', '.idea', 'node_modules'];
  
  if (args.type == ProjectType.muleSoft) {
    ignoredDirs.addAll(['target', '.mvn', 'catalog']);
  } else if (args.type == ProjectType.python) {
    ignoredDirs.addAll(['venv', '.venv', 'env', '__pycache__', 'build', 'dist', 'htmlcov', '.pytest_cache']);
  }

  final gitIgnoreFile = File(p.join(args.dir, '.gitignore'));
  if (gitIgnoreFile.existsSync()) {
    try {
      final lines = gitIgnoreFile.readAsLinesSync();
      for (var line in lines) {
        line = line.trim();
        if (line.isEmpty || line.startsWith('#')) continue;
        if (line.endsWith('/')) {
          ignoredDirs.add(line.replaceAll('/', ''));
        } else if (line == 'venv' || line == '.env' || line == 'build') {
           ignoredDirs.add(line);
        }
      }
    } catch (_) {}
  }

  if (dir.existsSync()) {
    await for (var entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        String relPath = p.relative(entity.path, from: args.dir);
        List<String> parts = p.split(relPath);

        bool isIgnored = parts.any((part) => ignoredDirs.contains(part));
        
        if (!isIgnored) {
           String name = p.basename(entity.path);
           if (binaryExts.contains(name.toLowerCase())) {
             isIgnored = true;
           }
        }

        if (!isIgnored) {
          String ext = p.extension(entity.path).toLowerCase();
          FileType type = binaryExts.contains(ext) ? FileType.binary : FileType.text;
          results.add(FileInfo(entity.path, entity.lengthSync(), type));
        }
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