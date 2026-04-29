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
    return ((bgr & 0xFF) << 16) | (bgr & 0x00FF00) | ((bgr >> 16) & 0xFF)
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
    GetCursorPosForCapture(app, &x, &y)
    color := GetColorAtPhysical(x, y)
    LeaveDpiCaptureContext(old)
    if (color = -1)
        return "000000"
    return Format("{:06X}", color)
}

CreatePickGui(app) {
    app.pickGui := Gui("+AlwaysOnTop -Caption +ToolWindow")
    app.pickGui.BackColor := "323338"
    app.pickGui.SetFont("s9", "Consolas")
    app.pickGui.MarginX := 8
    app.pickGui.MarginY := 6

    app.pickGui.preview := app.pickGui.AddProgress("xm y+4 w40 h40")
    app.pickGui.hexText := app.pickGui.AddText("xp+50 yp+2 w140 h18 cFFFFFF", "#FFFFFF")
    app.pickGui.rgbText := app.pickGui.AddText("xp yp+18 w140 h18 cAAAAAA", "RGB: 255,255,255")

    app.pickGuiRole := Gui("+AlwaysOnTop -Caption +ToolWindow")
    app.pickGuiRole.BackColor := "323338"
    app.pickGuiRole.SetFont("s9", "Consolas")
    app.pickGuiRole.MarginX := 0
    app.pickGuiRole.MarginY := 0

    app.pickGuiRole.roleControls := []

    app.rolePadding := 6
    app.roleGapX := 6
    app.roleGapY := 4
    app.roleColWidth := 90
    app.roleRowHeight := 18

    containerX := 3
    containerY := 5
    containerW := 200
    containerH := 100

    app.pickGuiRole.container := app.pickGuiRole.AddText(
        "x" containerX " y" containerY " w" containerW " h" containerH " Background38383D Border"
    )

    startX := containerX + app.rolePadding
    startY := containerY + app.rolePadding

    Loop 6 {
        i := A_Index

        col := Mod(i-1, 2)
        row := Floor((i-1) / 2)

        x := startX + col * (app.roleColWidth + app.roleGapX)
        y := startY + row * (app.roleRowHeight + app.roleGapY)

        ctrl := app.pickGuiRole.AddText(
            "x" x " y" y " w" app.roleColWidth " h" app.roleRowHeight " cAAAAAA BackgroundTrans"
        )

        app.pickGuiRole.roleControls.Push(ctrl)
    }
}

TogglePicker(app) {
    if !IsObject(app.pickerTickFn) {
        app.pickerTickFn := PickerTick.Bind(app)
    }

    app.CheckActive := !app.CheckActive

    if app.CheckActive {
        app.lastPickHex := ""
        app.lastMouseX := 0
        app.lastMouseY := 0
        app.pickGuiRoleVisible := false

        if !app.pickGui {
            CreatePickGui(app)
        }

        for ctrl in app.pickGuiRole.roleControls {
            ctrl.Value := ""
        }

        MovePickGui(app)
        SetTimer(app.pickerTickFn, 10)

        app.pickGui.Show("AutoSize NoActivate")
    } else {
        SetTimer(app.pickerTickFn, 0)

        if app.pickGui
            app.pickGui.Hide()

        if app.pickGuiRole
            app.pickGuiRole.Hide()
    }
}

PickerTick(app) {
    if !app.CheckActive
        return

    hex := GetColorUnderCursor(app)

    if (hex != app.lastPickHex) {
        app.lastPickHex := hex
        UpdatePickGui(app, hex)
    }

    MouseGetPos(&mx, &my)
    if (mx != app.lastMouseX || my != app.lastMouseY) {
        app.lastMouseX := mx
        app.lastMouseY := my
        MovePickGui(app)
    }
}

UpdatePickGui(app, hex) {
    g := app.pickGui
    gr := app.pickGuiRole

    g.preview.Opt("c" hex)
    g.preview.Value := 100

    rgb := HexToRGB(hex)

    g.hexText.Value := "#" hex
    g.rgbText.Value := "RGB: " rgb.r "," rgb.g "," rgb.b

    items := []

    for c in app.activePalette.colors {
        if c.hex = hex
            items.Push(c)
    }

    ; reset
    for ctrl in gr.roleControls {
        ctrl.Value := ""
        ctrl.Opt("+Hidden")
    }

    if (items.Length = 0) {
        gr.Hide()
        app.pickGuiRoleVisible := false
        return
    }

    ; fill
    for i, item in items {
        if i > 6
            break

        ctrl := gr.roleControls[i]
        ctrl.Value := GetRoleIcon(item.role) "  " item.section
        ctrl.Opt("-Hidden")
    }

    ; ===== SIZE CALC =====
    visibleRows := Ceil(items.Length / 2)

    padding := app.rolePadding
    gapY := app.roleGapY
    rowH := app.roleRowHeight

    containerH := padding*2 + (visibleRows * rowH) + ((visibleRows-1) * gapY)

    gr.container.Move(,, , containerH)

    ; match width with main GUI
    g.GetPos(,, &mainW, &mainH)

    gr.Show("w" mainW " h" containerH+10 " NoActivate")

    app.pickGuiRoleVisible := true
}

MovePickGui(app) {

    if !app.pickGui
        return

    MouseGetPos(&X, &Y)

    app.pickGui.GetPos(,, &w1, &h1)
    w2 := 0, h2 := 0
    if app.pickGuiRoleVisible
        app.pickGuiRole.GetPos(,, &w2, &h2)

    offsetX := 20
    offsetY := 25

    mon := GetMonitorFromPoint(X, Y)
    MonitorGetWorkArea(mon, &L, &T, &R, &B)

    totalW := w1
    totalH := h1 + (app.pickGuiRoleVisible ? (h2 + 6) : 0)

    x := X + offsetX
    y := Y + offsetY

    ; RIGHT SAFE
    if (x + totalW > R) {
        x := X - totalW - offsetX
        if (x < L)
            x := L + 5
    }

    ; BOTTOM SAFE
    if (y + totalH > B) {
        y := Y - totalH - offsetY
        if (y < T)
            y := T + 5
    }

    roleX := x + (w1 - w2) // 2
    app.pickGui.Show("NoActivate x" x " y" y)

    if (app.pickGuiRoleVisible)
        app.pickGuiRole.Show("NoActivate x" roleX " y" y + h1 + 6)
}

SaveColor(app) {
    if !App.CheckActive
        return

    palette := App.activePalette
    hex := GetColorUnderCursor(App)
    rgb := GetRGBFromHex(hex)
    section := GetSelectedSectionName(palette)

    if section = ""
        section := "Default"

    existsInSection := false
    for c in palette.colors {
        if c.hex = hex && c.section = section {
            existsInSection := true
            break
        }
    }

    if existsInSection {
        ShowToast(app, "Already in " section)
        return
    }

    item := CreateItem(hex, rgb, GetColorName(hex), "Base")
    item.section := section
    item.pinned := 0

    AddColor(palette, item)

    if !HasSectionName(palette, section)
        AddSectionName(palette, section)

    Normalize(palette)
    SaveHistory(app)

    ApplyHighlight(app, hex)
    RefreshSectionCells(app, section)

    ShowToast(app, "Saved #" hex " to " section)
}
