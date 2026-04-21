#Requires AutoHotkey v2.0
#SingleInstance Force
#UseHook
Persistent

#Include "src/utils/color_names.ahk"

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

; =========================================================
; HOTKEYS (MUST BE GLOBAL SCOPE IN AHK v2)
; =========================================================
^!p::TogglePicker(App)
^!o::ToggleHistory(App)

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
; =========================================================
; APP INIT
; =========================================================
InitApp() {
    return { 
        version: "3.0",
        CheckActive: false,
        historyVisible: false,
        g_UsePhysicalCoords: true,

        historyMax: 0,

        pickGui: 0,
        historyGui: 0,
        roleMenuGui: 0,
        lastHex: "",
        stableCount: 0,
        selectedRole: "Base",

        palettes: Map(),
        paletteOrder: [],
        paletteGui: 0, 
        activePalette: 0,
        lastSize: { w: 0, h: 0 },
        events: Map(),
        toastTick: 0,
        lastCopyType: "",

        ui: {
            controls: Map(),
            generation: 0,
            itemW: 200,
            itemH: 30,
            gap: 4,
            cols: 10,
            rows: 3
        },

        toast: {
            gui: 0,
            running: false,
            startY: 0,
            curY: 0,
            endY: 0,
            x: 0,
            step: 0
        }
    }
}

InitEvents(app) {
    app.events["history_changed"] := [(*) => RefreshHistoryUI(app)]
}


Emit(app, name) {
    global _emitLock

    if _emitLock
        return

    if !app.events.Has(name)
        return

    _emitLock := true
    try {
        for _, fn in app.events[name]
            fn()
    } finally {
        _emitLock := false
    }
}
DebouncedRefresh(app) {
    static pending := false

    if pending
        return

    pending := true
    SetTimer(() => (
        pending := false,
        RefreshHistoryUI(app)
    ), -50)
}
; =========================================================
; PIXEL CAPTURE
; =========================================================
GetCursorPosForCapture(app, &x, &y) {
    pt := Buffer(8, 0)

    ; always get logical cursor position (stable in AHK GUI space)
    DllCall("GetCursorPos", "Ptr", pt)

    x := NumGet(pt, 0, "Int")
    y := NumGet(pt, 4, "Int")
}

GetColorAtPhysical(x, y) {
    hDC := DllCall("GetDC", "Ptr", 0, "Ptr")
    if (!hDC)
        return -1

    bgr := DllCall("GetPixel", "Ptr", hDC, "Int", x, "Int", y, "UInt")
    DllCall("ReleaseDC", "Ptr", 0, "Ptr", hDC)

    if (bgr = 0xFFFFFFFF)
        return -1

    return ((bgr & 0xFF) << 16)
         | (bgr & 0x00FF00)
         | ((bgr >> 16) & 0xFF)
}
EnterDpiCaptureContext(app) {
    if (!app.g_UsePhysicalCoords)
        return 0
    return DllCall("User32\SetThreadDpiAwarenessContext", "Ptr", -4, "Ptr")
}

LeaveDpiCaptureContext(oldCtx) {
    if (oldCtx)
        DllCall("User32\SetThreadDpiAwarenessContext", "Ptr", oldCtx, "Ptr")
}

GetColorUnderCursor(app) {
    old := EnterDpiCaptureContext(app)
    try {
        GetCursorPosForCapture(app, &x, &y)
        color := GetColorAtPhysical(x, y)

        if (color = -1)
            return "000000"

        return Format("{:06X}", color)
    } finally {
        LeaveDpiCaptureContext(old)
    }
}
GetMonitorFromPoint(x, y) {
    count := MonitorGetCount()
    Loop count {
        MonitorGetWorkArea(A_Index, &L, &T, &R, &B)
        if (x >= L && x <= R && y >= T && y <= B)
            return A_Index
    }
    return 1
}
DetectColorType(val) {
    if RegExMatch(val, "^[0-9A-Fa-f]{6}$")
        return "hex"
    if RegExMatch(val, "^\d+,\s*\d+,\s*\d+$")
        return "rgb"
    return "unknown"
}
; =========================================================
; HOTKEY ACTIONS
; =========================================================
TogglePicker(app) {
    app.CheckActive := !app.CheckActive

    if app.CheckActive
        SetTimer(() => PickerTick(app), 10)
    else if app.pickGui
        app.pickGui.Hide()
}

