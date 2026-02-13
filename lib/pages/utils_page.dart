import 'dart:convert';
import 'dart:io';
// Removed unused dart:math
import 'package:crypto/crypto.dart' as crypto; // Add crypto ^3.0.3
import 'package:encrypt/encrypt.dart' as enc; // Add encrypt ^5.0.3
import 'package:file_picker/file_picker.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/foundation.dart'; // For compute
import 'package:flutter/services.dart';

class UtilsPage extends StatefulWidget {
  const UtilsPage({super.key});

  @override
  State<UtilsPage> createState() => _UtilsPageState();
}

class _UtilsPageState extends State<UtilsPage> {
  // --- NAVIGATION STATE (Tabs) ---
  int _tabIndex = 0;

  // --- ENCODER TAB STATE ---
  final TextEditingController _encodeCtrl = TextEditingController();
  String? _selectedFilePath;
  String _status = "Ready";
  bool _isWorking = false;

  final TextEditingController _decodeCtrl = TextEditingController();
  String? _decodeSelectedFilePath; 
  String _decodeStatus = "Ready";
  bool _isDecoding = false;

  final TextEditingController _statsCtrl = TextEditingController();
  int _statsChars = 0;
  int _statsTokens = 0;

  // --- CRYPTO TAB STATE ---
  bool _isEncryptMode = true;
  final TextEditingController _cryptoInputCtrl = TextEditingController();
  final TextEditingController _cryptoPassCtrl = TextEditingController();
  String? _cryptoSelectedFile;
  String _cryptoStatus = "Ready";
  bool _isCryptoWorking = false;

  // ===========================================================================
  // ENCODER / DECODER LOGIC
  // ===========================================================================

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

  // --- WORKER FUNCTIONS (ENCODER) ---
  static Future<String> _encodeTextWorker(String text) async {
    return base64Encode(utf8.encode(text));
  }

  static Future<String> _encodeFileWorker(String path) async {
    final file = File(path);
    final bytes = await file.readAsBytes();
    return base64Encode(bytes);
  }

  static Future<void> _saveEncodedTextWorker(List<String> args) async {
    final text = args[0];
    final path = args[1];
    final encoded = base64Encode(utf8.encode(text));
    await File(path).writeAsString(encoded);
  }

