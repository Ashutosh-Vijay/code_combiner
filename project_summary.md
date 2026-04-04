# ContextForge — Project Summary

**For use in the apinsity portfolio. Subdomain: `contextforge.apinsity.com`**

---

## What It Is

**ContextForge** is a Windows desktop application built with Flutter that solves a very specific, very real problem: preparing codebases to paste into an LLM's context window. Instead of manually copying file after file, you drop a folder in, pick what to include, and hit one button. You get a clean, structured dump of your entire codebase — file tree and all — ready for Claude, GPT, or whatever model you're using.

It's a developer tool, built by a developer, out of frustration with bad tooling.

---

## What It Does

- **Drag & drop a project folder** — scans it instantly using Dart isolates (no UI freeze)
- **Smart exclusion system** — automatically skips `node_modules`, `build`, `.git`, binary files, and anything else you don't want; fully configurable per-project via a `.exclusion_settings.json` file that travels with the project
- **GitIgnore-aware** — parses `.gitignore` and respects it during scans
- **Project type presets** — one click to apply the right exclusion profile for Standard, MuleSoft, Python, or React projects
- **Real-time token estimation** — shows how many tokens your selection will consume, with a color-coded budget indicator (green → orange → red)
- **Multiple output formats** — Plain text, XML (with CDATA wrapping), or Markdown code blocks
- **File tree generation** — outputs a structured file tree alongside the combined content
- **Copy to clipboard or save to disk** — disk writes use a streaming approach (chunk-by-chunk) so even massive codebases don't blow up RAM
- **File search / filter** — search bar to quickly find files in large projects
- **Themes** — dark, light, pitch-black, and multiple accent color flavors, all backed by Windows Mica/Acrylic glass effects

---

## How It Was Built

| Layer | Tech |
|---|---|
| Framework | Flutter (Windows desktop) |
| UI Library | `fluent_ui` — Windows 11 Fluent Design System |
| Windowing | `bitsdojo_window` + `flutter_acrylic` for Mica/glass chrome |
| State | `provider` (ChangeNotifier) |
| Persistence | `shared_preferences` (global) + per-project `.exclusion_settings.json` |
| File I/O | Dart `dart:io` with `compute()` isolates for non-blocking scans |
| Fonts | Google Fonts |
| Drag & Drop | `desktop_drop` |
| AES Encryption | `encrypt` + `crypto` (Phase 4 identity features) |

Architecture is clean and separated: `AppState` is the manager, `SettingsService` handles persistence, `FileService` handles heavy I/O in isolates, and pages are thin UI shells.

---

## Development Phases

The project was built in four deliberate phases:

1. **Phase 1 — Glass Stack**: Core window chrome, Mica/Acrylic effects, fluent UI foundation
2. **Phase 2 — Exclusion Mechanism**: Folder/pattern/file exclusion, GitIgnore parsing, per-project config files
3. **Phase 3 — Utilities & File Tree**: Tree generation, search/filter, streaming disk writes, token estimation
4. **Phase 4 — Identity**: AES-256 encryption, URL launcher, about page, polished release

---

## Why It Exists

Every time you want to give Claude your codebase, you have to either paste files one by one, use some half-working VSCode extension, or write a bash script. ContextForge is the proper desktop app that should have existed from the start — native, fast, configurable, and with a UI that doesn't look like it was thrown together in an afternoon.

---

## Key Stats

- **Language**: Dart / Flutter
- **Platform**: Windows (x64 desktop)
- **Output formats**: Plain text, XML, Markdown
- **Supported project types**: Standard, MuleSoft, Python, React
- **Repo**: `cc.apinsity.com` → GitHub