PickerTick(app) {
    if !app.CheckActive
        return

    g := app.pickGui

    hex := GetColorUnderCursor(app)

    ; stability check FIRST
    if (hex = app.lastHex)
        app.stableCount++
    else {
        app.lastHex := hex
        app.stableCount := 0
    }

    if (app.stableCount < 2)
        return

    ; GUI init AFTER stable
    if !IsObject(g) {
        g := Gui("+AlwaysOnTop -Caption +ToolWindow")
        g.BackColor := "202020"
        g.SetFont("s10", "Consolas")

        g.preview := g.AddProgress("x8 w40 h60")
        g.txt := g.AddText("x+8 yp w160 h65 cFFFFFF")

        app.pickGui := g
    }

    ; =========================
    ; 2. COLOR READ (NO CHANGE HERE)
    ; =========================
    hex := GetColorUnderCursor(app)
    static lastHex := ""

    if (hex != lastHex) {
        rgb := HexToRGB(hex)
        exists := app.activePalette.map.Has(hex)

        if exists
            ApplyHighlight(app, hex)

        g.preview.Opt("c" hex)
        g.preview.Value := 100

        item := GetItemByHex(app, hex)

        text := "HEX: #" hex "`nRGB: " rgb.r "," rgb.g "," rgb.b

        if item {
            text .= "`nROLE: " item.role " " GetRoleIcon(item.role)
            text .= "`n(ALREADY SAVED)"
        }

        item := GetItemByHex(app, hex)

        g.txt.Text := text

        lastHex := hex
    }


    MouseGetPos(&X, &Y)
    g.GetPos(,, &w, &h)

    hoverHistory := false

    if IsObject(app.historyGui) {
        WinGetPos(&hx, &hy, &hw, &hh, app.historyGui.Hwnd)

        if (X >= hx && X <= hx + hw && Y >= hy && Y <= hy + hh)
            hoverHistory := true
    }

    offsetX := 20
    offsetY := 30

    x := X + offsetX
    y := Y + offsetY

    if hoverHistory
        y -= 200

    g.Show("AutoSize NoActivate x" x " y" y)
}
GetItemByHex(app, hex) {
    return app.activePalette.map.Has(hex)
        ? app.activePalette.map[hex]
        : 0
}
; =========================================================
; SAVE COLOR
; =========================================================
SaveColor(app) {
    if !App.CheckActive
        return

    palette := App.activePalette
    hex := GetColorUnderCursor(App)
    rgb := GetRGBFromHex(hex)

     A_Clipboard := GetKeyState("Ctrl") ? rgb : hex

    exists := palette.map.Has(hex)

    clip := GetKeyState("Ctrl")
        ? FormatColor(rgb, "rgb")
        : FormatColor(hex, "hex")

    A_Clipboard := clip.value
    app.lastCopyType := clip.type

    if exists {
        ShowToast(app, "✔ COPIED " (app.lastCopyType = "rgb" ? "RGB: " rgb : "HEX: #" hex ))
        ApplyHighlight(app, hex)
        Emit(app, "history_changed")
        return
    } else {
        ShowToast(app, "➕ SAVED COLOR " (app.lastCopyType = "rgb" ? "RGB: " rgb : "HEX: #" hex ))
    }

    item := CreateItem(hex, rgb)
    item.isSaved := true

    Mutate(app, (p) => AddColor(p, item))
    ApplyHighlight(app, hex)
    Emit(app, "history_changed")
    Commit(app)
}
; =========================================================
; HISTORY CORE
; =========================================================
AddColor(p, item) {
    if p.map.Has(item.hex)
        return

    item.flashUntil := 0

    p.colors.InsertAt(1, item)
    p.map[item.hex] := item

    if (p.colors.Length > p.historyMax)
        p.colors.Pop()
}

Mutate(app, fn) {
    fn(app.activePalette)
    Normalize(app.activePalette)
}

Commit(app) {
    SaveHistory(app)
    DebouncedRefresh(app)
}

