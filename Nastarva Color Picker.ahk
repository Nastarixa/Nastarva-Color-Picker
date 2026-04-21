#Requires AutoHotkey v2.0
#SingleInstance Force
#UseHook
Persistent

#Include "src/utils/color_format.ahk"
#Include "src/utils/color_names.ahk"
#Include "src/core/app_core.ahk"
#Include "src/core/history_state.ahk"
#Include "src/core/persistence.ahk"
#Include "src/features/picker.ahk"
#Include "src/features/history_gui.ahk"
#Include "src/features/palette_manager.ahk"
#Include "src/features/palette_export.ahk"

; =========================================================
; GLOBAL STATE
; =========================================================
global App := InitApp()
global _emitLock := false
DllCall("User32\SetProcessDpiAwarenessContext", "Ptr", -4)
CoordMode("Mouse", "Screen")
CoordMode("Pixel", "Screen")

InitPalettes(App)
App.activePalette := App.palettes["Default"]
LoadHistory(App)
InitEvents(App)
ShowHotkeyHelp(App)

; =========================================================
; HOTKEYS (MUST BE GLOBAL SCOPE IN AHK v2)
; =========================================================
^!p::TogglePicker(App)
^!o::ToggleHistory(App)
^!u::StartPaletteScreenshotImport(App)

^!1::SwitchPaletteByIndex(App, 1)
^!2::SwitchPaletteByIndex(App, 2)
^!3::SwitchPaletteByIndex(App, 3)
^!4::SwitchPaletteByIndex(App, 4)
^!5::SwitchPaletteByIndex(App, 5)
^!6::SwitchPaletteByIndex(App, 6)
^!7::SwitchPaletteByIndex(App, 7)
^!8::SwitchPaletteByIndex(App, 8)
^!9::SwitchPaletteByIndex(App, 9)
^!i::TogglePaletteManager(App)

~MButton::SaveColor(App)
~^MButton::SaveColor(App)