  static Future<void> _streamEncodeFileWorker(List<String> args) async {
    final inputPath = args[0];
    final outputPath = args[1];
    final inputFile = File(inputPath);
    final output = File(outputPath);
    final sink = output.openWrite();
    await inputFile.openRead()
        .transform(base64.encoder) 
        .transform(utf8.encoder)
        .pipe(sink);
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
        base64Str = await compute(_encodeTextWorker, textInput);
        setState(() => _status = "Encoded text copied! (${base64Str.length} chars)");
      } else {
        File f = File(_selectedFilePath!);
        int len = await f.length();
        if (len > 10 * 1024 * 1024) { 
           throw "File too big for Clipboard (>10MB). Save to file instead.";
        }
        base64Str = await compute(_encodeFileWorker, _selectedFilePath!);
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
        await compute(_saveEncodedTextWorker, [textInput, outputFile]);
        setState(() => _status = "Saved encoded text to $outputFile");
      } else {
        await compute(_streamEncodeFileWorker, [_selectedFilePath!, outputFile]);
        setState(() => _status = "Saved file output to $outputFile");
      }
    } catch (e) {
      setState(() => _status = "Error: $e");
    } finally {
      setState(() => _isWorking = false);
    }
  }

  // --- DECODER WORKERS & HELPERS ---
  static Future<String> _decodeTextWorker(String input) async {
    final bytes = base64Decode(input);
    return utf8.decode(bytes);
  }

  static Future<String> _decodeFileWorker(String path) async {
    final file = File(path);
    String content = await file.readAsString();
    content = content.replaceAll(RegExp(r'\s'), ''); // Clean
    final bytes = base64Decode(content);
    return utf8.decode(bytes);
  }

  static Future<void> _saveDecodedBytesWorker(List<dynamic> args) async {
    final String input = args[0];
    final String outputPath = args[1];
    final bool isFileSource = args[2];
    final outputFile = File(outputPath);
    final sink = outputFile.openWrite();

    final whitespacePattern = RegExp(r'\s');

    if (!isFileSource) {
      sink.add(base64Decode(input));
    } else {
      final inputFile = File(input);
      await inputFile.openRead()
          .transform(utf8.decoder) 
          .map((chunk) => chunk.replaceAll(whitespacePattern, '')) 
          .transform(const Base64Decoder()) 
          .pipe(sink);
    }
    await sink.close();
  }

  String? _detectExtension(Uint8List bytes) {
    if (bytes.length < 4) return null;
    bool match(List<int> magic) {
      if (bytes.length < magic.length) return false;
      for (int i = 0; i < magic.length; i++) {
        if (bytes[i] != magic[i]) return false;
      }
      return true;
    }
    if (match([0x89, 0x50, 0x4E, 0x47])) return 'png';
    if (match([0x25, 0x50, 0x44, 0x46])) return 'pdf';
    if (match([0xFF, 0xD8, 0xFF])) return 'jpg';
    if (match([0x50, 0x4B, 0x03, 0x04])) return 'zip';
    if (match([0x47, 0x49, 0x46, 0x38])) return 'gif';
    if (match([0x49, 0x44, 0x33])) return 'mp3';
    if (match([0x7B]) || match([0x5B])) return 'json';
    if (match([0x3C])) return 'xml';
    return null;
  }

  // --- DECODER UI LOGIC ---
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
      String result;
      if (hasText) {
        result = await compute(_decodeTextWorker, textInput);
      } else {
        result = await compute(_decodeFileWorker, _decodeSelectedFilePath!);
      }
      await Clipboard.setData(ClipboardData(text: result));
      setState(() => _decodeStatus = "Decoded text copied! (${result.length} chars)");
    } catch (e) {
      setState(() => _decodeStatus = "Error: Invalid Base64 or Not Text.");
    } finally {
      setState(() => _isDecoding = false);
    }
  }

  Future<void> _saveDecodedToFile() async {
    final textInput = _decodeCtrl.text.trim();
    final hasText = textInput.isNotEmpty;
    final hasFile = _decodeSelectedFilePath != null;

    if (!hasText && !hasFile) return;

    String detectedExt = 'bin'; 
    try {
      Uint8List headerBytes;
      String cleanStart = "";
      
      if (hasText) {
        cleanStart = textInput.length > 50 ? textInput.substring(0, 50) : textInput;
      } else {
        File f = File(_decodeSelectedFilePath!);
        final raf = await f.open();
        List<int> chars = await raf.read(100);
        await raf.close();
        cleanStart = utf8.decode(chars, allowMalformed: true).replaceAll(RegExp(r'\s'), '');
      }

      int remainder = cleanStart.length % 4;
      if (remainder > 0) {
        cleanStart = cleanStart.substring(0, cleanStart.length - remainder);
      }
      
      if (cleanStart.length >= 4) {
         headerBytes = base64Decode(cleanStart);
         String? ext = _detectExtension(headerBytes);
         if (ext != null) {
           detectedExt = ext;
         } else {
           try {
             utf8.decode(headerBytes);
             detectedExt = 'txt';
           } catch (_) {}
         }
      }
    } catch (e) {
      debugPrint("Header detection failed: $e");
    }

    String? outputFile = await FilePicker.platform.saveFile(
      dialogTitle: 'Save Decoded File',
      fileName: 'decoded_file.$detectedExt',
    );

    if (outputFile == null) return;

    setState(() { _isDecoding = true; _decodeStatus = "Decoding & Saving..."; });

    try {
      await compute(_saveDecodedBytesWorker, [
        hasText ? textInput : _decodeSelectedFilePath!,
        outputFile,
        !hasText // isFileSource
      ]);
      
      setState(() => _decodeStatus = "Saved decoded file to $outputFile");
    } catch (e) {
      setState(() => _decodeStatus = "Error: $e");
    } finally {
      setState(() => _isDecoding = false);
    }
  }

  void _onStatsChanged(String text) {
    setState(() {
      _statsChars = text.length;
      _statsTokens = (text.length / 4).ceil();
    });
  }

  void _compactText() {
    final text = _statsCtrl.text;
    if (text.isEmpty) return;
    
    final newText = text
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .join('\n');
        
    _statsCtrl.text = newText;
    _onStatsChanged(newText);
  }

  // ===========================================================================
  // CRYPTO LOGIC (AES-256)
  // ===========================================================================

  Future<void> _pickCryptoFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result != null) {
      setState(() {
        _cryptoSelectedFile = result.files.single.path;
        _cryptoStatus = "File selected: ${result.files.single.name}";
      });
    }
  }

  static Future<void> _cryptoWorker(List<dynamic> args) async {
    // args: [isEncrypt, keyString, inputPath, outputPath, isText, textInput]
    final bool isEncrypt = args[0];
    final String pass = args[1];
    final String? inputPath = args[2];
    final String outputPath = args[3];
    final bool isText = args[4];
    final String? textInput = args[5];

    // 1. Key Derivation (SHA-256 of Passphrase -> 32 bytes)
    final keyBytes = crypto.sha256.convert(utf8.encode(pass)).bytes;
    final key = enc.Key(Uint8List.fromList(keyBytes));

    // 2. Encrypter Setup
    // Note: We use PKCS7 padding by default in AESMode.cbc
    
    if (isEncrypt) {
      // ENCRYPT: Generate IV -> Encrypt -> Prepend IV
      final iv = enc.IV.fromLength(16);
      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
      
      List<int> inputBytes;
      if (isText) {
        inputBytes = utf8.encode(textInput!);
      } else {
        inputBytes = await File(inputPath!).readAsBytes();
      }

      final encrypted = encrypter.encryptBytes(inputBytes, iv: iv);
      
      // Output Format: IV (16 bytes) + Ciphertext
      final combined = Uint8List(16 + encrypted.bytes.length);
      combined.setRange(0, 16, iv.bytes);
      combined.setRange(16, combined.length, encrypted.bytes);
      
      await File(outputPath).writeAsBytes(combined);

    } else {
      // DECRYPT: Read IV (first 16) -> Decrypt Rest
      List<int> fileBytes;
      if (isText && textInput != null) {
         // If user pasted Base64 encoded ciphertext
         try {
           fileBytes = base64Decode(textInput.replaceAll(RegExp(r'\s'), ''));
         } catch (e) {
           throw "Invalid Base64 input";
         }
      } else {
         fileBytes = await File(inputPath!).readAsBytes();
      }

      if (fileBytes.length < 16) throw "Invalid Encrypted Data (Too short)";

      final iv = enc.IV(Uint8List.fromList(fileBytes.sublist(0, 16)));
      final ciphertext = enc.Encrypted(Uint8List.fromList(fileBytes.sublist(16)));
      
      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
      final decrypted = encrypter.decryptBytes(ciphertext, iv: iv);
      
      await File(outputPath).writeAsBytes(decrypted);
    }
  }

  Future<void> _executeCrypto() async {
    final pass = _cryptoPassCtrl.text;
    final hasFile = _cryptoSelectedFile != null;
    final hasText = _cryptoInputCtrl.text.isNotEmpty;

    if (pass.isEmpty) {
      setState(() => _cryptoStatus = "Error: Passphrase required.");
      return;
    }
    if (!hasFile && !hasText) {
      setState(() => _cryptoStatus = "Error: No input provided.");
      return;
    }

    String? outputFile = await FilePicker.platform.saveFile(
      dialogTitle: _isEncryptMode ? 'Save Encrypted File' : 'Save Decrypted File',
      fileName: _isEncryptMode ? 'secret.enc' : 'decrypted_file',
    );

    if (outputFile == null) return;

    setState(() {
      _isCryptoWorking = true;
      _cryptoStatus = _isEncryptMode ? "Encrypting..." : "Decrypting...";
    });

    try {
      await compute(_cryptoWorker, [
        _isEncryptMode,
        pass,
        _cryptoSelectedFile,
        outputFile,
        hasText,
        hasText ? _cryptoInputCtrl.text : null
      ]);
      
      setState(() => _cryptoStatus = "Success! Saved to $outputFile");
    } catch (e) {
      setState(() => _cryptoStatus = "Error: $e");
    } finally {
      setState(() => _isCryptoWorking = false);
    }
  }

  // ===========================================================================
  // UI BUILD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    // Nested NavigationView to simulate "Tabs" or "Pivots" cleanly
    return NavigationView(
      pane: NavigationPane(
        selected: _tabIndex,
        onChanged: (index) => setState(() => _tabIndex = index),
        displayMode: PaneDisplayMode.top, // This creates the "Pivot" tab look
        items: [
          PaneItem(
            icon: const Icon(FluentIcons.file_code),
            title: const Text("Encoders & Tools"),
            body: ScaffoldPage(
              content: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12),
                child: _buildEncodersTab(),
              ),
            ),
          ),
          PaneItem(
            icon: const Icon(FluentIcons.lock),
            title: const Text("Cryptography"),
            body: ScaffoldPage(
              content: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12),
                child: _buildCryptoTab(FluentTheme.of(context)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEncodersTab() {
    final theme = FluentTheme.of(context);
    final hasEncoderInput = _encodeCtrl.text.isNotEmpty || _selectedFilePath != null;
    final hasDecoderInput = _decodeCtrl.text.isNotEmpty || _decodeSelectedFilePath != null;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- ENCODER CARD ---
          _buildCard(theme, "Base64 Encoder", FluentIcons.file_code, [
            const Text("Convert binary files (Images, PDFs) or text to Base64.", style: TextStyle(fontSize: 12)),
            const SizedBox(height: 16),
            
            TextBox(
              controller: _encodeCtrl,
              placeholder: "Type or paste text to encode...",
              maxLines: 3,
              minLines: 2,
              style: const TextStyle(fontFamily: 'Consolas', fontSize: 11),
              onChanged: (v) => setState(() {}),
            ),
            
            const SizedBox(height: 12),

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

            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                Button(
                  onPressed: _isWorking ? null : _pasteToEncoder,
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(FluentIcons.paste, size: 12), SizedBox(width: 6), Text("Paste Clipboard")]),
                ),
                Button(
                  onPressed: _isWorking ? null : _pickFile,
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(FluentIcons.folder_open, size: 12), SizedBox(width: 6), Text("Browse File")]),
                ),
                FilledButton(
                  onPressed: (_isWorking || !hasEncoderInput) ? null : _copyEncodedToClipboard,
                  child: const Text("Copy Encoded"),
                ),
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
            
            TextBox(
              controller: _decodeCtrl,
              placeholder: "Paste Base64 string here...",
              maxLines: 3, 
              minLines: 2,
              style: const TextStyle(fontFamily: 'Consolas', fontSize: 11),
              onChanged: (v) => setState(() {}),
            ),
            
            const SizedBox(height: 12),

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

            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                Button(
                  onPressed: _isDecoding ? null : _pasteToDecoder,
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(FluentIcons.paste, size: 12), SizedBox(width: 6), Text("Paste Clipboard")]),
                ),
                Button(
                  onPressed: _isDecoding ? null : _pickDecodeFile,
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(FluentIcons.folder_open, size: 12), SizedBox(width: 6), Text("Browse File")]),
                ),
                FilledButton(
                  onPressed: (_isDecoding || !hasDecoderInput) ? null : _copyDecodedToClipboard,
                  child: const Text("Copy Decoded"),
                ),
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
    );
  }

  Widget _buildCryptoTab(FluentThemeData theme) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCard(theme, "AES-256 (CBC)", FluentIcons.lock, [
            const Text("Vendor-compliant AES encryption. \nPrepends 16-byte IV to ciphertext. Passphrase hashed via SHA-256.", style: TextStyle(fontSize: 12)),
            const SizedBox(height: 16),

            // Toggle
            Row(
              children: [
                RadioButton(
                  checked: _isEncryptMode,
                  onChanged: (v) => setState(() => _isEncryptMode = true),
                  content: const Text("Encrypt"),
                ),
                const SizedBox(width: 16),
                RadioButton(
                  checked: !_isEncryptMode,
                  onChanged: (v) => setState(() => _isEncryptMode = false),
                  content: const Text("Decrypt"),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Passphrase
            PasswordBox(
              controller: _cryptoPassCtrl,
              placeholder: "Secret Passphrase (Required)",
              revealMode: PasswordRevealMode.peek,
            ),
            const SizedBox(height: 16),

            // Input Text (Optional if file selected)
            TextBox(
              controller: _cryptoInputCtrl,
              placeholder: _isEncryptMode ? "Enter text to encrypt (or select file below)..." : "Paste Base64 ciphertext (or select file below)...",
              maxLines: 3,
              minLines: 2,
              style: const TextStyle(fontFamily: 'Consolas', fontSize: 11),
            ),
            const SizedBox(height: 12),

            // File Picker
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
                      _cryptoSelectedFile ?? "No file selected (using text input)...",
                      style: TextStyle(
                        fontFamily: 'Consolas',
                        color: _cryptoSelectedFile == null ? theme.resources.textFillColorTertiary : theme.resources.textFillColorPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (_cryptoSelectedFile != null)
                    IconButton(
                      icon: const Icon(FluentIcons.clear, size: 12),
                      onPressed: () => setState(() {
                        _cryptoSelectedFile = null;
                      }),
                    ),
                  const SizedBox(width: 8),
                  Button(
                    onPressed: _pickCryptoFile,
                    child: const Icon(FluentIcons.folder_open, size: 12),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Execute
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _isCryptoWorking ? null : _executeCrypto,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: _isCryptoWorking 
                    ? const SizedBox(height: 16, width: 16, child: ProgressRing(strokeWidth: 2, activeColor: Colors.white))
                    : Text(_isEncryptMode ? "ENCRYPT & SAVE" : "DECRYPT & SAVE", style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ),

            const SizedBox(height: 12),
            if (_cryptoStatus != "Ready")
              Text(_cryptoStatus, style: TextStyle(
                fontFamily: 'Consolas',
                fontSize: 11,
                color: _cryptoStatus.startsWith("Error") ? Colors.red : theme.accentColor,
                fontWeight: FontWeight.bold,
              )),
          ]),
        ],
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