Normalize(p) {
    pinned := []
    normal := []

    for item in p.colors
        (item.pinned ? pinned : normal).Push(item)

    p.colors := pinned
    for _, item in normal
        p.colors.Push(item)

    p.map := Map()
    for item in p.colors
        p.map[item.hex] := item
}
NormalizeColorInput(val) {
    type := DetectColorType(val)

    if (type = "hex")
        return { hex: val, rgb: GetRGBFromHex(val), type: "hex" }

    if (type = "rgb") {
        parts := StrSplit(val, ",")
        hex := Format("{:02X}{:02X}{:02X}", parts[1], parts[2], parts[3])
        return { hex: hex, rgb: val, type: "rgb" }
    }

    return 0
}
GetOrCreateCtrl(app, item) {
    if !app.ui.controls.Has(item.hex) {
        CreateCell(app, item)
    }
    return app.ui.controls.Has(item.hex)
        ? app.ui.controls[item.hex]
        : 0
}
; =========================================================
; HISTORY UI
; =========================================================
ToggleHistory(app) {
    app.historyVisible := !app.historyVisible

    if app.historyVisible {
        if !IsObject(app.historyGui)
            InitHistoryGui(app)

        RefreshHistoryUI(app)
        Layout(app)
        app.historyGui.Show()
    } else {
        if IsObject(app.historyGui)
            app.historyGui.Hide()
    }
}
GetHistoryGui(app) {
    if !IsObject(app.historyGui) {
        InitHistoryGui(app)
    }
    return app.historyGui
}

