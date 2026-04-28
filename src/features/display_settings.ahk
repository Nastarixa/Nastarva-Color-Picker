CreateDisplayPanel(gui, app, leftX, leftW) {
    CreatePanel(x, y, w, h, title) {
        gui.AddText("x" x " y+1 w" w " h" (h-5), "")
        gui.AddText("x" x+6 " y" y-10 " cFFD76A", title)
    }

    yBase := 250
    CreatePanel(leftX, yBase, leftW, 165, "Display")

    y := yBase + 12
    gui.AddText("x" leftX+5 " y" y " cFFFFFF", "Section:")
    maxPerSec := app.activePalette.HasOwnProp("maxPerSection") ? app.activePalette.maxPerSection : 10
    gui.inputMax := gui.AddEdit("x+2 yp-2 w40 Number", maxPerSec)
    gui.AddText("x+10 yp+2 cFFFFFF", "Cols:")
    cols := app.activePalette.HasOwnProp("maxCols") ? app.activePalette.maxCols : 4
    gui.inputCols := gui.AddEdit("x+2 yp-2 w40 Number", cols)
    gui.AddButton("x+10 yp-1 w60 h24", "Apply").OnEvent("Click", (*) => ApplyDisplayBtnClicked(app))

    y += 28
    p := app.activePalette
    guiMode := p.HasOwnProp("guiMode") ? p.guiMode : "undocked"
    guiModeLabel := (guiMode = "docked") ? "Mode: Docked" : "Mode: Undocked"
    gui.btnGuiMode := gui.AddButton("x" leftX+5 " y" y " w" leftW-10 " h22", guiModeLabel)
    gui.btnGuiMode.OnEvent("Click", (*) => ToggleGuiModeClicked(app, gui))

y += 26
    p := app.activePalette
    layout := p.HasOwnProp("layout") ? p.layout : "normal"
    layoutLabel := layout = "grid" ? "Layout: Grid" : (layout = "vertical" ? "Layout: V-Strip" : "Layout: Normal")
    gui.btnLayout := gui.AddButton("x" leftX+5 " y" y " w" leftW/2-7 " h22", layoutLabel)
    gui.btnLayout.OnEvent("Click", (*) => ToggleLayoutClicked(app, gui))
    compactMode := app.HasOwnProp("compactMode") ? app.compactMode : false
    fullCompactMode := app.HasOwnProp("fullCompactMode") ? app.fullCompactMode : false
    compactLabel := fullCompactMode ? "Display: Full" : (compactMode ? "Display: Compact" : "Display: Normal")
    gui.btnCompact := gui.AddButton("x+5 w" leftW/2-7 " h22", compactLabel)
    gui.btnCompact.OnEvent("Click", (*) => ToggleCompactClicked(app, gui))

    y += 26
    headerCompactMode := app.HasOwnProp("headerCompactMode") ? app.headerCompactMode : false
    headerLabel := headerCompactMode ? "Header: Compact" : "Header: Normal"
    gui.btnHeaderCompact := gui.AddButton("x" leftX+5 " y" y " w" leftW-10 " h22", headerLabel)
    gui.btnHeaderCompact.OnEvent("Click", (*) => ToggleHeaderClicked(app, gui))
}

ApplyDisplayBtnClicked(app) {
    g := app.paletteGui
    if !IsObject(g)
        return
    p := app.activePalette
    
    if g.HasOwnProp("inputMax") && g.inputMax.Value != "" {
        maxPerSecVal := Integer(g.inputMax.Value)
    } else {
        maxPerSecVal := p.historyMax
    }
    
    if g.HasOwnProp("inputCols") && g.inputCols.Value != "" {
        maxColsVal := Integer(g.inputCols.Value)
    } else {
        maxColsVal := p.maxCols
    }
    
    if (maxPerSecVal >= 1) {
        p.historyMax := maxPerSecVal
        p.maxPerSection := maxPerSecVal
    }
    if (maxColsVal >= 1) {
        p.maxCols := maxColsVal
        app.ui.cols := maxColsVal
    }
    
    SaveHistory(app)
    app.ui.generation++
    RebuildUI(app)
    ShowToast(app, "Display: " maxPerSecVal " max, " maxColsVal " cols")
}

