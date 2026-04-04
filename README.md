# ContextForge

A Windows desktop app for preparing codebases as LLM context. Drop a folder, pick your files, copy a structured dump of your entire codebase — file tree included — ready to paste into Claude, GPT, or whatever you're using.

Built with Flutter and Windows 11 Mica/Glass UI.

---

## Features

**Smart scanning**
- Recursively scans project folders, skipping binaries, build artifacts, and anything in `.gitignore`
- Per-project exclusion config saved as `.exclusion_settings.json` alongside your code
- Project type presets: Standard, MuleSoft, Python, React

**Output**
- Formats: XML (CDATA-wrapped), Markdown, Plain Text
- Generates a file tree alongside the content
- Streams large codebases to disk chunk-by-chunk — no RAM spikes

**UI**
- Windows 11 Mica/Acrylic glass chrome
- Theme flavors: Standard Glass, Pitch Black, Ocean Depth, Cyber Forest
- Token budget indicator — color-coded estimate of context size
- Drag & drop folder loading

---

## Installation

Download the latest zip from the [Releases](https://github.com/Ashutosh-Vijay/ContextForge/releases) page, extract, and run `ContextForge.exe`. No installer.

**Build from source:**

```bash
flutter pub get
flutter run -d windows --release
```

Requires Flutter SDK with Windows desktop enabled.

---

## Exclusions

The app ships with sensible defaults and respects `.gitignore` automatically. You can manage exclusions per-project from the Exclusions tab — folders, file patterns, or specific files.

Default excluded folders: `node_modules`, `.git`, `build`, `dist`, `.next`, `venv`, `__pycache__`

---

## License

MIT