InitHistoryGui(app) {
    if IsObject(app.historyGui)
        app.historyGui.Destroy()

    app.ui.controls := Map()

    g := Gui("+AlwaysOnTop -Caption +ToolWindow")
    g.BackColor := "202020"

    app.historyGui := g
}
RebuildUI(app) {
    g := app.historyGui
    if !IsObject(g)
        return

    ; destroy old controls
    for _, ctrl in app.ui.controls {
        try ctrl.bg.Destroy()
        try ctrl.txt.Destroy()
    }

    app.ui.controls := Map()

    ; rebuild fresh
    for _, item in app.activePalette.colors {
        CreateCell(app, item)
    }

    Layout(app)
}
CreateCell(app, item) {
    g := app.historyGui
    if !IsObject(g)
        return

    if app.ui.controls.Has(item.hex)
        return

    safeHex := RegExReplace(item.hex, "[^0-9A-Fa-f]")
    if (StrLen(safeHex) != 6)
        safeHex := "808080"

    w := app.ui.itemW
    h := app.ui.itemH

    opt := "w" w " h" h " Background" safeHex " Border"

    bg := g.AddText(opt)
    txt := g.AddText("cFFFFFF w180 Center", item.hex)

    bg.hex := item.hex
    txt.hex := item.hex

    bg.OnEvent("Click", (*) => HistoryClick(app, item.hex))
    bg.OnEvent("ContextMenu", (*) => OpenRoleMenu(app, item.hex))

    app.ui.controls[item.hex] := { bg: bg, txt: txt }
    bg.gen := app.ui.generation
    txt.gen := app.ui.generation
}
RefreshHistoryUI(app) {
    if !IsObject(app.historyGui)
        return

    ApplyHighlight(app, app.activePalette.selectedHex)


    toDelete := []

    for hex, ctrl in app.ui.controls {
        if (ctrl.txt.gen != app.ui.generation)
            toDelete.Push(hex)
    }

    for _, hex in toDelete {
        if !app.ui.controls.Has(hex)
            continue

        ctrl := app.ui.controls[hex]

        try ctrl.bg.Destroy()
        try ctrl.txt.Destroy()

        app.ui.controls.Delete(hex)
    }

    now := A_TickCount

    for _, item in app.activePalette.colors {
        ctrl := GetOrCreateCtrl(app, item)
        if !ctrl
            continue

        rgb := HexToRGB(item.hex)

        text := FormatColorInfo(item, "compact")

        if item.pinned
            text := "📌 " text

        ctrl.txt.Value := text

        isSelected := (item.hex = app.activePalette.highlightHex)

        if isSelected {
            ctrl.txt.Opt("BackgroundFFD700 c000000")
        } else {
            ctrl.txt.Opt("Background202020 cFFFFFF")
        }
    }

    Layout(app)
}
HasColor(colors, hex) {
    for item in colors
        if (item.hex = hex)
            return true
    return false
}
ApplyHighlight(app, hex) {
    if (hex = "")
        return

    p := app.activePalette

    if (p.highlightHex = hex)
        return   ; 🔥 prevent redundant emit loop

    p.selectedHex := hex
    p.highlightHex := hex
}
Layout(app) {
    if !IsObject(app.historyGui)
        return

    itemW := app.ui.itemW
    itemH := app.ui.itemH
    gap := app.ui.gap
    cols := app.activePalette.HasOwnProp("maxCols")
        ? app.activePalette.maxCols
        : app.ui.cols

    idx := 0

    for _, item in app.activePalette.colors {

        if !app.ui.controls.Has(item.hex)
            continue

        ctrl := app.ui.controls[item.hex]

        col := Mod(idx, cols)
        row := Floor(idx / cols)

        x := col * (itemW + gap)
        y := row * (itemH + gap)

        ctrl.bg.Move(x, y)
        ctrl.txt.Move(x + 10, y + 2)  
        
        idx++
    }

    cols := app.ui.cols
    maxItems := app.activePalette.historyMax
    app.ui.rows := Ceil(maxItems / cols)

    usedRows := Min(app.ui.rows, Max(1, Floor((idx - 1) / cols) + 1))

    totalW := cols * (itemW + gap)
    totalH := usedRows * (itemH + gap)

    MouseGetPos(&x, &y)
    mon := GetMonitorFromPoint(x, y)
    MonitorGetWorkArea(mon, &L, &T, &R, &B)

    app.historyGui.Show("NA x" L " y" (B - totalH - 10) " w" totalW " h" totalH)
}
; =========================================================
; TOAST
; =========================================================
InitToast(app) {
    if IsObject(app.toast.gui)
        return

    g := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20")
    g.BackColor := "202020"
    g.SetFont("s10", "Consolas")
    g.txt := g.AddText("cFFFFFF w220", "")

    app.toast.gui := g
    app.toastTick := SlideTick.Bind(app)
}
ShowToast(app, text, duration := 2000, speed := 0.8) {
    if !(duration is Number)
        duration := 2000

    if !(speed is Number)
        speed := 0.8

    InitToast(app)
    g := app.toast.gui

    if !IsObject(app.historyGui)
        return

    WinGetPos(&hx, &hy, &hw, &hh, app.historyGui.Hwnd)

    app.toast.x := hx + 10
    app.toast.curY := hy - 50
    app.toast.endY := hy - 85
    app.toast.step := speed
    app.toast.running := true
    app.toast.endTime := A_TickCount + duration

    g.txt.Text := text
    g.Show("x" app.toast.x " y" app.toast.curY " NoActivate")

    if !IsObject(app.toast.gui)
        return StopToast(app)

    if IsObject(app.toastTick)
        SetTimer(app.toastTick, 10)
}
SlideTick(app) {
    if !app.toast.running
        return

    if (A_TickCount >= app.toast.endTime) {
        StopToast(app)
        return
    }

    g := app.toast.gui

    app.toast.curY -= app.toast.step

    if (app.toast.curY <= app.toast.endY) {
        StopToast(app)
        return
    }

    g.Show("x" app.toast.x " y" app.toast.curY " NoActivate")
}
StopToast(app) {
    app.toast.running := false

    if IsObject(app.toastTick)
        SetTimer(app.toastTick, 0)

    if IsObject(app.toast.gui)
        app.toast.gui.Hide()
}
; =========================================================
; INTERACTION
; =========================================================
HistoryClick(app, hex) {
    Mutate(app, (p) => p.selectedHex := hex)
    Commit(app)

    rgb := GetRGBFromHex(hex)

    A_Clipboard := GetKeyState("Ctrl")
        ? rgb
        : hex

    app.lastCopyType := GetKeyState("Ctrl") ? "rgb" : "hex"

    ShowToast(app, "✔ COPIED " (app.lastCopyType = "rgb" ? "RGB: " rgb : "HEX: #" hex ))
    ApplyHighlight(app, hex)
    SetTimer(() => Emit(app, "history_changed"), -900)
}
OpenRoleMenu(app, hex) {
    app.activePalette.selectedHex := hex
    
    ApplyHighlight(app, hex)
    Emit(app, "history_changed")

    if app.historyVisible
        Emit(app, "history_changed")

    if IsObject(app.roleMenuGui) && app.roleMenuGui.Hwnd
        app.roleMenuGui.Hide()

    g := Gui("+AlwaysOnTop -Caption +ToolWindow")
    g.BackColor := "202020"
    g.SetFont("s10", "Consolas")

    g.AddText("cFFFFFF", "Set Role:")

    roles := ["Base","Highlight","Shadow","2 Shadow","Hi Shadow"]

    for role in roles {
        btn := g.AddButton("w160", role)
        btn.OnEvent("Click", RoleClick.Bind(app, role, hex))
    }

    g.AddButton("w160", "Pin/Unpin")
        .OnEvent("Click", (*) => TogglePin(app, hex))

    GetCursorPosForCapture(app, &x, &y)

    g.Show("AutoSize Hide")
    g.GetPos(,, &w, &h)

    xPos := x + 10
    yPos := y - h - 100

    if (yPos < 0)
        yPos := y + 10

    g.Show("x" xPos " y" yPos " NoActivate")

    app.roleMenuGui := g

    SetTimer(() => (
        app.roleMenuGui = g && g.Hwnd ? g.Hide() : ""
    ), -2500)
}
RoleClick(app, role, hex, *) {
    ApplyRole(app, role, hex)
}