ToggleGuiModeClicked(app, gui) {
    p := app.activePalette
    current := p.HasOwnProp("guiMode") ? p.guiMode : "undocked"
    newMode := (current = "docked") ? "undocked" : "docked"
    p.guiMode := newMode
    SavePalette(p, app.version)
    if gui.HasOwnProp("btnGuiMode")
        gui.btnGuiMode.Text := (newMode = "docked") ? "Mode: Docked" : "Mode: Undocked"
    wasDocked := IsPaletteDocked(p)
    p.guiMode := newMode
    isNowDocked := IsPaletteDocked(p)
    if !wasDocked && isNowDocked {
        SaveSectionPanelPositions(app)
    }
    SaveHistory(app)
    app.ui.generation++
    InitHistoryGui(app)
    RebuildUI(app)
    Emit(app, "history_changed")
    ShowToast(app, "GUI Mode: " (newMode = "docked" ? "Docked" : "Undocked"))
}

ToggleLayoutClicked(app, gui) {
    p := app.activePalette
    current := p.HasOwnProp("layout") ? p.layout : "normal"
    if current = "normal" {
        p.layout := "grid"
    } else if current = "grid" {
        p.layout := "vertical"
    } else {
        p.layout := "normal"
    }
    if gui.HasOwnProp("btnLayout") {
        label := p.layout = "grid" ? "Layout: Grid" : (p.layout = "vertical" ? "Layout: V-Strip" : "Layout: Normal")
        gui.btnLayout.Text := label
    }
    SavePalette(p, app.version)
    app.ui.generation++
    RebuildUI(app)
}

ToggleCompactClicked(app, gui) {
    compactMode := app.HasOwnProp("compactMode") ? app.compactMode : false
    fullCompactMode := app.HasOwnProp("fullCompactMode") ? app.fullCompactMode : false
    if !compactMode && !fullCompactMode {
        app.compactMode := true
        app.fullCompactMode := false
    } else if compactMode && !fullCompactMode {
        app.compactMode := false
        app.fullCompactMode := true
    } else {
        app.fullCompactMode := false
        app.compactMode := false
    }
    if gui.HasOwnProp("btnCompact") {
        label := app.fullCompactMode ? "Display: Full" : (app.compactMode ? "Display: Compact" : "Display: Normal")
        gui.btnCompact.Text := label
    }
    app.ui.generation++
    RebuildUI(app)
    ShowToast(app, "Display: " (app.fullCompactMode ? "Full" : (app.compactMode ? "Compact" : "Normal")))
}

ToggleHeaderClicked(app, gui) {
    current := app.HasOwnProp("headerCompactMode") ? app.headerCompactMode : false
    app.headerCompactMode := !current
    if gui.HasOwnProp("btnHeaderCompact")
        gui.btnHeaderCompact.Text := app.headerCompactMode ? "Header: Compact" : "Header: Normal"
    app.ui.generation++
    RebuildUI(app)
    ShowToast(app, "Header: " (app.headerCompactMode ? "Compact" : "Normal"))
}

ToggleRoleOrderClicked(app, gui) {
    p := app.activePalette
    if p.HasOwnProp("roleOrder") && p.roleOrder.Length > 0 {
        p.DeleteProp("roleOrder")
    } else {
        p.roleOrder := DefaultRoleOrder()
    }
    if gui.HasOwnProp("btnRoleOrder") {
        label := p.HasOwnProp("roleOrder") && p.roleOrder.Length > 0 ? "Role Order: Custom" : "Role Order: Default"
        gui.btnRoleOrder.Text := label
    }
    if gui.HasOwnProp("roleOrderEdit") {
        if p.HasOwnProp("roleOrder") && p.roleOrder.Length > 0 {
            gui.roleOrderEdit.Opt("-Disabled")
            gui.roleOrderEdit.Value := JoinRoleOrder(p.roleOrder)
        } else {
            gui.roleOrderEdit.Opt("+Disabled")
            gui.roleOrderEdit.Value := ""
        }
    }
    SavePalette(p, app.version)
    RebuildUI(app)
}

ApplyRoleOrderEdit(app, gui) {
    p := app.activePalette
    text := gui.roleOrderEdit.Value
    roles := StrSplit(text, ",")
    parsed := []
    for _, r in roles {
        r := Trim(r)
        if r != ""
            parsed.Push(r)
    }
    if parsed.Length > 0 {
        p.roleOrder := parsed
    } else {
        if p.HasOwnProp("roleOrder")
            p.DeleteProp("roleOrder")
    }
    if gui.HasOwnProp("btnRoleOrder") {
        label := p.HasOwnProp("roleOrder") && p.roleOrder.Length > 0 ? "Role Order: Custom" : "Role Order: Default"
        gui.btnRoleOrder.Text := label
    }
    SavePalette(p, app.version)
    RebuildUI(app)
}
