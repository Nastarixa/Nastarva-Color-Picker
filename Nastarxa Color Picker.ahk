#Requires AutoHotkey v2.0
#SingleInstance Force
#UseHook
Persistent

#Include "src/utils/color_format.ahk"
#Include "src/utils/color_names.ahk"
#Include "src/utils/color_calc.ahk"
#Include "src/core/app_core.ahk"
#Include "src/core/history_state.ahk"
#Include "src/core/persistence.ahk"
#Include "src/ui/cell.ahk"
#Include "src/features/palette_gui.ahk"
#Include "src/features/picker.ahk"
#Include "src/features/palette_manager.ahk"
#Include "src/features/palette_templates.ahk"
#Include "src/features/display_settings.ahk"
#Include "src/features/actions.ahk"
#Include "src/features/palette_export.ahk"
#Include "src/features/section_handler.ahk"
#Include "src/features/role_handler.ahk"
#Include "src/features/color_dialogs.ahk"
#Include "src/features/import_review.ahk"
#Include "src/features/favorites.ahk"
TraySetIcon "Icon.ico"

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
LoadFavorites(App)
InitEvents(App)
InitKeyboardNav(App)
OnExit(HandleAppExit)
ShowHotkeyHelp(App)

; =========================================================
; HOTKEYS (MUST BE GLOBAL SCOPE IN AHK v2)
; =========================================================
^!p::TogglePicker(App)
^!o::TogglePalette(App)
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
^!f::ShowFavoritesWindow(App)
^!v::PasteColorFromClipboard(App)

Hotkey("~Left", (*) => App.historyVisible && NavigateColorCell(App, -1))
Hotkey("~Right", (*) => App.historyVisible && NavigateColorCell(App, 1))
Hotkey("~Up", (*) => App.historyVisible && ChangeRoleByKeyboard(App, -1))
Hotkey("~Down", (*) => App.historyVisible && ChangeRoleByKeyboard(App, 1))
Hotkey("~Home", (*) => App.historyVisible && NavigateKeyboard(App, "Home"))
Hotkey("~End", (*) => App.historyVisible && NavigateKeyboard(App, "End"))
Hotkey("~Enter", (*) => App.historyVisible && EnterSelectedColor(App))

~MButton::
{
    if App.HasOwnProp("roleMenuGui") && SafeGetGuiHwnd(App.roleMenuGui)
        return
    if HandleSectionHeaderMiddleClick(App)
        return
    if HandleHistoryMiddleClick(App)
        return
    SaveColor(App)
}

~^MButton::SaveColor(App)

HandleAppExit(*) {
    global App
    try PersistActivePaletteState(App)
}