ApplyRole(app, role, hex) {
    Mutate(app, (p) => ApplyRoleMutation(p, role, hex))
    Commit(app)
}
ApplyRoleMutation(p, role, hex) {
    for item in p.colors {
        if (item.hex = hex) {
            item.role := role
            break
        }
    }
}
TogglePin(app, hex) {
    Mutate(app, (p) => TogglePinMutation(p, hex))
    Commit(app)
}

TogglePinMutation(p, hex) {
    for item in p.colors {
        if (item.hex = hex) {
            item.pinned := !item.pinned
            break
        }
    }
}
; =========================================================
; PALETTE MANAGER UI
; =========================================================
TogglePaletteManager(app) {
    if IsObject(app.paletteGui) && app.paletteGui.Hwnd {
        ; if visible → hide
        if WinExist("ahk_id " app.paletteGui.Hwnd) {
            app.paletteGui.Hide()
            return
        }
    }

    ; otherwise → open
    OpenPaletteManager(app)
}
SwitchPaletteByIndex(app, idx) {
    if (idx < 1 || idx > app.paletteOrder.Length)
        return

    name := app.paletteOrder[idx]
    SwitchPalette(app, name)

    ShowToast(app, "🎨 Switched to: " name)
}
OpenPaletteManager(app) {
    if IsObject(app.paletteGui) && app.paletteGui.Hwnd {
        app.paletteGui.Show()
        return
    }

    g := Gui("+AlwaysOnTop +Resize", "🎨 Palette Manager v" app.version)
    g.BackColor := "1E1E1E"
    g.SetFont("s10", "Consolas")

    ; =========================
    ; HEADER
    ; =========================
    g.SetFont("s11 bold", "Consolas")
    g.AddText("xm cFFFFFF", "🎨 Nastarva Palette Manager v" app.version)

    g.SetFont("s9 norm", "Consolas")

    ; =========================
    ; LIST
    ; =========================
    g.AddText("xm y+10 cAAAAAA", "📂 Palettes")

    g.list := g.AddListBox("w320 h220 xm y+5")
    g.list.OnEvent("Change", (*) => PaletteSwitchUI(app, g))
    g.list.OnEvent("DoubleClick", (*) => OpenPaletteFile(app, g))

    ; =========================
    ; SETTINGS PANEL
    ; =========================
    g.AddText("xm y+10 cAAAAAA", "⚙️ Settings")

    g.AddText("xm y+5 cFFFFFF", "Max:")
    g.inputMax := g.AddEdit("w60 Number x+5 yp-2")

    g.AddText("x+15 yp+2 cFFFFFF", "Cols:")
    g.inputCols := g.AddEdit("w60 Number x+5 yp-2")

    g.AddButton("x+15 yp w80 h25", "✅ Apply")
        .OnEvent("Click", (*) => ApplyPaletteSettings(app))

    ; =========================
    ; ACTION BUTTONS
    ; =========================
    g.AddText("xm y+15 cAAAAAA", "🛠 Actions")

    g.AddButton("xm w100 h28", "➕ New")
        .OnEvent("Click", (*) => CreatePaletteUI(app, g))

    g.AddButton("x+10 w100 h28", "🗑 Delete")
        .OnEvent("Click", (*) => DeletePaletteUI(app, g))

    g.AddButton("x+10 w100 h28", "📋 Duplicate")
        .OnEvent("Click", (*) => DuplicatePaletteUI(app, g))

    g.AddButton("xm y+5 w100 h28", "✏ Rename")
    .OnEvent("Click", (*) => RenamePaletteUI(app, g))

    g.AddButton("x+10 w100 h28", "⬆ Move Up")
        .OnEvent("Click", (*) => MovePalette(app, g, -1))

    g.AddButton("x+10 w100 h28", "⬇ Move Down")
        .OnEvent("Click", (*) => MovePalette(app, g, 1))

    ; =========================
    ; FOOTER HELP
    ; =========================
    g.AddText("xm y+15 c666666", "💡 Click = Switch palette")
    g.AddText("xm c666666", "💡 Double Click = Open file location")
    g.AddText("xm c666666", "💡 Ctrl + Double Click = Edit file")

    ; =========================
    ; INIT DATA
    ; =========================
    RefreshPaletteList(app, g)

    for i, name in app.paletteOrder {
        if (name = app.activePalette.name) {
            g.list.Value := i
            break
        }
    }

    g.inputMax.Value := app.activePalette.historyMax
    g.inputCols.Value := app.activePalette.maxCols

    g.Show("Center")
    app.paletteGui := g
}
OpenPaletteFile(app, g) {
    sel := g.list.Value
    if !sel
        return

    name := app.paletteOrder[sel]
    p := app.palettes[name]

    if !p
        return

    file := p.file

    if !FileExist(file) {
        MsgBox "File not found:`n" file
        return
    }

    ; --- behavior ---
    if GetKeyState("Ctrl") {
        ; Ctrl + double click → open file
        Run('notepad.exe "' file '"')
    } else {
        ; Double click → open folder + select file
        Run('explorer.exe /select,"' file '"')
    }
}
ApplyPaletteSettings(app) {
    g := app.paletteGui
    if !IsObject(g)
        return

    p := app.activePalette

    ; --- history max ---
    max := Integer(g.inputMax.Value)
    if (max >= 1) {
        p.historyMax := max

        while (p.colors.Length > max)
            p.colors.Pop()
    }

    ; --- columns ---
    cols := Integer(g.inputCols.Value)
    if (cols >= 1) {
        p.maxCols := cols
        app.ui.cols := cols
    }

    SaveHistory(app)

    app.ui.generation++
    InitHistoryGui(app)
    RebuildUI(app)

    Emit(app, "history_changed")
}
ApplyHistoryMaxUI(app, g) {
    if !IsObject(g) || !g.HasOwnProp("inputMax")
        return

    val := Integer(g.inputMax.Value)
    if (val < 1)
        return

    p := app.activePalette
    p.historyMax := val

    while (p.colors.Length > val)
        p.colors.Pop()

    SaveHistory(app)

    app.ui.generation++
    InitHistoryGui(app)
    RebuildUI(app)

    Emit(app, "history_changed")
}
ApplyColsUI(app, g) {
    val := Integer(g.inputCols.Value)

    if (val < 1)
        return

    p := app.activePalette

    p.maxCols := val        ; save per palette
    app.ui.cols := val      ; apply immediately to UI

    SaveHistory(app)

    app.ui.generation++
    InitHistoryGui(app)
    RebuildUI(app)

    Emit(app, "history_changed")
}
GetActivePaletteName(app) {
    return app.activePalette.name
}
RefreshPaletteList(app, g) {
    g.list.Delete()

    active := app.activePalette.name

    for i, name in app.paletteOrder {
        isActive := (active = name)

        label := (isActive ? "🎯 " : "   ")
               . "[" i "] "
               . name

        g.list.Add([label])

        if isActive
            g.list.Value := i   ; 🔥 force selection sync
    }
}
PaletteSwitchUI(app, g) {
    sel := g.list.Value
    if !sel
        return

    name := app.paletteOrder[sel]
    SwitchPalette(app, name)

    g.inputMax.Value := app.activePalette.historyMax

    RefreshPaletteList(app, g)
}
CreatePaletteUI(app, g) {
    result := InputBox("Enter palette name:", "New Palette")

    if (result.Result != "OK" || result.Value = "")
        return

    name := Trim(result.Value)
    if (name = "")
        return

    if app.palettes.Has(name) {
        MsgBox "Palette already exists!"
        return
    }

    file := A_ScriptDir "\color\" name ".txt"

    app.palettes[name] := CreatePalette(name, file)
    app.paletteOrder.Push(name)

    RefreshPaletteList(app, g)
    SavePaletteList(app)
}
DeletePaletteUI(app, g) {
    name := GetActivePaletteName(app)

    if (name = "Default") {
        MsgBox "Cannot delete Default palette"
        return
    }

    file := app.palettes[name].file
    if FileExist(file)
        FileDelete(file)

    app.palettes.Delete(name)

    for i, n in app.paletteOrder {
        if (n = name) {
            app.paletteOrder.RemoveAt(i)
            break
        }
    }

    ; fallback to first palette
    app.activePalette := app.palettes[app.paletteOrder[1]]

    RefreshPaletteList(app, g)
    SavePaletteList(app)
}
DuplicatePaletteUI(app, g) {
    srcName := GetActivePaletteName(app)

    result := InputBox("Duplicate palette as:", "📋 Duplicate", "", srcName " Copy")
    if (result.Result != "OK" || Trim(result.Value) = "")
        return

    newName := Trim(result.Value)

    if app.palettes.Has(newName) {
        MsgBox "Palette already exists!"
        return
    }

    src := app.palettes[srcName]
    newFile := A_ScriptDir "\color\" newName ".txt"

    p := CreatePalette(newName, newFile)

    for item in src.colors {
        clone := CreateItem(item.hex, item.rgb, item.name, item.role)
        clone.pinned := item.pinned
        clone.isSaved := true

        p.colors.Push(clone)
        p.map[clone.hex] := clone
    }

    p.historyMax := src.historyMax
    p.maxCols := src.maxCols

    app.palettes[newName] := p
    app.paletteOrder.Push(newName)

    SaveHistory(app)
    SavePaletteList(app)

    RefreshPaletteList(app, g)
}
RenamePaletteUI(app, g) {
    oldName := GetActivePaletteName(app)

    result := InputBox("Rename palette:", "✏ Rename", "", oldName)
    if (result.Result != "OK" || Trim(result.Value) = "")
        return

    newName := Trim(result.Value)

    if app.palettes.Has(newName) {
        MsgBox "Palette already exists!"
        return
    }

    oldFile := app.palettes[oldName].file
    newFile := A_ScriptDir "\color\" newName ".txt"

    if FileExist(oldFile)
        FileMove(oldFile, newFile, true)

    p := app.palettes[oldName]
    p.name := newName
    p.file := newFile

    app.palettes.Delete(oldName)
    app.palettes[newName] := p

    ; update order
    for i, name in app.paletteOrder {
        if (name = oldName) {
            app.paletteOrder[i] := newName
            break
        }
    }

    app.activePalette := p

    RefreshPaletteList(app, g)
    SavePaletteList(app)
}
MovePalette(app, g, dir) {
    sel := g.list.Value
    if !sel
        return

    newIndex := sel + dir

    if (newIndex < 1 || newIndex > app.paletteOrder.Length)
        return

    temp := app.paletteOrder[sel]
    app.paletteOrder[sel] := app.paletteOrder[newIndex]
    app.paletteOrder[newIndex] := temp

    RefreshPaletteList(app, g)
    g.list.Value := newIndex
    SavePaletteList(app)
}
; =========================================================
; PALETTES
; =========================================================
InitPalettes(app) {
    base := A_ScriptDir "\color\"
    file := base "palettes.txt"

    if FileExist(file) {
        for name in StrSplit(FileRead(file), "`n", "`r") {
            name := Trim(name)
            if (name = "")
                continue

            app.palettes[name] := CreatePalette(name, base name ".txt")
            app.paletteOrder.Push(name)
        }
    } else {
        defaults := ["Default", "UI", "Shadow"]

        for name in defaults {
            app.palettes[name] := CreatePalette(name, base name ".txt")
            app.paletteOrder.Push(name)
        }

        SavePaletteList(app)
    }
}
SavePaletteList(app) {
    file := A_ScriptDir "\color\palettes.txt"
    DirCreate(A_ScriptDir "\color")

    f := FileOpen(file, "w")
    for name in app.paletteOrder
        f.WriteLine(name)
    f.Close()
}
CreatePalette(name, file) {
    return {
        name: name,
        file: file,
        colors: [],
        map: Map(),
        selectedHex: "",
        highlightHex: "",
        highlightToken: 0,
        historyMax: 30,
        maxCols: 10
    }
}

