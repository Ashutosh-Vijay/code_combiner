import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';

class UtilsPage extends StatefulWidget {
  const UtilsPage({super.key});

  @override
  State<UtilsPage> createState() => _UtilsPageState();
}

class _UtilsPageState extends State<UtilsPage> {
  String? _selectedFilePath;
  String _status = "Ready";
  bool _isWorking = false;

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result != null) {
      setState(() {
        _selectedFilePath = result.files.single.path;
        _status = "File selected: ${result.files.single.name}";
      });
    }
  }

  Future<void> _convertToClipboard() async {
    if (_selectedFilePath == null) return;
    
    File f = File(_selectedFilePath!);
    int len = await f.length();
    
    if (len > 10 * 1024 * 1024) { 
      setState(() => _status = "Error: File too big for Clipboard (>10MB). Save to file instead.");
      return;
    }

    setState(() { _isWorking = true; _status = "Converting..."; });

    try {
      List<int> bytes = await f.readAsBytes();
      String base64Str = base64Encode(bytes);
      await Clipboard.setData(ClipboardData(text: base64Str));
      setState(() => _status = "Copied to Clipboard! (${base64Str.length} chars)");
    } catch (e) {
      setState(() => _status = "Error: $e");
    } finally {
      setState(() => _isWorking = false);
    }
  }

  Future<void> _convertToFile() async {
      if (_selectedFilePath == null) return;

      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Base64 Output',
        fileName: 'output.b64.txt',
      );

      if (outputFile == null) return;

      setState(() { _isWorking = true; _status = "Streaming conversion..."; });

      try {
        final inputFile = File(_selectedFilePath!);
        final output = File(outputFile);
        final sink = output.openWrite();
        
        await inputFile.openRead()
            .transform(base64.encoder) 
            .transform(utf8.encoder)   
            .pipe(sink);                
            
        setState(() => _status = "Saved to $outputFile");
      } catch (e) {
        setState(() => _status = "Error: $e");
      } finally {
        setState(() => _isWorking = false);
      }
    }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return ScaffoldPage(
      header: const PageHeader(title: Text('Utilities')),
      content: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Feature Card: Base64 ---
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: theme.resources.cardStrokeColorDefault),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(FluentIcons.file_code, size: 20),
                      SizedBox(width: 12),
                      Text("Base64 Encoder", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text("Convert binary files (Images, PDFs) to text for LLM ingestion.", style: TextStyle(color: theme.resources.textFillColorSecondary)),
                  const SizedBox(height: 20),
                  
                  // File Picker Box
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.resources.controlFillColorSecondary,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: theme.resources.cardStrokeColorDefault.withValues(alpha: 0.1)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _selectedFilePath ?? "No file selected...",
                            style: TextStyle(
                              fontFamily: 'Consolas',
                              color: _selectedFilePath == null ? theme.resources.textFillColorTertiary : theme.resources.textFillColorPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Button(
                          onPressed: _isWorking ? null : _pickFile,
                          child: const Text("Browse"),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Actions
                  Row(
                    children: [
                      FilledButton(
                        onPressed: (_isWorking || _selectedFilePath == null) ? null : _convertToClipboard,
                        child: const Text("Copy Base64"),
                      ),
                      const SizedBox(width: 12),
                      Button(
                        onPressed: (_isWorking || _selectedFilePath == null) ? null : _convertToFile,
                        child: const Text("Save to File"),
                      ),
                      const SizedBox(width: 16),
                      if (_isWorking) const SizedBox(height: 16, width: 16, child: ProgressRing(strokeWidth: 2)),
                    ],
                  ),
                  
                  const SizedBox(height: 12),
                  
                  if (_status != "Ready")
                    Text(_status, style: TextStyle(
                      fontFamily: 'Consolas',
                      color: _status.startsWith("Error") ? Colors.red : theme.accentColor,
                      fontWeight: FontWeight.bold,
                    )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}