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
  // Encoder State
  final TextEditingController _encodeCtrl = TextEditingController();
  String? _selectedFilePath;
  String _status = "Ready";
  bool _isWorking = false;

  // Decoder State
  final TextEditingController _decodeCtrl = TextEditingController();
  String? _decodeSelectedFilePath; 
  String _decodeStatus = "Ready";
  bool _isDecoding = false;

  // Scratchpad State
  final TextEditingController _statsCtrl = TextEditingController();
  int _statsChars = 0;
  int _statsTokens = 0;

  // --- ENCODER LOGIC ---
  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result != null) {
      setState(() {
        _selectedFilePath = result.files.single.path;
        _status = "File selected: ${result.files.single.name}";
      });
    }
  }

  Future<void> _pasteToEncoder() async {
    ClipboardData? cdata = await Clipboard.getData(Clipboard.kTextPlain);
    if (cdata != null && cdata.text != null) {
      setState(() {
        _encodeCtrl.text = cdata.text!;
        _status = "Pasted ${cdata.text!.length} chars to encoder.";
      });
    }
  }

  Future<void> _copyEncodedToClipboard() async {
    final textInput = _encodeCtrl.text;
    final hasText = textInput.isNotEmpty;
    final hasFile = _selectedFilePath != null;

    if (!hasText && !hasFile) return;

    setState(() { _isWorking = true; _status = "Encoding..."; });

    try {
      String base64Str;
      if (hasText) {
        base64Str = base64Encode(utf8.encode(textInput));
        setState(() => _status = "Encoded text copied! (${base64Str.length} chars)");
      } else {
        File f = File(_selectedFilePath!);
        int len = await f.length();
        if (len > 10 * 1024 * 1024) { 
           throw "File too big for Clipboard (>10MB). Save to file instead.";
        }
        List<int> bytes = await f.readAsBytes();
        base64Str = base64Encode(bytes);
        setState(() => _status = "Encoded file copied! (${base64Str.length} chars)");
      }
      await Clipboard.setData(ClipboardData(text: base64Str));
    } catch (e) {
      setState(() => _status = "Error: $e");
    } finally {
      setState(() => _isWorking = false);
    }
  }

  Future<void> _saveEncodedToFile() async {
    final textInput = _encodeCtrl.text;
    final hasText = textInput.isNotEmpty;
    final hasFile = _selectedFilePath != null;

    if (!hasText && !hasFile) return;

    String? outputFile = await FilePicker.platform.saveFile(
      dialogTitle: hasText ? 'Save Encoded Text' : 'Save Base64 Output',
      fileName: hasText ? 'encoded_text.txt' : 'output.b64.txt',
    );

    if (outputFile == null) return;

    setState(() { _isWorking = true; _status = "Saving..."; });

    try {
      if (hasText) {
        String base64Str = base64Encode(utf8.encode(textInput));
        await File(outputFile).writeAsString(base64Str);
        setState(() => _status = "Saved encoded text to $outputFile");
      } else {
        final inputFile = File(_selectedFilePath!);
        final output = File(outputFile);
        final sink = output.openWrite();
        
        await inputFile.openRead()
            .transform(base64.encoder) 
            .transform(utf8.encoder)   
            .pipe(sink);                
            
        setState(() => _status = "Saved file output to $outputFile");
      }
    } catch (e) {
      setState(() => _status = "Error: $e");
    } finally {
      setState(() => _isWorking = false);
    }
  }

  // --- DECODER LOGIC ---
  Future<void> _pickDecodeFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result != null) {
      setState(() {
        _decodeSelectedFilePath = result.files.single.path;
        _decodeStatus = "File selected: ${result.files.single.name}";
      });
    }
  }

  Future<void> _pasteToDecoder() async {
    ClipboardData? cdata = await Clipboard.getData(Clipboard.kTextPlain);
    if (cdata != null && cdata.text != null) {
      setState(() {
        _decodeCtrl.text = cdata.text!;
        _decodeStatus = "Pasted ${cdata.text!.length} chars from clipboard.";
      });
    }
  }

  Future<void> _copyDecodedToClipboard() async {
    final textInput = _decodeCtrl.text.trim();
    final hasText = textInput.isNotEmpty;
    final hasFile = _decodeSelectedFilePath != null;

    if (!hasText && !hasFile) return;

    setState(() { _isDecoding = true; _decodeStatus = "Decoding..."; });

    try {
      Uint8List bytes;
      if (hasText) {
        bytes = base64Decode(textInput);
      } else {
        final inputFile = File(_decodeSelectedFilePath!);
        String content = await inputFile.readAsString();
        content = content.replaceAll(RegExp(r'\s'), ''); 
        bytes = base64Decode(content);
      }

      try {
        String result = utf8.decode(bytes);
        await Clipboard.setData(ClipboardData(text: result));
        setState(() => _decodeStatus = "Decoded text copied! (${result.length} chars)");
      } catch (_) {
        throw "Result is binary data, not text. Use 'Save to File'.";
      }
    } catch (e) {
      setState(() => _decodeStatus = "Error: $e");
    } finally {
      setState(() => _isDecoding = false);
    }
  }

  Future<void> _saveDecodedToFile() async {
    final textInput = _decodeCtrl.text.trim();
    final hasText = textInput.isNotEmpty;
    final hasFile = _decodeSelectedFilePath != null;

    if (!hasText && !hasFile) return;

    String? outputFile = await FilePicker.platform.saveFile(
      dialogTitle: 'Save Decoded File',
      fileName: 'decoded_file',
    );

    if (outputFile == null) return;

    setState(() { _isDecoding = true; _decodeStatus = "Decoding & Saving..."; });

    try {
      Uint8List bytes;
      if (hasText) {
        bytes = base64Decode(textInput);
      } else {
        final inputFile = File(_decodeSelectedFilePath!);
        String content = await inputFile.readAsString();
        content = content.replaceAll(RegExp(r'\s'), '');
        bytes = base64Decode(content);
      }

      await File(outputFile).writeAsBytes(bytes);
      setState(() => _decodeStatus = "Saved decoded file to $outputFile");
    } catch (e) {
      setState(() => _decodeStatus = "Error: $e");
    } finally {
      setState(() => _isDecoding = false);
    }
  }

  // --- SCRATCHPAD LOGIC ---
  void _onStatsChanged(String text) {
    setState(() {
      _statsChars = text.length;
      _statsTokens = (text.length / 4).ceil();
    });
  }

  void _compactText() {
    final text = _statsCtrl.text;
    if (text.isEmpty) return;
    
    // Remove empty lines
    final newText = text
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .join('\n');
        
    _statsCtrl.text = newText;
    _onStatsChanged(newText);
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final hasEncoderInput = _encodeCtrl.text.isNotEmpty || _selectedFilePath != null;
    final hasDecoderInput = _decodeCtrl.text.isNotEmpty || _decodeSelectedFilePath != null;

    return ScaffoldPage(
      header: const PageHeader(title: Text('Utilities')),
      content: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- ENCODER CARD ---
              _buildCard(theme, "Base64 Encoder", FluentIcons.file_code, [
                const Text("Convert binary files (Images, PDFs) or text to Base64.", style: TextStyle(fontSize: 12)),
                const SizedBox(height: 16),
                
                // Text Input
                TextBox(
                  controller: _encodeCtrl,
                  placeholder: "Type or paste text to encode...",
                  maxLines: 3,
                  minLines: 2,
                  style: const TextStyle(fontFamily: 'Consolas', fontSize: 11),
                  onChanged: (v) => setState(() {}),
                ),
                
                const SizedBox(height: 12),

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
                      if (_selectedFilePath != null)
                        IconButton(
                          icon: const Icon(FluentIcons.clear, size: 12),
                          onPressed: () => setState(() {
                            _selectedFilePath = null;
                            _status = "Ready";
                          }),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Actions (Systematic Order)
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    // 1. Paste
                    Button(
                      onPressed: _isWorking ? null : _pasteToEncoder,
                      child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(FluentIcons.paste, size: 12), SizedBox(width: 6), Text("Paste Clipboard")]),
                    ),
                    
                    // 2. Browse File
                    Button(
                      onPressed: _isWorking ? null : _pickFile,
                      child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(FluentIcons.folder_open, size: 12), SizedBox(width: 6), Text("Browse File")]),
                    ),

                    // 3. Smart Copy
                    FilledButton(
                      onPressed: (_isWorking || !hasEncoderInput) ? null : _copyEncodedToClipboard,
                      child: const Text("Copy Encoded"),
                    ),

                    // 4. Smart Save
                    Button(
                      onPressed: (_isWorking || !hasEncoderInput) ? null : _saveEncodedToFile,
                      child: const Text("Save to File"),
                    ),

                    if (_isWorking) const SizedBox(height: 16, width: 16, child: ProgressRing(strokeWidth: 2)),
                  ],
                ),
                
                const SizedBox(height: 8),
                if (_status != "Ready")
                  Text(_status, style: TextStyle(
                    fontFamily: 'Consolas',
                    fontSize: 11,
                    color: _status.startsWith("Error") ? Colors.red : theme.accentColor,
                    fontWeight: FontWeight.bold,
                  )),
              ]),

              const SizedBox(height: 24),

              // --- DECODER CARD ---
              _buildCard(theme, "Base64 Decoder", FluentIcons.return_key, [
                const Text("Convert Base64 text/files back to original.", style: TextStyle(fontSize: 12)),
                const SizedBox(height: 16),
                
                // Text Input
                TextBox(
                  controller: _decodeCtrl,
                  placeholder: "Paste Base64 string here...",
                  maxLines: 3, 
                  minLines: 2,
                  style: const TextStyle(fontFamily: 'Consolas', fontSize: 11),
                  onChanged: (v) => setState(() {}),
                ),
                
                const SizedBox(height: 12),

                // Decoder File Picker
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
                          _decodeSelectedFilePath ?? "No file selected...",
                          style: TextStyle(
                            fontFamily: 'Consolas',
                            color: _decodeSelectedFilePath == null ? theme.resources.textFillColorTertiary : theme.resources.textFillColorPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (_decodeSelectedFilePath != null)
                        IconButton(
                          icon: const Icon(FluentIcons.clear, size: 12),
                          onPressed: () => setState(() {
                            _decodeSelectedFilePath = null;
                            _decodeStatus = "Ready";
                          }),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Actions
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    // 1. Paste
                    Button(
                      onPressed: _isDecoding ? null : _pasteToDecoder,
                      child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(FluentIcons.paste, size: 12), SizedBox(width: 6), Text("Paste Clipboard")]),
                    ),
                    
                    // 2. Browse File
                    Button(
                      onPressed: _isDecoding ? null : _pickDecodeFile,
                      child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(FluentIcons.folder_open, size: 12), SizedBox(width: 6), Text("Browse File")]),
                    ),

                    // 3. Smart Copy
                    FilledButton(
                      onPressed: (_isDecoding || !hasDecoderInput) ? null : _copyDecodedToClipboard,
                      child: const Text("Copy Decoded"),
                    ),

                    // 4. Smart Save
                    Button(
                      onPressed: (_isDecoding || !hasDecoderInput) ? null : _saveDecodedToFile,
                      child: const Text("Save to File"),
                    ),
                    
                    if (_isDecoding) const SizedBox(height: 16, width: 16, child: ProgressRing(strokeWidth: 2)),
                  ],
                ),

                const SizedBox(height: 8),
                if (_decodeStatus != "Ready")
                  Text(_decodeStatus, style: TextStyle(
                    fontFamily: 'Consolas',
                    fontSize: 11,
                    color: _decodeStatus.startsWith("Error") ? Colors.red : theme.accentColor,
                    fontWeight: FontWeight.bold,
                  )),
              ]),

              const SizedBox(height: 24),

              // --- TOKEN SCRATCHPAD ---
              _buildCard(theme, "Token Scratchpad", FluentIcons.edit, [
                const Text("Quickly check token usage or compact text before pasting.", style: TextStyle(fontSize: 12)),
                const SizedBox(height: 16),
                
                TextBox(
                  controller: _statsCtrl,
                  placeholder: "Paste text here...",
                  maxLines: 8,
                  minLines: 3,
                  style: const TextStyle(fontFamily: 'Consolas', fontSize: 11),
                  onChanged: _onStatsChanged,
                ),
                
                const SizedBox(height: 12),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "$_statsChars chars  •  ~$_statsTokens tokens", 
                      style: TextStyle(
                        fontFamily: 'Consolas', 
                        fontWeight: FontWeight.bold,
                        color: _statsTokens > 32000 ? Colors.red : theme.accentColor,
                      )
                    ),
                    
                    Row(
                      children: [
                        Button(
                          onPressed: _statsCtrl.text.isEmpty ? null : _compactText,
                          child: const Text("Remove Empty Lines"),
                        ),
                        const SizedBox(width: 8),
                        Button(
                          onPressed: () {
                             _statsCtrl.clear();
                             _onStatsChanged("");
                          },
                          child: const Text("Clear"),
                        ),
                      ],
                    )
                  ],
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCard(FluentThemeData theme, String title, IconData icon, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.resources.cardStrokeColorDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20),
              const SizedBox(width: 12),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 12),
          ...children
        ],
      ),
    );
  }
}