SwitchPalette(app, name) {
    if !app.palettes.Has(name)
        return

    app.activePalette := app.palettes[name]
    LoadHistory(app)

    InitHistoryGui(app)

    app.ui.generation++
    RebuildUI(app)

    Emit(app, "history_changed")
}
CreateItem(hex, rgb, name := "", role := "Base") {

    if (name = "")
        name := GetColorName(hex)  

    return {
        hex: hex,
        rgb: rgb,
        name: name,
        role: role,
        pinned: false,
        isSaved: false,      
        copiedUntil: 0
    }
}
LoadHistory(app) {
    p := app.activePalette
    app.ui.generation++

    if !FileExist(p.file) {
        SaveHistory(app)
    }

    p.colors := []       
    p.map := Map()
    if !p.HasOwnProp("historyMax") || p.historyMax < 1
        p.historyMax := 30

    if !FileExist(p.file)
        return

    for line in StrSplit(FileRead(p.file), "`n","`r") {
        line := Trim(line)
        if (line = "")
            continue
        ; =========================
        ; META PARSE (SAFE EXIT)
        ; =========================
        if (SubStr(line, 1, 5) = "#META") {
            if RegExMatch(line, "version=([\d\.]+)", &m)
                p.version := m[1]
            if RegExMatch(line, "historyMax=(\d+)", &m1)
                p.historyMax := Integer(m1[1])

            if RegExMatch(line, "maxCols=(\d+)", &m2)
                p.maxCols := Integer(m2[1])

            continue
        }
        ; =========================
        ; NORMAL COLOR PARSE
        ; =========================
        part := StrSplit(line, "|")

        if (part.Length < 4)
            continue

        item := CreateItem(part[1], part[2], part[3], part[4])
        item.pinned := (part.Length >= 5 && part[5] = "1")
        item.isSaved := true
        item.copiedUntil := 0

        p.colors.Push(item)
        p.map[item.hex] := item
    }

    Emit(App, "history_changed")
    RebuildUI(app)
}

