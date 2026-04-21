# Nastarva Color Picker

Nastarva Color Picker is an AutoHotkey v2 tool for picking, organizing, and exporting colors.

It is built for character-sheet and art-reference workflows where colors are not only saved, but also grouped into palettes, sections, and role-based shade sets such as `Base`, `Highlight`, `Shadow`, `Hi Shadow`, and `2 Shadow`.

## What It Does

- Live screen color picker with HEX and RGB copy
- Multiple palettes stored as text files
- Section-based micro palettes inside each palette
- Docked or undocked section windows
- Pinned colors with drag reorder and cross-section move
- Palette import from image file
- Palette import from screenshot snip
- Export to `txt`, `json`, `ini`, `csv`, and `png`

## Requirements

- Windows
- AutoHotkey v2
- PowerShell
- Windows snipping support for `ms-screenclip:`

## Main Hotkeys

| Hotkey | Action |
| --- | --- |
| `Ctrl + Alt + P` | Toggle live color picker |
| `Ctrl + Alt + O` | Toggle color palette |
| `Ctrl + Alt + I` | Toggle palette manager |
| `Ctrl + Alt + U` | Start screenshot snip import |
| `Ctrl + Alt + 1` to `Ctrl + Alt + 9` | Switch palettes by order |
# After Toggle Color Picker
| `Middle Click` | Save and copy Hex Color |
| `Ctrl + Middle Click` | Save and copy RGB Color |
# After Toggle Color Palette, in Color Palette
| `Left Click` | Copy Hex Color |
| `Ctrl + Left Click` | Copy RGB Color |
| `Right Click` | Open Color Palette Menu |
| `Drag` | Reorder Pinned Colors |

## Core Workflow

### 1. Pick colors live

- Turn on the picker with `Ctrl + Alt + P`
- Hover any pixel on screen
- Middle click to save the current color
- `Ctrl + Middle Click` copies RGB

### 2. Organize colors

- Open history with `Ctrl + Alt + O`
- Each section is its own small panel
- Click the circle in a section header to make it the active target section
- New picked colors go to the selected section
- Right click a color to set role, pin, move, or delete
- Toast notifications appear at the top-left of the current monitor for better visibility

### 3. Manage palettes

- Open palette manager with `Ctrl + Alt + I`
- Create, rename, duplicate, delete, and reorder palettes
- Set per-palette:
  - max items per section
  - columns
  - GUI mode: `Docked` or `Undocked`
  - role order

### 4. Import from screenshot or image

- Use `Ctrl + Alt + S`, `Ctrl + Alt + U`, or the `Snip` button to capture a palette area
- Or use `Import` to load a saved image file
- The importer will try to:
  - detect solid swatch blocks
  - split them into sections
  - assign likely shade roles
  - pin imported colors automatically
  - use nearby OCR text as section names when possible

## GUI Modes

### Docked

- Section panels stack from the bottom-left area
- Good for compact workflows
- Panels are not draggable in this mode

### Undocked

- Each section is a floating panel
- Panels can be moved freely
- Positions are remembered per palette and section

## Section Features

- Create section
- Rename section
- Duplicate section
- Delete section
- Select target section for new picks
- Drag pinned colors between sections
- Drop pinned colors into empty sections

## Export Formats

- `TXT`
- `JSON`
- `INI`
- `CSV`
- `PNG`

PNG export includes:

- palette name
- section grouping
- swatches
- RGB values
- role labels

## File Layout

Main script:

- [Nastarva Color Picker.ahk](D:/Github/Nastarva-Color-Picker/Nastarva%20Color%20Picker.ahk)

Core modules:

- [app_core.ahk](D:/Github/Nastarva-Color-Picker/src/core/app_core.ahk)
- [history_state.ahk](D:/Github/Nastarva-Color-Picker/src/core/history_state.ahk)
- [persistence.ahk](D:/Github/Nastarva-Color-Picker/src/core/persistence.ahk)

Feature modules:

- [picker.ahk](D:/Github/Nastarva-Color-Picker/src/features/picker.ahk)
- [history_gui.ahk](D:/Github/Nastarva-Color-Picker/src/features/history_gui.ahk)
- [palette_manager.ahk](D:/Github/Nastarva-Color-Picker/src/features/palette_manager.ahk)
- [palette_export.ahk](D:/Github/Nastarva-Color-Picker/src/features/palette_export.ahk)
- [palette_image_import.ps1](D:/Github/Nastarva-Color-Picker/src/features/palette_image_import.ps1)
- [palette_png_export.ps1](D:/Github/Nastarva-Color-Picker/src/features/palette_png_export.ps1)

Data:

- palette files are stored in `color\`
- palette order is stored in `color\palettes.txt`

## Palette Text Format

Example:

```txt
#META|version=3.0|historyMax=20|maxCols=4|guiMode=undocked
#ROLEORDER|Base,Highlight,Shadow,Hi Shadow,2 Shadow
#SECTION|Default
#SECTION|Hair
FFCCAA|255,204,170|Hair Base|Base|1|1|Hair|171369999-1-1234
CC9966|204,153,102|Hair Shadow|Shadow|1|2|Hair|171369999-2-5678
```

Color row fields:

1. `hex`
2. `rgb`
3. `name`
4. `role`
5. `pinned`
6. `pinOrder`
7. `section`
8. `item id`

## Current Limits

- Image role assignment is heuristic, not guaranteed
- OCR section naming is best-effort and depends on Windows OCR quality
- Imported palette layouts with unusual shapes may still need manual cleanup
- A screenshot import can differ by 1 RGB value from live picker if the captured image is slightly different from the exact on-screen pixel

## Limit Test Notes

Checked in this final pass:

- AutoHotkey v2 validation passes for the main script
- Screenshot/image import runs on multiple reference images
- Docked and undocked section logic was reviewed
- Pinned cross-section drag logic was reviewed and patched earlier in this thread

Known soft spot after testing:

- Automatic role assignment from imported images is the least reliable part because palette layouts vary a lot

## Running The Script

Run:

```powershell
AutoHotkey64.exe "D:\Github\Nastarva-Color-Picker\Nastarva Color Picker.ahk"
```

## License

See [LICENSE](D:/Github/Nastarva-Color-Picker/LICENSE).
