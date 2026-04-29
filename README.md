# 🎨 Nastarxa Color Picker

A **color palette manager** for game developers, digital artists, and designers — built with [AutoHotkey v2](https://www.autohotkey.com/).

![Version](https://img.shields.io/badge/version-3.5-blue)
![Platform](https://img.shields.io/badge/platform-Windows-lightgrey)
![Language](https://img.shields.io/badge/language-AutoHotkey_v2-green)

---

## ✨ Overview

Nastarxa Color Picker is a powerful color workflow tool for fast creative iteration:

- Capture colors directly from screen
- Organize into structured palettes
- Assign semantic roles (Base, Shadow, Outline, etc.)
- Validate accessibility (WCAG)
- Generate gradients, harmonies, and variations

---

## 🚀 Features

### 🎯 Color Picker
- Live eyedropper with real-time HEX / RGB (`Ctrl + Alt + P`)
- Middle-click instant save from screen
- Clipboard HEX auto-detection

---

### 🗂 Palette System
- Multiple named palettes
- Section-based grouping (collapsible panels)
- Pin important colors
- Drag & drop reorder system
- Merge & compare palettes

---

### 🎭 Color Roles System
- Base, Highlight, Shadow, Hi Shadow, 2 Shadow, Mask, Outline, Black
- Batch role assignment (multi-select)
- Custom role ordering

---

### 🧪 Color Tools
- 🎨 Harmony Generator (Complementary, Analogous, Triadic, Split, Tetradic)
- ♿ WCAG Contrast Checker (AA/AAA + bad pair detection)
- 🌈 Gradient Generator (2–20 steps)
- 👁 Color Blindness Simulation (4 modes)

---

### 📥 Import / Export
- Screenshot capture (`Ctrl + Alt + U`)
- Image color extraction (PNG / JPG / BMP)
- Folder batch import
- Pre-import review system

Export formats:
TXT • JSON • INI • CSV • PNG • ASE

---

### 📦 Templates
- Material Design
- Tailwind CSS
- Pastel Soft
- RPG UI
- Neon Cyberpunk
- and more

Apply as:
- New palette
- Insert into palette
- Replace current palette

---

### ⭐ Favorites
- Star/unstar colors (`Ctrl + Alt + F`)
- Persistent across sessions

---

### 🧭 Display Modes
- Normal / Compact / Square
- HEX or RGB primary mode
- Docked or floating panels

---

## ⌨️ Hotkeys

### Global
| Shortcut | Action |
|----------|--------|
| Ctrl + Alt + P | Toggle Color Picker |
| Ctrl + Alt + O | Toggle Palette |
| Ctrl + Alt + U | Screenshot Import |
| Ctrl + Alt + I | Palette Manager |
| Ctrl + Alt + F | Favorites |
| Ctrl + Alt + V | Paste HEX |
| Ctrl + Alt + 1–9 | Switch Palette |

---

### Picker Mode
| Input | Action |
|------|--------|
| Middle Mouse | Save HEX |
| Ctrl + Middle Mouse | Save RGB |

---

### Palette Mode
| Input | Action |
|------|--------|
| Click | Copy value |
| Ctrl + Click | Copy alternate format |
| Shift + Click | Multi-select |
| Right Click | Context menu |
| Middle Click | Role assignment |
| Arrow Keys | Navigate |
| Enter | Copy |
| Space | Toggle selection |

---

## 🖼 Image Preview

![Palette Manager](docs/images/1.png)
![Bottom Palette](docs/images/2.png)
![Palette on Side](docs/images/3.png)
![Bottom Palette 100 Color](docs/images/4.png)
![Split Undock Palett](docs/images/5.png)
![Split Undock Palette](docs/images/6.png)
![Information of the Color](docs/images/7.png)
![Additional Color Palette for Drawing Software](docs/images/8.png)
![Screenshot Import Result](docs/images/9.png)

---

## 🧱 Project Structure

```
Nastarxa Color Picker.ahk
src/
  core/
  features/
  utils/
  ui/
color/
templates/
```
Data:
- palette files are stored in `color\`
- palette order is stored in `color\palettes.txt`

---

## ⚙️ Requirements

- Windows 10 / 11
- AutoHotkey v2 (64-bit)
- PowerShell
- Windows Snipping Tool (ms-screenclip support)

https://www.autohotkey.com/

---

## 📦 Installation

```bash
git clone <repo-url>
cd nastarxa-color-picker
```

Run:

```
Nastarva Color Picker.ahk
```

---

## 📄 License

MIT
See [LICENSE](/LICENSE).

---

## ⚠️ Disclaimer

This project was developed with the assistance of AI tools.
AI was used to support code writing, refactoring, and documentation, while the design direction, features, and final implementation were guided and reviewed by the author.
