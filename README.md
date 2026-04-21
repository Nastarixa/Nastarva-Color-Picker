# 🎨 Nastarva Color Picker

A fast, lightweight **color picker + palette manager** built with AutoHotkey v2.

Nastarva Color Picker is more than a picker — it’s a **color workflow system** designed to help you capture, organize, and reuse colors with structured roles like **Base, Highlight, and Shadow**.

---

## ✨ Features

### 🎯 Real-Time Color Picker
- Hover anywhere to instantly detect colors
- Stable sampling (prevents flicker noise)
- Live preview with HEX + RGB

---

### 📋 Smart Clipboard Copy
- **Click / Middle Click** → Copy HEX  
- **Ctrl + Click / Ctrl + Middle Click** → Copy RGB  
- Instant toast feedback

---

### 🧠 Multi-Palette System
- Create unlimited palettes
- Reorder palettes (Up / Down)
- Delete & manage easily
- Each palette is **independent**

---

### 🔢 Quick Palette Switching
- `Ctrl + Alt + 1 → 9` switches palettes by order
- Fully dynamic (based on palette list, not fixed names)

---

### 📦 Per-Palette Settings
Each palette has its own:
- **History size (History Max)**
- **Grid layout (Columns)**

Settings are:
- Saved automatically
- Restored when switching palettes
- Applied instantly to UI

---

### 🧩 Color Roles
Assign meaning to colors:
- ⚫ Base  
- ✨ Highlight  
- ⬛ Shadow  
- ♻️ 2 Shadow  
- 💞 Hi Shadow  

Helps build consistent design systems.

---

### 📌 Pin System
- Pin important colors to keep them at the top
- Works across sorting and history updates

---

### 🕘 Smart History Tracking
- Recent colors are automatically stored
- Respects per-palette history limits
- Old entries trimmed automatically

---

### 🖱️ Fast Interaction
- **Click** → Copy color  
- **Right Click** → Role / Pin menu  
- **Hover** → Preview color info  
- Designed for minimal friction workflow

---

### 💬 Animated Toast Feedback
- Smooth slide animation
- Shows copy/save status
- Context-aware (HEX / RGB)

---

### 🧱 Responsive Grid Layout
- Grid adapts based on:
  - Column setting per palette
  - History size
- Clean and consistent spacing

---

## ⌨️ Hotkeys

| Key | Action |
|-----|--------|
| `Ctrl + Alt + P` | Toggle color picker |
| `Ctrl + Alt + O` | Toggle history panel |
| `Ctrl + Alt + I` | Toggle palette manager |
| `Ctrl + Alt + 1–9` | Switch palette by order |
| `Middle Click` | Save / copy HEX |
| `Ctrl + Middle Click` | Save / copy RGB |

---

## 🧪 How It Works

- Colors are stored as **HEX**
- RGB is generated for display and clipboard use
- Each palette is saved as its own file
- Metadata (like `historyMax`, `columns`) is stored per palette


---

## 🧰 Palette Manager

Simple and focused UI:

- Select palette from list
- Adjust:
  - History size
  - Columns
- Click **Apply** to update instantly

Actions:
- Switch palette
- Create new
- Delete
- Reorder (Up / Down)

---

## 🎯 Design Philosophy

Nastarva is built around:

- ⚡ Speed — minimal clicks, instant feedback  
- 🧠 Structure — colors have meaning (roles)  
- 🧩 Flexibility — multiple palettes, custom layouts  
- 🧘 Simplicity — clean UI, no clutter  

---

## ⚠️ Disclaimer

This AutoHotkey script was created with assistance from AI and may require adjustments depending on your setup or workflow.
