GetCursorPosForCapture(app, &x, &y) {
    pt := Buffer(8, 0)

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

TogglePicker(app) {
    if !IsObject(app.pickerTickFn)
        app.pickerTickFn := PickerTick.Bind(app)

    app.CheckActive := !app.CheckActive

    if app.CheckActive {
        SetTimer(app.pickerTickFn, 10)
    } else {
        SetTimer(app.pickerTickFn, 0)

        if app.pickGui
            app.pickGui.Hide()
    }
}

PickerTick(app) {
    if !app.CheckActive
        return

    g := app.pickGui

    hex := GetColorUnderCursor(app)

    if (hex = app.lastHex)
        app.stableCount++
    else {
        app.lastHex := hex
        app.stableCount := 0
    }

    if (app.stableCount < 2)
        return

    if !IsObject(g) {
        g := Gui("+AlwaysOnTop -Caption +ToolWindow")
        g.BackColor := "202020"
        g.SetFont("s10", "Consolas")

        g.preview := g.AddProgress("x8 w40 h60")
        g.txt := g.AddText("x+8 yp w160 h65 cFFFFFF")

        app.pickGui := g
    }

    hex := GetColorUnderCursor(app)
    static lastHex := ""
    static lastTargetSection := ""
    targetSection := GetSelectedSectionName(app.activePalette)

    if (hex != lastHex || targetSection != lastTargetSection) {
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

        g.txt.Text := text
        lastHex := hex
        lastTargetSection := targetSection
    }

    MouseGetPos(&X, &Y)
    g.GetPos(,, &w, &h)

    hoverHistory := GetHoveredHistoryPanelRect(app, X, Y, &hx, &hy, &hw, &hh)

    offsetX := 23
    offsetY := 30

    x := X + offsetX
    y := Y + offsetY

    if hoverHistory {
        margin := 10
        y := hy - h - margin

        mon := GetMonitorFromPoint(X, Y)
        MonitorGetWorkArea(mon, &L, &T, &R, &B)

        if (y < T)
            y := hy + hh + margin
    }

    g.Show("AutoSize NoActivate x" x " y" y)
}

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

    targetSection := GetSelectedSectionName(palette)
    item := CreateItem(hex, rgb)
    item.isSaved := true
    item.section := targetSection

    Mutate(app, (p) => (
        AddSectionName(p, targetSection),
        AddColor(p, item)
    ))
    ApplyHighlight(app, hex)
    if app.historyVisible {
        Emit(app, "history_changed")
        DebouncedRefresh(app)
    }
    SaveHistory(app)
}
