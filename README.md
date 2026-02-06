Code Combiner (God Mode)

"Stop pasting node_modules into ChatGPT."

A high-performance, aesthetically pleasing utility designed to prepare massive codebases for Large Language Model (LLM) context windows. Built with Flutter, Mica/Glass UI, and pure rage against bad tooling.

🚀 Features

🧠 Smart Context Management

Token Budget Visualizer: Instantly see if your selection fits into 32k/128k context windows.

Intelligent Scanning: Recursively scans folders while ignoring binary files (.exe, .png) and junk folders (node_modules, .git) by default.

ASCII Tree Generator: Auto-generates a file tree map so the AI understands your project structure.

🎨 "Glass God" UI

Windows 11 Mica Effect: True translucent background integration.

Themed Flavors: Switch between Standard Glass, Pitch Black (OLED), Ocean Depth, and Cyber Forest.

Drag & Drop: Yeet a folder onto the window to start scanning immediately.

🛠️ The Utility Belt

Base64 Encoder/Decoder: Process text or files directly to/from Base64 for safe transport.

Token Scratchpad: Quick-paste area to check token counts and strip empty lines.

Multiple Formats: Export context as XML (Claude/Gemini optimized), Markdown, or Plain Text.

📦 Installation

Download the latest release from the Releases Page.

Build from Source:

flutter pub get
flutter run -d windows --release


⚡ Key Shortcuts

Drag & Drop: Drop any folder to scan it.

Toggle Selection: Click list items to include/exclude.

Exclude Unselected: Banish all unchecked files to the exclusion list permanently.

🛑 Exclusions

The app comes pre-loaded with a list of common "trash" folders (.git, build, dist). You can manage these in the Exclusions tab.

Defaults: node_modules, venv, .next, __pycache__

GitIgnore: Respects your project's .gitignore automatically.

👤 Author

Ashutosh Vijay

License: MIT