SaveHistory(app) {
    p := app.activePalette
    DirCreate(A_ScriptDir "\color")

    f := FileOpen(p.file, "w")
    ; --- save meta first ---
    f.WriteLine("#META|version=" app.version "|historyMax=" p.historyMax "|maxCols=" p.maxCols)

    ; --- save colors ---
    for item in p.colors
        f.WriteLine(item.hex "|" item.rgb "|" item.name "|" item.role "|" item.pinned)
    f.Close()
}

; =========================================================
; UTILITIES
; =========================================================
HexToRGB(hex) {
    return {
        r: Integer("0x" SubStr(hex,1,2)),
        g: Integer("0x" SubStr(hex,3,2)),
        b: Integer("0x" SubStr(hex,5,2))
    }
}

GetRGBFromHex(hex) {
    rgb := HexToRGB(hex)
    return rgb.r "," rgb.g "," rgb.b
}
FormatColor(value, type) {
    return { value: value, type: type }  ; type = "hex" | "rgb"
}
FormatColorInfo(item, mode := "full") {
    rgb := item.rgb

    if (mode = "compact")
        return item.hex " | " rgb " | " item.role " " GetRoleIcon(item.role)

    return (
        "HEX: #" item.hex "`n"
        "RGB: " rgb "`n"
        "ROLE: " item.role
    )
}
GetRoleIcon(role) {
    switch role {
        case "Base":       return "⚫"
        case "Highlight":  return "✨"
        case "Shadow":     return "⬛"
        case "2 Shadow":   return "♻️"
        case "Hi Shadow":  return "💞"
        default: return "•"
    }
}
