TogglePaletteManager(app) {
    paletteHwnd := SafeGetGuiHwnd(app.paletteGui)
    if paletteHwnd {
        if WinExist("ahk_id " paletteHwnd) {
            app.paletteGui.Hide()
            return
        }
    }

    OpenPaletteManager(app)
}

SwitchPaletteByIndex(app, idx) {
    if (idx < 1 || idx > app.paletteOrder.Length)
        return

    name := app.paletteOrder[idx]

    if app.activePalette && !IsPaletteDocked(app.activePalette) && app.historyVisible {
        SaveSectionPanelPositions(app)
        SavePalette(app.activePalette, app.version)
        SaveHistory(app)
        ShowToast(app, "💾 Positions saved before switch")
    }

    SwitchPalette(app, name)

    ShowToast(app, "🎨 Switched to: " name)
}

OpenPaletteManager(app) {
    if SafeGetGuiHwnd(app.paletteGui) {
        app.paletteGui.Show()
        return
    }

    g := Gui("+AlwaysOnTop +Resize +OwnDialogs", "Nastarxa Palette Manager v" app.version)
    g.BackColor := "323338"
    g.SetFont("s9", "Consolas")

    ; ===== HEADER BUTTONS =====
    g.AddButton("x10 y10 w120 h24", "🎯 Color Picker").OnEvent("Click", (*) => TogglePicker(app))
    g.AddButton("x+5 y10 w120 h24", "🎨 Color Palette").OnEvent("Click", (*) => TogglePalette(app))
    g.AddButton("x+5 y10 w120 h24", "🔄 Refresh").OnEvent("Click", (*) => RefreshPaletteManager(app, g))
    displayLabel := app.displayMode = "hex" ? "HEX" : "RGB"
    g.AddButton("x+5 y10 w60 h24", "📋 " displayLabel).OnEvent("Click", (*) => ToggleDisplayMode(app, g))
    g.AddButton("x+5 y10 w30 h24", "❓").OnEvent("Click", (*) => ShowHotkeyHelp(app))

    ; ===== LAYOUT CONSTANTS =====
    margin := 10
    gap := 10

    leftX := margin
    leftW := 280

    centerX := leftX + leftW + gap
    centerW := 260

    fullW := centerX + centerW - margin

    ; ===== HELPER =====
    CreatePanel(x, y, w, h, title) {
        g.AddText("x" x " y+1 w" w " h" (h-5), "")
        g.AddText("x" x+6 " y" y-10 " cFFD76A", title)
    }

    ; ===== LEFT: PALETTE LIST =====
    yBase := 55
    CreatePanel(leftX, yBase, leftW, 300, "📂 Palettes")

    y := yBase + 12
    g.list := g.AddListView("x" leftX+5 " y" y " w" leftW-10 " h130 -Sort -Multi", ["Palette"])
    g.list.SetFont("s8", "Consolas")
    g.list.OnEvent("Click", (ctrl, item) => PaletteSwitchUI(app, g))
    g.list.OnEvent("ColClick", (*) => "")

    y += 135
    g.AddButton("x" leftX+5 " y" y " w" leftW/2-7 " h22", "▲ Up")
        .OnEvent("Click", (*) => MovePalette(app, g, -1))
    g.AddButton("x+5 yp w" leftW/2-7 " h22", "▼ Down")
        .OnEvent("Click", (*) => MovePalette(app, g, 1))

    ; ===== CENTER: INFO + NOTE =====
    yBase := 55
    CreatePanel(centerX, yBase, centerW, 300, "📝 Note")

    y := yBase + 12
    g.noteEdit := g.AddEdit("x" centerX+5 " y" y " w" centerW-10 " h63", GetPaletteNote(app.activePalette))
    y += 68
    g.AddButton("x" centerX+5 " y" y " w80 h22", "💾 Save").OnEvent("Click", (*) => SavePaletteNoteInline(app, g))
    x := centerX + 90
    g.AddButton("x" x " y" y " w80 h22", "🧹 Clear").OnEvent("Click", (*) => ClearPaletteNote(app, g))

    y += 37
    g.infoTable := CreatePaletteInfoTable(g, centerX+5, y-5, centerW-10, app.activePalette, 2)

    ; ===== BOTTOM LEFT: DISPLAY =====
    CreatePickerPanel(g, app, leftX, leftW)


    CreateDisplayPanel(g, app, leftX, leftW)
    
    ; ===== BOTTOM CENTER: ACTIONS =====
    CreateActionsPanel(g, app, centerX, centerW)

    ; ===== POPULATE =====
    RefreshPaletteList(app, g)

    for i, name in app.paletteOrder {
        if (name = app.activePalette.name) {
            g.list.Modify(i, "Select")
            break
        }
    }

    if g.HasOwnProp("inputMax") && g.HasOwnProp("inputCols") {
        g.inputMax.Value := app.activePalette.historyMax
        g.inputCols.Value := app.activePalette.maxCols
    }
    selectedPalette := app.activePalette
    UpdatePaletteInfoTable(g, selectedPalette)
    g.noteEdit.Value := GetPaletteNote(app.activePalette)

    g.Show("w" (fullW + 20) " h450 Center")
    app.paletteGui := g
}
OpenPaletteFile(app, g) {
    sel := g.list.GetNext()
    if !sel
        return

    name := app.paletteOrder[sel]
    p := app.palettes[name]

    if !p
        return

    palettePath := p.file

    if !FileExist(palettePath) {
        ShowToast(app, "File not found: " palettePath)
        return
    }

    if GetKeyState("Ctrl") {
        Run('notepad.exe "' palettePath '"')
    } else {
        Run('explorer.exe /select,"' palettePath '"')
    }
}

ApplyDisplaySettings(app) {
    g := app.paletteGui
    if !IsObject(g)
        return

    p := app.activePalette

    maxHistory := Integer(g.inputMax.Value)
    if (maxHistory >= 1) {
        p.historyMax := maxHistory
        Normalize(p)
    }

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
    ShowToast(app, "✅ Display settings applied")
}

ApplyRoleOrderSettings(app) {
    SaveHistory(app)
    ShowToast(app, "✅ Role order applied")
}

ToggleGuiMode(app) {
    p := app.activePalette
    currentMode := p.HasOwnProp("guiMode") ? p.guiMode : "undocked"
    newMode := (currentMode = "undocked") ? "docked" : "undocked"

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

    g := app.paletteGui
    if IsObject(g) && g.HasOwnProp("btnGuiMode")
        g.btnGuiMode.Text := GetGuiModeLabel(app)

    ShowToast(app, newMode = "docked" ? "✅ Docked" : "✅ Undocked")
}

ToggleLayout(app) {
    p := app.activePalette
    current := p.HasOwnProp("layout") ? p.layout : "normal"

    switch current {
        case "normal": p.layout := "grid"
        case "grid": p.layout := "vertical"
        case "vertical": p.layout := "character"
        default: p.layout := "normal"
    }

    SaveHistory(app)
    app.ui.generation++
    InitHistoryGui(app)
    RebuildUI(app)
    Emit(app, "history_changed")

    g := app.paletteGui
    if IsObject(g) && g.HasOwnProp("btnLayout")
        g.btnLayout.Text := GetLayoutLabel(app)

    ShowToast(app, "✅ Layout: " GetPaletteLayoutLabel(p))
}

GetGuiModeLabel(app) {
    p := app.activePalette
    mode := p.HasOwnProp("guiMode") ? p.guiMode : "undocked"
    return mode = "docked" ? "🪟 GUI: Docked" : "🖥 GUI: Undocked"
}

GetLayoutLabel(app) {
    p := app.activePalette
    layout := p.HasOwnProp("layout") ? p.layout : "normal"
    switch layout {
        case "grid": return "Layout: Grid"
        case "vertical": return "Layout: Vertical"
        default: return "Layout: Normal"
    }
}

GetPaletteInfoMap(p) {
    if !p
        return Map()

    return Map(
        "Colors", p.HasOwnProp("colors") ? p.colors.Length : 0,
        "Sections", p.HasOwnProp("sections") ? p.sections.Length : 0,
        "Max Cols", p.HasOwnProp("maxCols") ? p.maxCols : 10,
        "Max Color", p.HasOwnProp("historyMax") ? p.historyMax : 20,
        "Mode", p.HasOwnProp("guiMode") ? p.guiMode : "docked",
        "Layout", p.HasOwnProp("layout") ? p.layout : "normal"
    )
}
GetPaletteInfoOrder() {
    return ["Colors", "Max Color", "Sections", "Max Cols", "Mode", "Layout"]
}
CreatePaletteInfoTable(g, x, y, w, p, opts := 0) {
    ; ===== Defaults =====
    cols   := 2
    rowH   := 18
    gapX   := 6     ; label ↔ value
    gapY   := 2      ; row gap
    colGap := 15     ; ✅ column gap (NEW)
    labelW := 60
    padL   := 0
    padR   := 0

    if IsObject(opts) {
        cols   := opts.Has("cols")   ? opts["cols"]   : cols
        rowH   := opts.Has("rowH")   ? opts["rowH"]   : rowH
        gapX   := opts.Has("gapX")   ? opts["gapX"]   : gapX
        gapY   := opts.Has("gapY")   ? opts["gapY"]   : gapY
        colGap := opts.Has("colGap") ? opts["colGap"] : colGap
        labelW := opts.Has("labelW") ? opts["labelW"] : labelW
        padL   := opts.Has("padL")   ? opts["padL"]   : padL
        padR   := opts.Has("padR")   ? opts["padR"]   : padR
    }

    data := GetPaletteInfoMap(p)
    controls := []

    total := data.Count

    ; ✅ subtract total column gaps first
    usableW := w - padL - padR - ((cols - 1) * colGap)
    colW := Floor(usableW / cols)

    valueW := colW - labelW - gapX

    i := 0
    data := GetPaletteInfoMap(p)
    order := GetPaletteInfoOrder()

    for key in order {
    val := data.Has(key) ? data[key] : ""
        col := Mod(i, cols)
        row := Floor(i / cols)

        ; ✅ include colGap in positioning
        xx := x + padL + (col * (colW + colGap))
        yy := y + (row * (rowH + gapY))

        lbl := g.AddText("x" xx " y" yy " w" labelW " h" rowH " cAAAAAA", key)
        txt := g.AddText("x" xx + labelW + gapX " y" yy " w" valueW " h" rowH " cFFFFFF", val)

        controls.Push({label: lbl, value: txt, key: key})
        i++
    }

    return controls
}
UpdatePaletteInfoTable(g, p) {
    if !g.HasOwnProp("infoTable")
        return

    data := GetPaletteInfoMap(p)

    for item in g.infoTable {
        val := data.Has(item.key) ? data[item.key] : ""
        item.value.Value := val
    }
}
ToggleCompactMode(app, g) {
    if !app.compactMode && !app.fullCompactMode {
        app.compactMode := true
        app.fullCompactMode := false
        label := "Compact"
    } else if app.compactMode && !app.fullCompactMode {
        app.compactMode := false
        app.fullCompactMode := true
        label := "Squares"
    } else {
        app.compactMode := false
        app.fullCompactMode := false
        label := "Normal"
    }

    if g.HasOwnProp("btnCompact")
        g.btnCompact.Text := GetCompactModeLabel(app)

    if app.historyVisible {
        app.ui.generation++
        RebuildUI(app)
        Emit(app, "history_changed")
    }

    ShowToast(app, "Display mode: " label)
}

GetCompactModeLabel(app) {
    if app.fullCompactMode
        return "🔲 Display: Squares"
    else if app.compactMode
        return "🔳 Display: Compact"
    else
        return "◾ Display: Normal"
}

ToggleHeaderCompactMode(app, g) {
    app.headerCompactMode := !app.headerCompactMode

    if g.HasOwnProp("btnHeaderCompact")
        g.btnHeaderCompact.Text := app.headerCompactMode ? "🧊 Header: Compact" : "📄 Header: Normal"

    if app.historyVisible {
        app.ui.generation++
        RebuildUI(app)
        Emit(app, "history_changed")
    }

    ShowToast(app, "Header: " (app.headerCompactMode ? "Compact" : "Normal"))
}

GetPaletteLayoutLabel(p) {
    layout := p.HasOwnProp("layout") ? p.layout : "normal"
    switch StrLower(layout) {
        case "grid": return "Grid"
        case "vertical": return "Vertical"
        default: return "Normal"
    }
}

GetPaletteLayoutIndex(p) {
    layout := p.HasOwnProp("layout") ? p.layout : "normal"
    switch StrLower(layout) {
        case "grid": return 2
        case "vertical": return 3
        default: return 1
    }
}

ParsePaletteLayout(text) {
    text := StrLower(Trim(text))
    switch text {
        case "grid": return "grid"
        case "vertical": return "vertical"
        default: return "normal"
    }
}

ApplyPaletteSettings(app) {
    ApplyDisplaySettings(app)
}

ApplyHistoryMaxUI(app, g) {
    if !IsObject(g) || !g.HasOwnProp("inputMax")
        return

    val := Integer(g.inputMax.Value)
    if (val < 1)
        return

    p := app.activePalette
    p.historyMax := val
    Normalize(p)

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

    p.maxCols := val
    app.ui.cols := val

    SaveHistory(app)

    app.ui.generation++
    InitHistoryGui(app)
    RebuildUI(app)

    Emit(app, "history_changed")
}

GetActivePaletteName(app) {
    return app.activePalette.name
}

GetPaletteGuiModeLabel(p) {
    mode := p.HasOwnProp("guiMode") ? StrLower(p.guiMode) : "undocked"
    return (mode = "docked") ? "🪟 GUI: Docked" : "🖥 GUI: Undocked"
}

ParsePaletteGuiMode(text) {
    text := StrLower(Trim(text))
    return (text = "docked") ? "docked" : "undocked"
}

ParseRoleOrder(text) {
    roles := []
    seen := Map()

    for _, role in StrSplit(text, ",") {
        role := NormalizeRoleName(role)
        if (role = "" || seen.Has(role))
            continue

        roles.Push(role)
        seen[role] := true
    }

    return roles
}

RefreshPaletteList(app, g) {
    g.list.Delete()

    active := app.activePalette.name

    sortedByPriority := []
    for name, p in app.palettes {
        sortedByPriority.Push(name)
    }

    Loop sortedByPriority.Length {
        swapped := false
        Loop sortedByPriority.Length - A_Index {
            i := A_Index
            j := i + 1
            p1 := app.palettes[sortedByPriority[i]]
            p2 := app.palettes[sortedByPriority[j]]
            pri1 := p1.HasOwnProp("priority") ? p1.priority : 999
            pri2 := p2.HasOwnProp("priority") ? p2.priority : 999
            if pri1 > pri2 {
                temp := sortedByPriority[i]
                sortedByPriority[i] := sortedByPriority[j]
                sortedByPriority[j] := temp
                swapped := true
            }
        }
        if !swapped
            break
    }

    app.paletteOrder := sortedByPriority.Clone()

    for i, name in sortedByPriority {
        isActive := (active = name)
        p := app.palettes[name]
        priority := p && p.HasOwnProp("priority") ? p.priority : 1

displayName := (isActive ? "🎯 " : "   ") name

        g.list.Add("", displayName)

        if isActive
            g.list.Modify(i, "Select")
    }
}

PaletteSwitchUI(app, g) {
    if app.HasOwnProp("paletteUIBusy") && app.paletteUIBusy
        return

    sel := g.list.GetNext()
    if !sel
        return

    name := app.paletteOrder[sel]

    selectedPalette := app.palettes[name]

    if app.activePalette && !IsPaletteDocked(app.activePalette) && app.historyVisible {
        SaveSectionPanelPositions(app)
        SaveHistory(app)
    }

    SwitchPalette(app, name)

    g.inputMax.Value := app.activePalette.historyMax
    g.inputCols.Value := app.activePalette.maxCols
    if g.HasOwnProp("btnGuiMode")
        g.btnGuiMode.Text := GetGuiModeLabel(app)
    if g.HasOwnProp("btnLayout")
        g.btnLayout.Text := GetLayoutLabel(app)
    if g.HasOwnProp("noteEdit")
        g.noteEdit.Value := GetPaletteNote(selectedPalette)
    if g.HasOwnProp("infoTable")
        UpdatePaletteInfoTable(g, selectedPalette)


    RefreshPaletteList(app, g)
}

CreatePaletteUI(app, g) {
    ShowInputDialog(app, "Enter palette name:", "➕ New Palette", (name) => CreatePaletteConfirm(app, g, name))
}

CreatePaletteConfirm(app, g, name) {
    name := Trim(name)
    if (name = "")
        return

    if app.palettes.Has(name) {
        ShowToast(app, "Palette already exists!")
        return
    }

    file := A_ScriptDir "\color\" name ".txt"

    app.palettes[name] := CreatePalette(name, file)
    app.paletteOrder.Push(name)

    RefreshPaletteList(app, g)
    SavePaletteList(app)
    ShowToast(app, "✅ Created palette: " name)
}

DeletePaletteUI(app, g) {
    name := GetActivePaletteName(app)

    if (name = "Default") {
        ShowToast(app, "Cannot delete Default palette")
        return
    }

    ShowConfirmDialog(app, "🗑 Delete palette '" name "'?`nThis cannot be undone.", "Delete Palette", () => DeletePaletteConfirm(app, g, name))
}

DeletePaletteConfirm(app, g, name) {
    palettePath := app.palettes[name].file
    if FileExist(palettePath)
        FileDelete(palettePath)

    app.palettes.Delete(name)

    for i, n in app.paletteOrder {
        if (n = name) {
            app.paletteOrder.RemoveAt(i)
            break
        }
    }

    app.activePalette := app.palettes[app.paletteOrder[1]]
    app.ui.cols := app.activePalette.maxCols

    LoadHistory(app)
    
    app.pickGuiOffsetX := app.activePalette.HasOwnProp("pickGuiOffsetX") ? app.activePalette.pickGuiOffsetX : -325
    app.pickGuiOffsetY := app.activePalette.HasOwnProp("pickGuiOffsetY") ? app.activePalette.pickGuiOffsetY : 90
    
    InitHistoryGui(app)
    app.ui.generation++
    RebuildUI(app)
    RefreshPaletteList(app, g)
    g.inputMax.Value := app.activePalette.historyMax
    g.inputCols.Value := app.activePalette.maxCols
    if g.HasOwnProp("btnGuiMode")
        g.btnGuiMode.Text := GetGuiModeLabel(app)
    if g.HasOwnProp("btnLayout")
        g.btnLayout.Text := GetLayoutLabel(app)
    if g.HasOwnProp("noteEdit")
        g.noteEdit.Value := GetPaletteNote(app.activePalette)

    SavePaletteList(app)
    Emit(app, "history_changed")
    ShowToast(app, "🗑 Deleted palette: " name)
}

DuplicatePaletteUI(app, g) {
    srcName := GetActivePaletteName(app)

    ShowInputDialog(app, "Duplicate palette as:", "📋 Duplicate", (val) => DuplicatePaletteConfirm(app, g, val), srcName " Copy")
}

DuplicatePaletteConfirm(app, g, val) {
    newName := Trim(val)
    if (newName = "")
        return

    if app.palettes.Has(newName) {
        ShowToast(app, "Palette already exists!")
        return
    }

    srcName := GetActivePaletteName(app)
    src := app.palettes[srcName]
    newFile := A_ScriptDir "\color\" newName ".txt"

    p := CreatePalette(newName, newFile)

    for item in src.colors {
        clone := CreateItem(item.hex, item.rgb, item.name, item.role)
        clone.pinned := item.pinned
        clone.pinOrder := item.pinOrder
        clone.section := item.section
        clone.paint := item.HasOwnProp("paint") ? item.paint : ""
        clone.isSaved := true

        p.colors.Push(clone)
        if !p.map.Has(clone.hex)
            p.map[clone.hex] := clone
        p.idMap[clone.id] := clone
    }

    p.historyMax := src.historyMax
    p.maxCols := src.maxCols
    p.guiMode := src.HasOwnProp("guiMode") ? src.guiMode : "undocked"
    p.note := src.HasOwnProp("note") ? src.note : ""

    for section in src.sections {
        if IsObject(section) {
            p.sections.Push({
                id: GenerateSectionId(),
                name: section.name,
                isDefault: section.HasOwnProp("isDefault") ? section.isDefault : false,
                locked: section.HasOwnProp("locked") ? section.locked : false,
                collapsed: section.HasOwnProp("collapsed") ? section.collapsed : false,
                tag: section.HasOwnProp("tag") ? section.tag : "",
                note: section.HasOwnProp("note") ? section.note : ""
            })
        }
    }

    app.palettes[newName] := p
    app.paletteOrder.Push(newName)

    SavePalette(p, app.version)
    SavePaletteList(app)

    RefreshPaletteList(app, g)
    ShowToast(app, "📋 Duplicated palette: " newName)
}

RenamePaletteUI(app, g) {
    oldName := GetActivePaletteName(app)

    ShowInputDialog(app, "Rename palette:", "✏ Rename", (val) => RenamePaletteConfirm(app, g, val), oldName)
}

RenamePaletteConfirm(app, g, val) {
    newName := Trim(val)
    if (newName = "")
        return

    if app.palettes.Has(newName) {
        ShowToast(app, "Palette already exists!")
        return
    }

    oldName := GetActivePaletteName(app)
    oldFile := app.palettes[oldName].file
    newFile := A_ScriptDir "\color\" newName ".txt"

    if FileExist(oldFile)
        FileMove(oldFile, newFile, true)

    p := app.palettes[oldName]
    p.name := newName
    p.file := newFile

    app.palettes.Delete(oldName)
    app.palettes[newName] := p

    for i, name in app.paletteOrder {
        if (name = oldName) {
            app.paletteOrder[i] := newName
            break
        }
    }

    app.activePalette := p
    LoadHistory(app)

    RefreshPaletteList(app, g)
    SavePaletteList(app)
    ShowToast(app, "✏ Renamed palette to: " newName)
}

MovePalette(app, g, dir) {
    if app.HasOwnProp("paletteUIBusy") && app.paletteUIBusy
        return
    app.paletteUIBusy := true

    sel := g.list.GetNext()
    if !sel {
        app.paletteUIBusy := false
        return
    }

    currentName := app.paletteOrder[sel]
    if !currentName || !app.palettes.Has(currentName) {
        app.paletteUIBusy := false
        return
    }

    currentP := app.palettes[currentName]

    if dir = -1 && sel > 1 {
        swapName := app.paletteOrder[sel - 1]
        swapP := app.palettes[swapName]
        temp := currentP.priority
        currentP.priority := swapP.priority
        swapP.priority := temp
        SavePalette(currentP, app.version)
        SavePalette(swapP, app.version)
    } else if dir = 1 && sel < app.paletteOrder.Length {
        swapName := app.paletteOrder[sel + 1]
        swapP := app.palettes[swapName]
        temp := currentP.priority
        currentP.priority := swapP.priority
        swapP.priority := temp
        SavePalette(currentP, app.version)
        SavePalette(swapP, app.version)
    } else {
        if !currentP.HasOwnProp("priority")
            currentP.priority := 1
        currentP.priority += dir
        if currentP.priority < 1
            currentP.priority := 1
        SavePalette(currentP, app.version)
    }

    RefreshPaletteList(app, g)

    app.paletteUIBusy := false
}

ImportPaletteImageUI(app) {
    path := PickImportImagePath(app)
    if (path = "")
        return

    ext := GetImportFileExtension(path)

    if IsImageImportExtension(ext) {
        ShowImportModeDialog(app, path)
        return
    }

    if IsPaletteDataImportExtension(ext) {
        ImportPaletteDataFile(app, path)
        return
    }

    ShowToast(app, "Unsupported import file type")
}

PickImportImagePath(app) {
    try {
        path := FileSelect("1", , "Import Palette", "Supported Files (*.png;*.jpg;*.jpeg;*.bmp;*.txt;*.ini;*.json;*.csv)")
        if (path != "")
            return path
    } catch {
        ShowToast(app, "File picker unavailable, use path input")
    }

    return ShowImportPathDialog(app)
}

ShowImportPathDialog(app) {
    result := ""
    g := Gui("+AlwaysOnTop +ToolWindow +Border", "Import File Path")
    g.BackColor := "323338"
    g.SetFont("s9", "Consolas")
    g.MarginX := 16
    g.MarginY := 12

    g.AddText("cFFFFFF w360", "Paste a file path or drop a supported import file here:")
    g.pathEdit := g.AddEdit("w360 y+6")
    g.AddText("c909090 w360 y+6", "Supported: PNG, JPG, JPEG, BMP, TXT, INI, JSON, CSV")

    g.OnEvent("DropFiles", ImportPathDialogDropFiles)
    g.AddButton("w120 h28 y+14", "Import").OnEvent("Click", (*) => ConfirmImportPathDialog(app, g, &result))
    g.AddButton("w120 h28 x+10", "Cancel").OnEvent("Click", (*) => g.Destroy())

    g.Show("AutoSize Center")
    WinWaitClose("ahk_id " g.Hwnd)
    return result
}

ImportPathDialogDropFiles(g, files) {
    first := ""
    for _, file in files {
        first := file
        break
    }
    if (first != "")
        g.pathEdit.Value := first
}

ConfirmImportPathDialog(app, g, &result) {
    path := Trim(g.pathEdit.Value)
    if (path = "") {
        ShowToast(app, "Enter file path")
        return
    }
    if !FileExist(path) {
        ShowToast(app, "Import file not found")
        return
    }

    ext := GetImportFileExtension(path)
    if !(IsImageImportExtension(ext) || IsPaletteDataImportExtension(ext)) {
        ShowToast(app, "Unsupported import type")
        return
    }

    result := path
    g.Destroy()
}

ImportFolderImages(app) {
    ShowFolderSelectDialog(app)
}

ShowFolderSelectDialog(app) {
    g := Gui("+AlwaysOnTop +ToolWindow +Border", "Select Folder")
    g.BackColor := "323338"
    g.SetFont("s9", "Consolas")
    g.MarginX := 16
    g.MarginY := 12

    g.AddText("cFFFFFF", "Select folder with import files:")
    g.folderEdit := g.AddEdit("w265 y+4")
    g.AddButton("x+5 yp w30 h24", "...").OnEvent("Click", (*) => DoBrowseFolder(app, g))

    g.AddText("xm cFFFFFF y+10", "Or enter path:")
    g.pathEdit := g.AddEdit("w300 y+4")

    g.AddButton("w120 h28 y+15", "Select").OnEvent("Click", (*) => DoSelectFolder(app, g))
    g.AddButton("w120 h28 x+10", "Cancel").OnEvent("Click", (*) => g.Destroy())

    g.Show("AutoSize Center")
    app.folderSelectGui := g
    return ""
}

DoBrowseFolder(app, g) {
    folderPath := FileSelect("D", , "Select folder with import files")
    if (folderPath != "") {
        g.folderEdit.Value := folderPath
        g.pathEdit.Value := folderPath
    }
}

DoSelectFolder(app, g) {
    folderPath := Trim(g.pathEdit.Value)
    if folderPath = "" {
        folderPath := Trim(g.folderEdit.Value)
    }
    g.Destroy()
    if folderPath != "" {
        ContinueFolderImport(app, folderPath)
    }
}

ContinueFolderImport(app, folderPath) {
    if !DirExist(folderPath) {
        ShowToast(app, "Folder not found")
        return
    }

    importFiles := []

    Loop Files, folderPath "\*", "F" {
        ext := GetImportFileExtension(A_LoopFileName)
        if IsImageImportExtension(ext) || IsPaletteDataImportExtension(ext)
            importFiles.Push(A_LoopFileFullPath)
    }

    if importFiles.Length = 0 {
        ShowToast(app, "No supported import files found in folder")
        return
    }

    ShowImportFolderPreview(app, folderPath, importFiles)
}

ShowImportMenu(app, g) {
    menu := Gui("+AlwaysOnTop -Caption +ToolWindow", "Import")
    menu.BackColor := "323338"
    menu.SetFont("s9", "Consolas")
    menu.MarginX := 0
    menu.MarginY := 0

    menu.AddButton("w130 h28", "📷 Screenshot").OnEvent("Click", (*) => (menu.Destroy(), DispatchAction(app, g, "Snip")))
    menu.AddButton("w130 h28", "🖼️ Import File").OnEvent("Click", (*) => (menu.Destroy(), DispatchAction(app, g, "Import")))
    menu.AddButton("w130 h28", "📁 Folder").OnEvent("Click", (*) => (menu.Destroy(), DispatchAction(app, g, "Folder")))
    menu.AddButton("w130 h28", "❌ Cancel").OnEvent("Click", (*) => (menu.Destroy()))

    menu.Show("AutoSize Center")
}

ShowImportFolderPreview(app, folderPath, imageFiles) {
    g := Gui("+AlwaysOnTop +ToolWindow +Border", "Import from Folder")
    g.BackColor := "323338"
    g.SetFont("s9", "Consolas")
    g.MarginX := 16
    g.MarginY := 12

    shortPath := folderPath
    if (StrLen(folderPath) > 50)
        shortPath := "..." SubStr(folderPath, -47)

    g.AddText("cFFFFFF", "Folder: " shortPath)
    g.AddButton("x+8 yp w30 h20", "📁").OnEvent("Click", (*) => Run('explorer.exe "' folderPath '"'))

    g.AddText("xm cAAAAAA y+5", "Found " imageFiles.Length " supported files:")
    g.fileList := g.AddListView("w450 h200 -Multi", ["#", "File Name"])
    g.fileList.SetFont("s8", "Consolas")
    totalW := 450
    hexW := 40
    remaining := totalW - hexW - 20
    each := Floor(remaining / 1)
    g.fileList.ModifyCol(1, hexW)
    Loop 1
        g.fileList.ModifyCol(A_Index + 1, each)

    for i, fpath in imageFiles {
        fname := SubStr(fpath, InStr(fpath, "\",, -1) + 1)
        g.fileList.Add("", i, fname)
    }

    totalColors := 0
    for imgPath in imageFiles {
        imported := GetImportedTextFromImportFile(app, imgPath)
        if (Trim(imported) = "")
            continue

        parsed := ParseImportedData(imported)
        for _, sectionName in parsed.sectionOrder
            totalColors += parsed.sections[sectionName].Length
    }

    g.AddText("y+5 cAAAAAA", "Est. ~" totalColors " detected/importable colors")

    g.AddButton("w140 h28 y+10", "🔍 Import Colors").OnEvent("Click", (*) => DoImportFolderImages(app, g, folderPath, imageFiles))
    g.AddButton("w140 h28 x+10", "Cancel").OnEvent("Click", (*) => g.Destroy())

    g.Show("AutoSize Center")
}

DoImportFolderImages(app, g, folderPath, imageFiles) {
    g.Destroy()
    ShowToast(app, "Processing " imageFiles.Length " files...")

    successCount := 0
    for imgPath in imageFiles {
        try {
            imported := GetImportedTextFromImportFile(app, imgPath)
            if (Trim(imported) = "") {
                continue
            }

            parsed := ParseImportedData(imported)
            if (!parsed.sections.Count) {
                continue
            }

            sourceName := parsed.HasOwnProp("sourceName") && parsed.sourceName != "" ? parsed.sourceName : ""

            if (sourceName = "") {
                SplitPath(imgPath, &fileName)
                sourceName := RegExReplace(fileName, "\.[^.]+$")
                sourceName := StrReplace(sourceName, "_", " ")
                sourceName := StrReplace(sourceName, "-", " ")
            }

            paletteName := sourceName
            counter := 1
            originalName := paletteName
            while app.palettes.Has(paletteName) {
                counter++
                paletteName := originalName " " counter
            }

            safeName := RegExReplace(paletteName, "[^a-zA-Z0-9 _\-]", "")
            safeName := Trim(safeName)
            if (safeName = "")
                safeName := "ImportedPalette"
            fileName := A_ScriptDir "\color\" safeName ".txt"
            p := CreatePalette(paletteName, fileName)

            for _, sectionName in parsed.sectionOrder {
                AddSectionName(p, sectionName)
                for _, color in parsed.sections[sectionName] {
                    hex := Trim(color.hex)
                    if !RegExMatch(hex, "^[0-9A-Fa-f]{6}$")
                        continue

                    rgb := color.rgb != "" ? color.rgb : ImportReviewGetRGBFromHex(hex)
                    name := color.name != "" ? color.name : GetColorName(hex)
                    role := color.role != "" ? color.role : "Base"

                    item := CreateItem(hex, rgb, name, role)
                    item.section := sectionName
                    item.paint := "P"
                    AddColor(p, item)
                }
            }

            if p.colors.Length > 0 {
                app.palettes[paletteName] := p
                app.paletteOrder.Push(paletteName)
                SavePalette(p, app.version)
                successCount++
            }
        }
    }

    if successCount > 0 {
        ShowToast(app, "Created " successCount " palettes")
        RefreshPaletteManager(app, app.paletteGui)
        if app.palettes.Has(app.paletteOrder[app.paletteOrder.Length]) {
            SwitchPalette(app, app.paletteOrder[app.paletteOrder.Length])
        }
    } else {
        ShowToast(app, "No importable palette colors detected")
    }
}

RunPaletteImportDetection(app, imgPath) {
    outPath := A_Temp "\folder_import_nastarxa" A_TickCount "_" Abs(Mod(StrLen(imgPath), 1000)) ".txt"
    scriptPath := A_Temp "\folder_import_nastarxa" A_TickCount "_" Abs(Mod(StrLen(imgPath) * 7, 1000)) ".ps1"
    trainingPath := GetImportTrainingPath()

    if FileExist(outPath)
        FileDelete(outPath)
    if FileExist(scriptPath)
        FileDelete(scriptPath)

    FileAppend(GetPaletteImageImportScript(), scriptPath, "UTF-8")

    cmd := Format(
        'powershell -NoProfile -ExecutionPolicy Bypass -File "{}" "{}" "{}" "{}"',
        scriptPath,
        imgPath,
        outPath,
        trainingPath
    )
    RunWait(cmd, , "Hide")

    imported := FileExist(outPath) ? FileRead(outPath, "UTF-8") : ""

    try FileDelete(scriptPath)
    try FileDelete(outPath)

    return imported
}

GetImportedTextFromImportFile(app, path) {
    ext := GetImportFileExtension(path)

    if IsImageImportExtension(ext)
        return RunPaletteImportDetection(app, path)
    if IsPaletteDataImportExtension(ext)
        return ParsePaletteDataFileToImportedText(path)

    return ""
}

ProcessSingleImportFile(app, imgPath, tempPath) {
    ext := GetImportFileExtension(imgPath)
    if IsImageImportExtension(ext)
        return ProcessSingleImageImport(app, imgPath, tempPath)
    if IsPaletteDataImportExtension(ext)
        return ProcessSinglePaletteDataImport(app, imgPath)
    return false
}

ProcessSingleImageImport(app, imgPath, tempPath) {
    imported := GetImportedTextFromImportFile(app, imgPath)
    if (Trim(imported) = "")
        return false

    parsed := ParseImportedData(imported)
    return ApplyParsedImportToActivePalette(app, parsed)
}

ProcessSinglePaletteDataImport(app, path) {
    imported := GetImportedTextFromImportFile(app, path)
    if (Trim(imported) = "")
        return false

    parsed := ParseImportedData(imported)
    return ApplyParsedImportToActivePalette(app, parsed)
}

ApplyParsedImportToActivePalette(app, parsed) {
    totalImported := 0
    p := app.activePalette

    for _, sectionName in parsed.sectionOrder {
        AddSectionName(p, sectionName)
        for _, color in parsed.sections[sectionName] {
            hex := Trim(color.hex)
            if !RegExMatch(hex, "^[0-9A-Fa-f]{6}$")
                continue
            if p.map.Has(hex)
                continue

            rgb := color.rgb != "" ? color.rgb : ImportReviewGetRGBFromHex(hex)
            name := color.name != "" ? color.name : GetColorName(hex)
            role := color.role != "" ? color.role : "Base"

            item := CreateItem(hex, rgb, name, role)
            item.section := sectionName
            item.pinned := color.HasOwnProp("pinned") ? color.pinned : 0
            item.pinOrder := color.HasOwnProp("pinOrder") ? color.pinOrder : 0
            item.paint := "P"
            AddColor(p, item)
            totalImported++
        }
    }

    return totalImported > 0
}

ImportPaletteDataFile(app, path) {
    imported := ParsePaletteDataFileToImportedText(path)
    if (Trim(imported) = "") {
        ShowToast(app, "Could not parse palette file")
        return
    }

    reviewPath := A_Temp "\palette_file_import_nastarxa.txt"
    if FileExist(reviewPath)
        FileDelete(reviewPath)
    FileAppend(imported, reviewPath, "UTF-8")

    importMode := app.HasOwnProp("importMode") ? app.importMode : "insert"
    app.importMode := ""
    ShowImportReview(app, imported, reviewPath, "", false, importMode)
}

GetImportFileExtension(path) {
    dotPos := InStr(path, ".",, -1)
    return dotPos ? StrLower(SubStr(path, dotPos + 1)) : ""
}

IsImageImportExtension(ext) {
    return ext = "png" || ext = "jpg" || ext = "jpeg" || ext = "bmp" || ext = "gif" || ext = "webp"
}

IsPaletteDataImportExtension(ext) {
    return ext = "txt" || ext = "ini" || ext = "json" || ext = "csv"
}

GetImportSourceName(path) {
    SplitPath(path, &fileName)
    name := RegExReplace(fileName, "\.[^.]+$")
    name := StrReplace(name, "_", " ")
    name := StrReplace(name, "-", " ")
    name := RegExReplace(name, "\s+", " ")
    return Trim(name) != "" ? Trim(name) : "Imported"
}

ParsePaletteDataFileToImportedText(path) {
    ext := GetImportFileExtension(path)
    content := FileRead(path, "UTF-8")
    sourceName := GetImportSourceName(path)

    switch ext {
        case "txt":
            return ParsePaletteTxtImport(content, sourceName)
        case "ini":
            return ParsePaletteIniImport(content, sourceName)
        case "json":
            return ParsePaletteJsonImport(content, sourceName)
        case "csv":
            return ParsePaletteCsvImport(content, sourceName)
        default:
            return ""
    }
}

BuildImportedTextFromSections(sourceName, sectionOrder, sectionColors) {
    lines := []
    lines.Push("#IMAGE|0|0|" sourceName)

    for _, sectionName in sectionOrder {
        if !sectionColors.Has(sectionName)
            continue
        lines.Push("#SECTION||" sectionName)
        pinOrder := 1
        for _, color in sectionColors[sectionName] {
            hex := StrUpper(RegExReplace(color.hex, "(?i)[^0-9A-F]"))
            if !RegExMatch(hex, "^[0-9A-F]{6}$")
                continue

            rgb := color.rgb != "" ? color.rgb : ImportReviewGetRGBFromHex(hex)
            name := color.name != "" ? color.name : sectionName " " color.role
            role := color.role != "" ? color.role : "Base"
            pinned := color.HasOwnProp("pinned") ? color.pinned : 0
            order := color.HasOwnProp("pinOrder") && color.pinOrder > 0 ? color.pinOrder : pinOrder
            lines.Push(hex "|" rgb "|" name "|" role "|" pinned "|" order "|" sectionName "|0|0|0|0")
            pinOrder++
        }
    }

    return JoinLines(lines)
}

ParsePaletteTxtImport(content, sourceName) {
    sectionOrder := ["Default"]
    sectionColors := Map("Default", [])
    currentSection := "Default"

    for _, rawLine in StrSplit(content, "`n", "`r") {
        line := Trim(rawLine)
        if (line = "")
            continue

        if (SubStr(line, 1, 1) = "#") {
            if (SubStr(line, 1, 9) = "#SECTION|") {
                parts := StrSplit(line, "|")
                if (parts.Length >= 3) {
                    currentSection := Trim(parts[3])
                    if (!sectionColors.Has(currentSection)) {
                        sectionColors[currentSection] := []
                        sectionOrder.Push(currentSection)
                    }
                }
            }
            continue
        }

        parts := StrSplit(line, "|")
        if parts.Length < 7
            continue

        hex := Trim(parts[1])
        if (InStr(hex, "#") = 1)
            hex := SubStr(hex, 2)
        if (hex = "" || !RegExMatch(hex, "^[0-9A-Fa-f]{6}$"))
            continue

        colorSection := parts.Length >= 7 ? Trim(parts[7]) : "Default"
        if (colorSection = "")
            colorSection := currentSection

        if (!sectionColors.Has(colorSection)) {
            sectionColors[colorSection] := []
            sectionOrder.Push(colorSection)
        }

        role := Trim(parts[4])
        pinned := 0
        if parts.Length >= 5 && InStr(parts[5], "pinned=")
            pinned := (Trim(SubStr(parts[5], 8)) = "1") ? 1 : 0

        sectionColors[colorSection].Push({
            hex: hex,
            rgb: Trim(parts[2]),
            name: Trim(parts[3]),
            role: role,
            pinned: pinned
        })
    }

    return BuildImportedTextFromSections(sourceName, sectionOrder, sectionColors)
}

ParsePaletteIniImport(content, sourceName) {
    sectionOrder := ["Default"]
    sectionColors := Map("Default", [])
    currentSection := "Default"
    currentColor := 0

    FinalizeIniColor() {
        if IsObject(currentColor) {
            hex := Trim(currentColor.hex)
            if (InStr(hex, "#") = 1)
                hex := SubStr(hex, 2)
            if (hex = "" || !RegExMatch(hex, "^[0-9A-Fa-f]{6}$")) {
                currentColor := 0
                return
            }
            currentColor.hex := hex
            if (!sectionColors.Has(currentSection))
                sectionColors[currentSection] := []
            sectionColors[currentSection].Push(currentColor)
        }
    }

    for _, rawLine in StrSplit(content, "`n", "`r") {
        line := Trim(rawLine)
        if (line = "" || SubStr(line, 1, 1) = ";")
            continue

        if RegExMatch(line, "^\[(.+)\]$", &m) {
            FinalizeIniColor()
            currentSection := Trim(m[1])
            if (!sectionColors.Has(currentSection)) {
                sectionColors[currentSection] := []
                sectionOrder.Push(currentSection)
            }
            currentColor := { hex: "", rgb: "", name: "", role: "Base", pinned: 0 }
            continue
        }

        eqPos := InStr(line, "=")
        if !eqPos || !IsObject(currentColor)
            continue

        key := StrLower(Trim(SubStr(line, 1, eqPos - 1)))
        value := Trim(SubStr(line, eqPos + 1))
        switch key {
            case "hex":
                currentColor.hex := value
            case "rgb":
                currentColor.rgb := value
            case "name":
                currentColor.name := value
            case "role":
                currentColor.role := value
            case "pinned":
                currentColor.pinned := (value = "1") ? 1 : 0
            case "section":
                FinalizeIniColor()
                currentSection := value
                if (!sectionColors.Has(currentSection)) {
                    sectionColors[currentSection] := []
                    sectionOrder.Push(currentSection)
                }
                currentColor := { hex: "", rgb: "", name: "", role: "Base", pinned: 0 }
        }
    }
    FinalizeIniColor()

    return BuildImportedTextFromSections(sourceName, sectionOrder, sectionColors)
}

ParsePaletteJsonImport(content, sourceName) {
    sectionOrder := []
    sectionColors := Map()
    pos := 1

    while RegExMatch(content, '\{[^{}]*"hex"\s*:\s*"([^"]+)"[^{}]*\}', &m, pos) {
        block := m[0]
        pos := m.Pos + m.Len

        hex := JsonFieldValue(block, "hex")
        rgb := JsonFieldValue(block, "rgb")
        name := JsonFieldValue(block, "name")
        role := JsonFieldValue(block, "role")
sectionName := JsonFieldValue(block, "section")
        pinned := StrLower(JsonFieldValue(block, "pinned")) = "true" ? 1 : 0

        hex := Trim(hex)
        if (InStr(hex, "#") = 1)
            hex := SubStr(hex, 2)
        if (hex = "" || !RegExMatch(hex, "^[0-9A-Fa-f]{6}$"))
            continue

        if (sectionName = "")
            sectionName := "Default"
        if !sectionColors.Has(sectionName) {
            sectionColors[sectionName] := []
            sectionOrder.Push(sectionName)
        }

        sectionColors[sectionName].Push({
            hex: hex,
            rgb: rgb,
            name: name,
            role: role,
            pinned: pinned
        })
    }

    return BuildImportedTextFromSections(sourceName, sectionOrder, sectionColors)
}

JsonFieldValue(block, fieldName) {
    pattern := '"' fieldName '"\s*:\s*"([^"]*)"'
    if RegExMatch(block, pattern, &m)
        return m[1]
    if RegExMatch(block, '"' fieldName '"\s*:\s*(true|false)', &m)
        return m[1]
    if RegExMatch(block, '"' fieldName '"\s*:\s*(-?\d+\.?\d*)', &m)
        return m[1]
    return ""
}

ParsePaletteCsvImport(content, sourceName) {
    sectionOrder := ["Default"]
    sectionColors := Map("Default", [])
    currentSection := "Default"

    for _, rawLine in StrSplit(content, "`n", "`r") {
        line := Trim(rawLine)
        if (line = "")
            continue

        if (SubStr(line, 1, 1) = "#") {
            if (SubStr(line, 1, 9) = "#SECTION|") {
                parts := StrSplit(line, "|")
                if (parts.Length >= 3) {
                    currentSection := Trim(parts[3])
                    if (!sectionColors.Has(currentSection)) {
                        sectionColors[currentSection] := []
                        sectionOrder.Push(currentSection)
                    }
                }
            }
            continue
        }

        parts := ParseCsvLine(line)
        if parts.Length < 7
            continue

        hex := Trim(parts[1])
        if (InStr(hex, "#") = 1)
            hex := SubStr(hex, 2)
        if (hex = "" || !RegExMatch(hex, "^[0-9A-Fa-f]{6}$"))
            continue

        sectionName := parts.Length >= 7 ? Trim(parts[7]) : "Default"
        if (sectionName = "")
            sectionName := "Default"

        if (!sectionColors.Has(sectionName)) {
            sectionColors[sectionName] := []
            sectionOrder.Push(sectionName)
        }

        sectionColors[sectionName].Push({
            hex: hex,
            rgb: Trim(parts[2]),
            name: Trim(parts[3]),
            role: Trim(parts[4]),
            pinned: parts[5] = "1" ? 1 : 0
        })
    }

    return BuildImportedTextFromSections(sourceName, sectionOrder, sectionColors)
}

ParseCsvLine(line) {
    values := []
    current := ""
    inQuotes := false
    i := 1

    while (i <= StrLen(line)) {
        ch := SubStr(line, i, 1)
        if (ch = '"') {
            if inQuotes && i < StrLen(line) && SubStr(line, i + 1, 1) = '"' {
                current .= '"'
                i += 1
            } else {
                inQuotes := !inQuotes
            }
        } else if (ch = "," && !inQuotes) {
            values.Push(current)
            current := ""
        } else {
            current .= ch
        }
        i += 1
    }

    values.Push(current)
    return values
}

ShowImportModeDialog(app, imagePath) {
    g := Gui("+AlwaysOnTop +ToolWindow", "📥 Import")
    g.BackColor := "323338"
    g.SetFont("s9", "Consolas")

    shortPath := imagePath
    slashPos := InStr(imagePath, "\",, -60)
    if (slashPos > 0)
        shortPath := "..." SubStr(imagePath, slashPos)

    g.AddText("xm y+5 c888888 w450", shortPath)

    g.AddButton("xm y+10 w450 h32", "🔍 Review Import Colors")
        .OnEvent("Click", (*) => (g.Destroy(), ImportPaletteImage(app, imagePath)))

    g.AddButton("xm y+3 w450 h28", "❌ Cancel")
        .OnEvent("Click", (*) => g.Destroy())

    g.Show("AutoSize Center")
}

ImportPaletteImage(app, imagePath) {
    outPath := A_Temp "\palette_import_nastarxa.txt"
    scriptPath := A_Temp "\palette_import_nastarxa.ps1"
    trainingPath := GetImportTrainingPath()

    if FileExist(outPath)
        FileDelete(outPath)
    if FileExist(scriptPath)
        FileDelete(scriptPath)

    FileAppend(GetPaletteImageImportScript(), scriptPath, "UTF-8")

    cmd := Format(
        'powershell -NoProfile -ExecutionPolicy Bypass -File "{}" "{}" "{}" "{}"',
        scriptPath,
        imagePath,
        outPath,
        trainingPath
    )

    RunWait(cmd, , "Hide")

    if !FileExist(outPath) {
        ShowToast(app, "Image import failed.")
        if (imagePath != "" && FileExist(imagePath))
            try FileDelete(imagePath)
        return
    }

    imported := FileRead(outPath, "UTF-8")
    if (Trim(imported) = "") {
        ShowToast(app, "No palette blocks were detected from that image.")
        if (imagePath != "" && FileExist(imagePath))
            try FileDelete(imagePath)
        return
    }

    isTemp := (imagePath != "" && InStr(imagePath, A_Temp) = 1)
    importMode := app.HasOwnProp("importMode") ? app.importMode : "new"
    app.importMode := ""
    ShowImportReview(app, imported, outPath, imagePath, isTemp, importMode)
}

GetPaletteImageImportScript() {
    return FileRead(A_ScriptDir "\src\features\palette_image_import.ps1")
}

StartPaletteScreenshotImport(app) {
    if app.screenshotCapture.active {
        CancelPaletteScreenshotImport(app, "")
        Sleep(500)
    }

    if !IsObject(app.screenshotPollFn)
        app.screenshotPollFn := PollPaletteScreenshotImport.Bind(app)

    app.screenshotCapture.savedClipboard := ClipboardAll()
    app.screenshotCapture.active := true
    app.screenshotCapture.noSnipTicks := 0
    app.screenshotCapture.deadline := A_TickCount + 120000
    app.screenshotCapture.tempPath := A_Temp "\palette_capture_nastarxa.png"

    A_Clipboard := ""
    ShowToast(app, "Snip the palette area, then release mouse")
    Run("ms-screenclip:")
    SetTimer(app.screenshotPollFn, 250)
}

PollPaletteScreenshotImport(app) {
    if !app.screenshotCapture.active {
        SetTimer(app.screenshotPollFn, 0)
        return
    }

    if (A_TickCount > app.screenshotCapture.deadline) {
        CancelPaletteScreenshotImport(app, "Screenshot import canceled")
        return
    }

    if ClipboardHasImage() {
        SetTimer(app.screenshotPollFn, 0)
        tempPath := app.screenshotCapture.tempPath

        if !SaveClipboardImageToFile(tempPath) {
            CancelPaletteScreenshotImport(app, "Could not read screenshot from clipboard")
            return
        }

        app.screenshotCapture.active := false
        try A_Clipboard := app.screenshotCapture.savedClipboard
        catch
            app.screenshotCapture.savedClipboard := 0

        ShowImportModeDialog(app, tempPath)
        return
    }

    if !WinExist("ahk_exe ScreenClippingHost.exe") && !WinExist("Snip & Sketch") && !WinExist("ahk_class Microsoft.UI.Content.Desktop") {
        if !app.screenshotCapture.HasOwnProp("noSnipTicks")
            app.screenshotCapture.noSnipTicks := 0
        app.screenshotCapture.noSnipTicks++
        if app.screenshotCapture.noSnipTicks > 20 {
            CancelPaletteScreenshotImport(app, "")
            return
        }
    } else {
        app.screenshotCapture.noSnipTicks := 0
    }
}

CancelPaletteScreenshotImport(app, message := "") {
    app.screenshotCapture.active := false
    SetTimer(app.screenshotPollFn, 0)
    app.screenshotCapture.noSnipTicks := 0

    try A_Clipboard := app.screenshotCapture.savedClipboard
    catch
        app.screenshotCapture.savedClipboard := 0

    if (message != "")
        ShowToast(app, message)
}

ClipboardHasImage() {
    return DllCall("IsClipboardFormatAvailable", "UInt", 2)
        || DllCall("IsClipboardFormatAvailable", "UInt", 8)
        || DllCall("IsClipboardFormatAvailable", "UInt", 17)
}

SaveClipboardImageToFile(path) {
    scriptPath := A_Temp "\clipboard_image_save_nastarxa.ps1"

    if FileExist(scriptPath)
        FileDelete(scriptPath)
    if FileExist(path)
        FileDelete(path)

    FileAppend(GetClipboardImageSaveScript(), scriptPath, "UTF-8")

    cmd := Format(
        'powershell -NoProfile -ExecutionPolicy Bypass -File "{}" "{}"',
        scriptPath,
        path
    )

    RunWait(cmd, , "Hide")
    return FileExist(path)
}

GetClipboardImageSaveScript() {
    return FileRead(A_ScriptDir "\src\features\clipboard_image_save.ps1")
}

ToggleDisplayMode(app, g) {
    current := app.HasOwnProp("displayMode") ? app.displayMode : "hex"
    app.displayMode := current = "hex" ? "rgb" : "hex"

    for ctrl in g {
        if ctrl.Type = "Button" && (InStr(ctrl.Text, "HEX") || InStr(ctrl.Text, "RGB")) {
            label := app.displayMode = "hex" ? "HEX" : "RGB"
            ctrl.Text := "📋 " . label
            break
        }
    }

    if app.historyVisible {
        for _, item in app.activePalette.colors {
            token := GetItemToken(item)
            if app.ui.controls.Has(token)
                UpdateCellDisplay(app, token)
        }
    }

    ShowToast(app, "Display mode: " StrUpper(app.displayMode))
}

DispatchAction(app, g, label) {
    switch label {
        case "New": CreatePaletteUI(app, g)
        case "Snip": StartPaletteScreenshotImport(app)
        case "Import": ImportPaletteImageUI(app)
        case "Folder": ImportFolderImages(app)
        case "Delete": DeletePaletteUI(app, g)
        case "Duplicate": DuplicatePaletteUI(app, g)
        case "Rename": RenamePaletteUI(app, g)
    }
}

DispatchToolAction(app, g, label) {
    switch label {
        case "Merge": OpenPaletteMergeDialog(app)
        case "Compare": OpenPaletteCompareDialog(app)
        case "Templates": OpenPaletteTemplateDialog(app)
    }
}

OpenPaletteMergeDialog(app) {
    palNames := []
    for name in app.paletteOrder
        palNames.Push(name)

    if palNames.Length < 2 {
        ShowToast(app, "Need at least 2 palettes to merge")
        return
    }

    g := Gui("+AlwaysOnTop +ToolWindow +Border", "Merge Palette")
    g.BackColor := "323338"
    g.SetFont("s9", "Consolas")
    g.MarginX := 16
    g.MarginY := 12

    g.AddText("cFFFFFF", "Source (colors to add):")
    g.sourceList := g.AddDropDownList("w250 y+4", palNames)
    g.sourceList.Value := 1

    g.AddText("cFFFFFF y+10", "Target (palette to merge into):")
    g.targetList := g.AddDropDownList("w250 y+4", palNames)
    if palNames.Length > 1
        g.targetList.Value := 2
    else
        g.targetList.Value := 1

    g.AddText("cAAAAAA y+12", "Options:")

    g.chkSkipDup := g.AddCheckbox("Checked y+4 cAAAAAA", "Skip duplicates (keep existing)")
    g.chkDeleteSrc := g.AddCheckbox("y+4 cAAAAAA", "Delete source palette after merge")

    g.AddText("cAAAAAA y+10", "Section (leave empty for default):")
    g.sectionEdit := g.AddEdit("w250 y+4")

    g.AddButton("w110 h28 y+16", "Merge").OnEvent("Click", (*) => DoPaletteMerge(app, g))
    g.AddButton("w110 h28 x+10", "Cancel").OnEvent("Click", (*) => g.Destroy())

    g.Show("AutoSize Center")
}

DoPaletteMerge(app, g) {
    srcName := g.sourceList.Text
    tgtName := g.targetList.Text

    if (srcName = tgtName) {
        ShowToast(app, "Source and target must be different")
        return
    }

    src := app.palettes[srcName]
    tgt := app.palettes[tgtName]
    skipDup := g.chkSkipDup.Value
    deleteSrc := g.chkDeleteSrc.Value
    section := Trim(g.sectionEdit.Value)
    if section = ""
        section := "Imported"

    added := 0
    skipped := 0

    for item in src.colors {
        hex := item.hex
        if skipDup && tgt.map.Has(hex) {
            skipped++
            continue
        }
        newItem := CreateItem(hex, item.rgb, item.name, item.role)
        newItem.section := item.section
        newItem.pinned := 0
        newItem.paint := item.HasOwnProp("paint") ? item.paint : "TP"
        AddColor(tgt, newItem)
        added++
        if !HasSectionName(tgt, item.section)
            AddSectionName(tgt, item.section)
    }

    Normalize(tgt)
    SaveHistory(app)

    if deleteSrc {
        palettePath := app.palettes[srcName].file
        if FileExist(palettePath)
            FileDelete(palettePath)
        app.palettes.Delete(srcName)
        for i, n in app.paletteOrder {
            if (n = srcName) {
                app.paletteOrder.RemoveAt(i)
                break
            }
        }
        if (app.activePalette.name = srcName)
            app.activePalette := tgt
        SavePaletteList(app)
    }

    g.Destroy()
    if app.historyVisible
        QueueHistoryRebuild(app)
    msg := "Merged: " added " added, " skipped " skipped"
    if deleteSrc
        msg .= ". Deleted " srcName
    ShowToast(app, msg)
}

OpenPaletteCompareDialog(app) {
    if app.paletteGui {
        RefreshPaletteManager(app, app.paletteGui)
    }

    palNames := []
    for name in app.paletteOrder
        palNames.Push(name)

    if palNames.Length < 2 {
        ShowToast(app, "Need at least 2 palettes to compare")
        return
    }

    activeName := app.activePalette.name
    activeIndex := 1
    for i, name in palNames {
        if name = activeName {
            activeIndex := i
            break
        }
    }

    g := Gui("+AlwaysOnTop +ToolWindow +Border", "Compare Palettes")
    g.BackColor := "323338"
    g.SetFont("s9", "Consolas")
    g.MarginX := 16
    g.MarginY := 12

    g.AddText("cFFFFFF", "Palette A:")
    g.listA := g.AddDropDownList("w220 y+4", palNames)
    g.listA.Value := activeIndex

    g.AddText("cFFFFFF y+10", "Palette B:")
    g.listB := g.AddDropDownList("w220 y+4", palNames)
    if palNames.Length > 1
        g.listB.Value := 2
    else
        g.listB.Value := 1

    g.AddButton("w220 h24 y+10", "Compare").OnEvent("Click", (*) => DoPaletteCompare(app, g))
    g.AddButton("w220 h24 y+5", "Cancel").OnEvent("Click", (*) => g.Destroy())

    g.Show("AutoSize Center")
}

DoPaletteCompare(app, g) {
    nameA := g.listA.Text
    nameB := g.listB.Text

    pA := app.palettes[nameA]
    pB := app.palettes[nameB]

    if pA.colors.Length = 0
        LoadPaletteFromFile(pA)
    if pB.colors.Length = 0
        LoadPaletteFromFile(pB)

    if !pA.colors.Length && !pB.colors.Length {
        ShowToast(app, "Both palettes empty")
        return
    }

    setA := Map(), setB := Map()
    for item in pA.colors
        setA[item.hex] := item
    for item in pB.colors
        setB[item.hex] := item

    common := [], onlyA := [], onlyB := []

    for hex in setA
        (setB.Has(hex)) ? common.Push(hex) : onlyA.Push(hex)

    for hex in setB
        if !setA.Has(hex)
            onlyB.Push(hex)

    ; ================= GUI =================
    cg := Gui("+AlwaysOnTop +ToolWindow +Border", nameA " vs " nameB)
    cg.BackColor := "2B2D31"
    cg.SetFont("s9", "Segoe UI")
    cg.MarginX := 10
    cg.MarginY := 8

    ; ================= PREVIEW (COMPACT ROW) =================
    cg.previewSwatch := cg.AddProgress("xm w50 h32 Background808080")

    cg.previewHex  := cg.AddText("x+6 yp-2 cFFFFFF w90", "#000000")
    cg.previewName := cg.AddText("x+13 yp cFFFFFF w120", "-")
    cg.infoSection := cg.AddText("x+2 yp cFFFFFF w120", "From: -")
    cg.previewRgb  := cg.AddText("xm+56 yp+18 cAAAAAA w90", "RGB: 0,0,0")
    cg.previewRole := cg.AddText("x+13 yp cFFFFFF w100", "-")

    ; ================= SUMMARY (ONE LINE) =================
    cg.summaryText := cg.AddText("xm y+6 cAAAAAA",
        "Common " common.Length
        "   |   A " onlyA.Length
        "   |   B " onlyB.Length
    )

    ; ================= COMMON =================
    cg.commonList := cg.AddListView("xm y+4 w460 h80 -Multi", ["HEX", "Name", "Role", "A", "B"])
    cg.commonList.SetFont("s8", "Consolas")

    cg.commonList.ModifyCol(1, 65)
    cg.commonList.ModifyCol(2, 110)
    cg.commonList.ModifyCol(3, 70)
    cg.commonList.ModifyCol(4, 90)
    cg.commonList.ModifyCol(5, 90)

    for hex in common {
        a := setA[hex], b := setB[hex]
        cg.commonList.Add("", "#" hex, a.name, a.role, b.name)
    }

    ; ================= SIDE LISTS =================
    cg.AddText("xm y+4 cFF6B6B", "(A) " nameA)
    cg.AddText("xp+231 yp c6B9FFF", "(B) " nameB)
    cg.onlyAList := cg.AddListView("xm y+2 w225 h120 -Multi", ["HEX", "Name", "Role"])
    cg.onlyAList.SetFont("s8", "Consolas")

    cg.onlyAList.ModifyCol(1, 65)
    cg.onlyAList.ModifyCol(2, 105)
    cg.onlyAList.ModifyCol(3, 55)

    for hex in onlyA {
        item := setA[hex]
        cg.onlyAList.Add("", "#" hex, item.name, item.role)
    }

    cg.onlyBList := cg.AddListView("x+6 yp w225 h120 -Multi", ["HEX", "Name", "Role"])
    cg.onlyBList.SetFont("s8", "Consolas")

    cg.onlyBList.ModifyCol(1, 65)
    cg.onlyBList.ModifyCol(2, 105)
    cg.onlyBList.ModifyCol(3, 55)

    for hex in onlyB {
        item := setB[hex]
        cg.onlyBList.Add("", "#" hex, item.name, item.role)
    }

    ; ================= EVENTS =================
    cg.commonList.OnEvent("Click", (*) => UpdateComparePreview(cg, cg.commonList, setA, setB, nameA, nameB))
    cg.onlyAList.OnEvent("Click", (*) => UpdateComparePreview(cg, cg.onlyAList, setA, setB, nameA, nameB))
    cg.onlyBList.OnEvent("Click", (*) => UpdateComparePreview(cg, cg.onlyBList, setA, setB, nameA, nameB))

    cg.selectedHex := ""
    cg.selectedSource := ""

    cg.setA := setA
    cg.setB := setB
    cg.onlyA := onlyA
    cg.onlyB := onlyB

    cg.targetA := nameA
    cg.targetB := nameB
    cg.sourceNameA := nameA
    cg.sourceNameB := nameB

    ; ================= BUTTONS (TIGHT ROW) =================
    cg.btnMove  := cg.AddButton("xm y+6 w80 h26", "Move→A")
    cg.btnDup   := cg.AddButton("x+5 yp w80 h26", "Duplicate")
    cg.btnMerge := cg.AddButton("x+5 yp w80 h26", "Merge")
    cg.btnDel   := cg.AddButton("x+5 yp w80 h26", "Delete")
    cg.AddButton("x+10 yp w70 h26", "Close").OnEvent("Click", (*) => cg.Destroy())

    cg.btnMove.OnEvent("Click", (*) => UpdateCompareButtonState(app, cg))
    cg.btnDup.OnEvent("Click", (*) => UpdateDuplicateButtonState(app, cg))
    cg.btnMerge.OnEvent("Click", (*) => UpdateMergeButtonState(app, cg))
    cg.btnDel.OnEvent("Click", (*) => UpdateDeleteButtonState(app, cg))

    cg.Show("AutoSize Center")
    g.Destroy()
}

CopyHexList(app, hexList) {
    if hexList.Length = 0 {
        ShowToast(app, "Nothing to copy")
        return
    }
    text := ""
    for hex in hexList
        text .= "#" hex "`n"
    A_Clipboard := Trim(text)
    ShowToast(app, "Copied " hexList.Length " HEX values")
}

CopyHexRgbList(app, hexList, set) {
    if hexList.Length = 0 {
        ShowToast(app, "Nothing to copy")
        return
    }
    text := ""
    for hex in hexList {
        item := set[hex]
        rgb := item.rgb ? item.rgb : "0,0,0"
        text .= "#" hex " (" rgb ")`n"
    }
    A_Clipboard := Trim(text)
    ShowToast(app, "Copied " hexList.Length " HEX+RGB values")
}

DoDuplicateToPalette(app, cg, targetName, sourceSet, sourceList, onlyList) {
    targetPal := app.palettes[targetName]
    if !targetPal {
        ShowToast(app, "Target palette not found")
        return
    }

    if !cg.selectedHex {
        ShowToast(app, "Select a color first")
        return
    }

    hex := cg.selectedHex
    if !sourceSet.Has(hex) || targetPal.map.Has(hex) {
        ShowToast(app, "Color already exists or not found")
        return
    }

    item := sourceSet[hex]
    newItem := { id: item.id, hex: item.hex, rgb: item.rgb, name: item.name, role: item.role, pinned: item.pinned, pinOrder: item.pinOrder, section: item.section }
    targetPal.colors.Push(newItem)
    targetPal.map[hex] := newItem

    SavePalette(targetPal, app.version)
    ShowToast(app, "Duplicated #" hex " to " targetName)
    RefreshPaletteManager(app, app.paletteGui)
}

RefreshPaletteManager(app, g) {
    SaveSectionPanelPositions(app)
    SaveHistory(app)

    LoadHistory(app)

    g.inputMax.Value := app.activePalette.historyMax
    g.inputCols.Value := app.activePalette.maxCols
    if g.HasOwnProp("btnGuiMode")
        g.btnGuiMode.Text := GetGuiModeLabel(app)
    if g.HasOwnProp("btnLayout")
        g.btnLayout.Text := GetLayoutLabel(app)
    if g.HasOwnProp("noteEdit")
        g.noteEdit.Value := GetPaletteNote(app.activePalette)


    RefreshPaletteList(app, g)

    if app.historyVisible {
        app.ui.generation++
        InitHistoryGui(app)
        RebuildUI(app)
        Emit(app, "history_changed")
    }

    ShowToast(app, "🔄 Palette refreshed")
}

SavePaletteNoteInline(app, g) {
    val := g.noteEdit.Value
    SetPaletteNote(app, val)
    RefreshPaletteList(app, g)
}
ClearPaletteNote(app, g) {
    g.noteEdit.Value := ""
    SetPaletteNote(app, "")
    ShowToast(app, "🧹 Note cleared")
}
OpenPaletteTemplateDialog(app) {
    templates := GetPaletteTemplates()
    names := []
    for key in templates
        names.Push(key)

    if names.Length = 0 {
        ShowToast(app, "No templates available")
        return
    }

    g := Gui("+AlwaysOnTop +ToolWindow +Border", "Palette Templates")
    g.BackColor := "323338"
    g.SetFont("s9", "Consolas")
    g.MarginX := 16
    g.MarginY := 12

    rowY := 10
    rowH := 28
    gap := 6

    ; ===== Title =====
    g.AddText("x10 y" rowY " cFFFFFF", "Choose a template:")
    rowY += 20

    ; ===== Template row =====
    g.tplList := g.AddDropDownList("x10 y" rowY " w240", names)
    g.tplList.Value := 1

    g.btnSave := g.AddButton("x260 y" rowY " w30 h24", "💾")
    g.btnDelete := g.AddButton("x295 y" rowY " w30 h24", "🗑")

    rowY += rowH + gap

    ; ===== Mode =====
    g.AddText("x10 y" rowY " cAAAAAA", "Import mode:")
    rowY += 18

    g.modeList := g.AddDropDownList("x10 y" rowY " w315", [
        "New Palette",
        "Insert to Selected",
        "Replace Selected"
    ])

    rowY += rowH + gap

    ; ===== Preview =====
    g.previewLabel := g.AddText("x10 y" rowY " w315 cAAAAAA", "Preview: 0 colors")

    rowY += 25

    ; ===== Buttons =====
    g.btnApply := g.AddButton("x10 y" rowY " w150 h28", "Apply")
    g.btnCancel := g.AddButton("x175 y" rowY " w150 h28", "Cancel")

    ; ===== Events =====
    g.btnApply.OnEvent("Click", (*) => CreatePaletteFromTemplate(app, g))
    g.btnCancel.OnEvent("Click", (*) => g.Destroy())

    g.btnSave.OnEvent("Click", (*) => SaveCurrentPaletteAsTemplate(app, g))
    g.btnDelete.OnEvent("Click", (*) => DeleteTemplateDialog(app, g, templates))

    g.tplList.OnEvent("Change", (*) => UpdateTemplatePreview(g, templates))

    ; ===== Initial preview =====
    selName := g.tplList.Text
    if selName != "" && templates.Has(selName) {
        tpl := templates[selName]
        g.previewLabel.Text := "Preview: " GetTemplateColorCount(tpl) " colors"
    } else {
        g.previewLabel.Text := "Preview: 0 colors"
    }

    g.Show("AutoSize Center")
}
UpdateTemplatePreview(g, templates) {
    selName := g.tplList.Text
    if selName = "" || !templates.Has(selName) {
        g.previewLabel.Text := "Preview: 0 colors"
        return
    }
    tpl := templates[selName]
    count := GetTemplateColorCount(tpl)
    g.previewLabel.Text := "Preview: " count " colors"
}

GetTemplateColorCount(tpl) {
    count := 0
    if tpl.Has("sections") {
        for sectionName, sectionData in tpl["sections"] {
            if sectionData.Has("items") {
                count += sectionData["items"].Count
            }
        }
    } else if tpl.Has("items") {
        count := tpl["items"].Count
    }
    return count
}

CreatePaletteFromTemplate(app, g) {
    selName := g.tplList.Text
    mode := g.modeList.Text
    templates := GetPaletteTemplates()
    tpl := templates[selName]
    g.Destroy()

    switch mode {
        case "New Palette":
            CreateNewPaletteFromTemplate(app, selName, tpl)
        case "Insert to Selected":
            InsertTemplateToPalette(app, tpl)
        case "Replace Selected":
            ReplacePaletteWithTemplate(app, tpl)
    }
}

CreateNewPaletteFromTemplate(app, selName, tpl) {
    AskNewPaletteName(app, selName, tpl)
}

AskNewPaletteName(app, selName, tpl) {
    g := Gui("+AlwaysOnTop +ToolWindow", "New Palette")
    g.BackColor := "323338"
    g.SetFont("s9", "Consolas")
    g.MarginX := 16
    g.MarginY := 12

    g.AddText("cFFFFFF", "Palette name:")
    g.AddEdit("w280 y+4", selName).Name := "nameEdit"

    g.AddButton("w130 h28 y+15", "Create").OnEvent("Click", (*) => DoCreatePaletteFromTemplate(app, g, tpl))
    g.AddButton("w130 h28 x+10", "Cancel").OnEvent("Click", (*) => g.Destroy())

    g.Show("AutoSize Center")
}

DoCreatePaletteFromTemplate(app, inputGui, tpl) {
    nameEdit := inputGui["nameEdit"]
    newName := Trim(nameEdit.Value)
    if newName = "" {
        ShowToast(app, "Name cannot be empty")
        return
    }
    newFile := "color\" newName ".txt"

    p := CreatePalette(newName, newFile)

    AddTemplateItemsToPalette(p, tpl)

    Normalize(p)
    p.guiMode := "docked"
    app.palettes[newName] := p
    app.paletteOrder.Push(newName)
    SavePalette(p, app.version)
    if SafeGetGuiHwnd(app.paletteGui) {
        RefreshPaletteManager(app, app.paletteGui)
    }
    SwitchPalette(app, newName)
    inputGui.Destroy()
    ShowToast(app, "Created palette: " newName)
}

InsertTemplateToPalette(app, tpl) {
    p := app.activePalette

    AddTemplateItemsToPalette(p, tpl, "Base")

    Normalize(p)
    SavePalette(p, app.version)
    if SafeGetGuiHwnd(app.paletteGui) {
        RefreshPaletteManager(app, app.paletteGui)
    }
    SwitchPalette(app, p.name)
    ShowToast(app, "Inserted template into: " p.name)
}

ReplacePaletteWithTemplate(app, tpl) {
    p := app.activePalette
    p.colors := []
    p.map := Map()
    p.sections := []

    AddTemplateItemsToPalette(p, tpl)

    Normalize(p)
    SavePalette(p, app.version)
    if SafeGetGuiHwnd(app.paletteGui) {
        RefreshPaletteManager(app, app.paletteGui)
    }
    SwitchPalette(app, p.name)
    ShowToast(app, "Replaced " p.name " with template")
}

AddTemplateItemsToPalette(p, tpl, defaultSection := "") {
    if tpl.Has("sections") && IsObject(tpl["sections"]) {
        for sectionName, sectionData in tpl["sections"] {
            if !IsObject(sectionData) || !sectionData.Has("items")
                continue
            for name, data in sectionData["items"] {
                AddTemplateItemToPalette(p, name, data, sectionName)
            }
        }
    } else if tpl.Has("items") && IsObject(tpl["items"]) {
        useUniqueSection := tpl.Has("section") && tpl["section"] != ""
        for name, data in tpl["items"] {
            AddTemplateItemToPalette(p, name, data, useUniqueSection ? tpl["section"] : defaultSection)
        }
    }
}

AddTemplateItemToPalette(p, name, data, section) {
    parts := StrSplit(data, "|")
    if parts.Length < 3
        return
    hex := parts[1]
    rgb := parts[2]
    role := parts[3]
    paint := parts.Length >= 4 ? parts[4] : "P"
    if paint = ""
        paint := "P"
    item := CreateItem(hex, rgb, name, role)
    item.pinned := 0
    if section = ""
        section := "Imported"
    item.section := section
    item.paint := paint
    AddColor(p, item)
    AddSectionName(p, section)
}

CheckClipboardForColor(app) {
    clip := A_Clipboard
    if clip = ""
        return ""

    hexes := []
    pattern := "i)(?:^|[^\dA-Fa-f])([A-Fa-f0-9]{6})(?![A-Fa-f0-9])"
    pos := 0
    while pos := RegexMatch(clip, pattern, &m, pos + 1) {
        hex := m[1]
        hex := StrUpper(hex)
        if !hexes.Has(hex)
            hexes.Push(hex)
    }

    if hexes.Length > 0 {
        return hexes[1]
    }
    return ""
}

PasteColorFromClipboard(app) {
    hex := CheckClipboardForColor(app)
    if hex = "" {
        ShowToast(app, "No HEX color in clipboard")
        return
    }

    p := app.activePalette
    section := GetSelectedSectionName(p)
    if section = ""
        section := "Clipboard"

    if p.map.Has(hex) {
        ShowToast(app, "#" hex " already in palette")
        return
    }

    rgb := HexToRGB(hex)
    name := GetColorName(hex)
    item := CreateItem(hex, rgb.r "," rgb.g "," rgb.b, name, "Base")
    item.section := section
    item.pinned := 0
    AddColor(p, item)
    AddSectionName(p, section)
    Normalize(p)
    SaveHistory(app)
    RebuildUI(app)
    ShowToast(app, "Added #" hex " (" name ")")
}

SaveCurrentPaletteAsTemplate(app, g) {
    p := app.activePalette
    if p.colors.Length = 0 {
        ShowToast(app, "Palette is empty")
        return
    }

    inputGui := Gui("+AlwaysOnTop +ToolWindow +Border", "Save as Template")
    inputGui.BackColor := "323338"
    inputGui.SetFont("s9", "Consolas")
    inputGui.MarginX := 16
    inputGui.MarginY := 12

    inputGui.AddText("cFFFFFF", "Template name:")
    inputGui.AddEdit("w280 y+4", p.name).Name := "nameEdit"
    
    inputGui.AddButton("w130 h28 y+15", "Save").OnEvent("Click", (*) => DoSaveTemplate(app, g, inputGui))
    inputGui.AddButton("w130 h28 x+10", "Cancel").OnEvent("Click", (*) => inputGui.Destroy())

    inputGui.Show("AutoSize Center")
}

DoSaveTemplate(app, g, inputGui) {
    nameEdit := inputGui["nameEdit"]
    tplName := Trim(nameEdit.Value)
    if tplName = "" {
        ShowToast(app, "Name cannot be empty")
        return
    }
    p := app.activePalette
    SavePaletteAsTemplateFile(app, tplName, p)
    inputGui.Destroy()
    ShowToast(app, "Saved template: " tplName)
    RefreshTemplateDialog(app, g)
}

SaveTemplateButton_Click(*) {
    global App
    if !IsObject(App) || !App.HasOwnProp("activePalette")
        return

    activePaletteGuiHwnd := SafeGetGuiHwnd(App.paletteGui)
    if !activePaletteGuiHwnd
        return

    for gui in App {
        if SafeGetGuiHwnd(gui) = activePaletteGuiHwnd {
            nameEdit := gui["nameEdit"]
            p := App.activePalette
            tplName := Trim(nameEdit.Value)
            if tplName = "" {
                ShowToast(App, "Name cannot be empty")
                return
            }
            SavePaletteAsTemplateFile(App, tplName, p)
            gui.Destroy()
            ShowToast(App, "Saved template: " tplName)
            OpenPaletteTemplateDialog(App)
            return
        }
    }
}

DeleteTemplateDialog(app, g, templates) {
    selName := g.tplList.Text
    if selName = "" {
        ShowToast(app, "Select a template first")
        return
    }

    tpl := templates[selName]
    isBuiltIn := tpl.Has("isBuiltIn") && tpl["isBuiltIn"]

    if isBuiltIn {
        ShowToast(app, "Cannot delete built-in templates")
        return
    }

    confirmGui := Gui("+AlwaysOnTop +ToolWindow +Border", "Delete Template")
    confirmGui.BackColor := "323338"
    confirmGui.SetFont("s9", "Consolas")
    confirmGui.MarginX := 16
    confirmGui.MarginY := 12

    confirmGui.AddText("cFFFFFF w280", "Delete template: " selName "?")
    confirmGui.AddButton("w130 h28 y+10", "Delete").OnEvent("Click", (*) => DoDeleteTemplate(app, g, confirmGui, selName))
    confirmGui.AddButton("w130 h28 x+10", "Cancel").OnEvent("Click", (*) => confirmGui.Destroy())

    confirmGui.Show("AutoSize Center")
}

DoDeleteTemplate(app, g, confirmGui, selName) {
    DeleteTemplateFile(selName)
    confirmGui.Destroy()
    RefreshTemplateDialog(app, g)
    ShowToast(app, "Deleted template: " selName)
}

DeleteTemplateFile(tplName) {
    tplPath := A_ScriptDir "\templates\" tplName ".txt"
    if FileExist(tplPath)
        FileDelete(tplPath)
}

SavePaletteAsTemplateFile(app, tplName, p) {
    tplDir := A_ScriptDir "\templates"
    DirCreate(tplDir)
    tplPath := tplDir "\" tplName ".txt"

    lines := []
    lines.Push("#TEMPLATE|" tplName)

    sectionMap := Map()
    for item in p.colors {
        sec := item.HasOwnProp("section") && item.section != "" ? item.section : "Default"
        if !sectionMap.Has(sec) {
            sectionMap[sec] := []
        }
        sectionMap[sec].Push(item)
    }

    for secName, items in sectionMap {
        lines.Push("#SECTION|" secName)
        for item in items {
            paintVal := item.HasOwnProp("paint") ? item.paint : ""
            lines.Push("#COLOR|" item.hex "|" item.rgb "|" item.name "|" item.role "|" secName "|" paintVal)
        }
    }

    content := ""
    for l in lines {
        content .= l "`n"
    }
    FileAppend(content, tplPath, "UTF-8")
}

RefreshTemplateDialog(app, g) {
    templates := GetPaletteTemplates()
    names := []
    for key in templates
        names.Push(key)

    g.tplList.Delete()
    for name in names {
        g.tplList.Add([name])
    }
    if names.Length > 0
        g.tplList.Value := 1
}

GetPaletteTemplates() {
    builtIn := GetBuiltInTemplates()
    userTemplates := LoadUserTemplates()
    allTemplates := Map()
    for name, tpl in builtIn {
        allTemplates[name] := tpl
    }
    for name, tpl in userTemplates {
        allTemplates[name] := tpl
    }
    return allTemplates
}

LoadUserTemplates() {
    tplDir := A_ScriptDir "\templates"
    if !DirExist(tplDir)
        return Map()

    templates := Map()
    for f in DirContents(tplDir, "*.txt") {
        fullPath := tplDir "\" f
        lines := StrSplit(FileRead(fullPath), "`n")
        if lines.Length < 2
            continue

        headerLine := lines[1]
        if !InStr(headerLine, "#TEMPLATE")
            continue

        parts := StrSplit(headerLine, "|")
        if parts.Length < 2
            continue

        tplName := Trim(parts[2])
        tpl := Map("section", "", "sections", Map(), "items", Map())
        currentSection := ""
        for i, line in lines {
            if i = 1
                continue
            if InStr(line, "#SECTION|") {
                sectionParts := StrSplit(line, "|")
                if sectionParts.Length >= 2 {
                    currentSection := Trim(sectionParts[2])
                    if currentSection != "" {
                        tpl["sections"][currentSection] := Map("items", Map())
                    }
                }
            }
            if InStr(line, "#COLOR|") {
                cparts := StrSplit(line, "|")
                if cparts.Length >= 6 {
                    paintVal := cparts.Length >= 7 ? cparts[7] : ""
                    if paintVal = ""
                        paintVal := "P"
                    colorData := cparts[2] "|" cparts[4] "|" cparts[5] "|" paintVal
                    colorName := cparts[3]
                    sectionName := cparts.Length >= 6 ? cparts[6] : "Default"
                    if currentSection != "" && tpl["sections"].Has(currentSection) {
                        tpl["sections"][currentSection]["items"][colorName] := colorData
                    } else {
                        if !tpl["items"].Has(colorName)
                            tpl["items"][colorName] := colorData
                        if tpl["section"] = ""
                            tpl["section"] := sectionName
                    }
                }
            }
        }
        templates[tplName] := tpl
    }
    return templates
}

DirContents(dir, pattern := "*") {
    result := []
    patternPath := dir "\" pattern
    Loop Files, patternPath, "F" {
        result.Push(A_LoopFileName)
    }
    return result
}

OpenColorHarmonyDialog(app) {
    p := app.activePalette
    colors := []
    for item in p.colors {
        colors.Push(item.hex)
    }
    if colors.Length = 0 {
        ShowToast(app, "No colors in palette")
        return
    }

    g := Gui("+AlwaysOnTop +ToolWindow +Border", "Color Harmony Suggestions")
    g.BackColor := "323338"
    g.SetFont("s9", "Consolas")
    g.MarginX := 14
    g.MarginY := 12
    rowY := 10
    gap := 8

    harmonyTypes := ["Complementary", "Analogous", "Triadic", "Split-Complementary", "Tetradic"]

    g.AddText("x10 y" rowY " cAAAAAA", "Base Color")
    rowY += 18

    colorList := []
    for hex in colors
        colorList.Push("#" hex)

    g.colorDrop := g.AddDropDownList("x10 y" rowY " w160", colorList)
    g.colorDrop.Value := 1

    g.targetPreview := g.AddProgress("x175 y" rowY " w90 h24")
    g.targetPreview.Opt("Background" colors[1])

    g.colorDrop.OnEvent("Change", (*) => UpdateColorDropPreview(g, colors))

    rowY += 32

    ; =========================
    ; HARMONY TYPE SECTION
    ; =========================
    g.AddText("x10 y" rowY " cAAAAAA", "Harmony Type")
    rowY += 18

    g.harmonyDrop := g.AddDropDownList("x10 y" rowY " w255", harmonyTypes)
    g.harmonyDrop.Value := 1

    rowY += 30

    ; =========================
    ; PREVIEW SECTION
    ; =========================
    g.AddText("x10 y" rowY " cAAAAAA", "Preview")
    rowY += 18

    g.previewLabel := g.AddText("x10 y" rowY " w255 cFFFFFF", "Generating harmony colors...")
    rowY += 30

    ; =========================
    ; ACTION BAR
    ; =========================
    g.btnApply := g.AddButton("x10 y" rowY " w120 h28", "✨ Apply")
    g.btnClose := g.AddButton("x140 y" rowY " w120 h28", "✖ Close")

    ; =========================
    ; EVENTS
    ; =========================
    g.btnApply.OnEvent("Click", (*) => ApplyColorHarmony(app, g))
    g.btnClose.OnEvent("Click", (*) => g.Destroy())

    g.colorDrop.OnEvent("Change", (*) => UpdateColorDropPreview(g, colors))
    g.harmonyDrop.OnEvent("Change", (*) => UpdateHarmonyPreview(g))

    ; =========================
    ; INITIAL STATE
    ; =========================
    UpdateHarmonyPreview(g)

    g.Show("AutoSize Center")
}
UpdateColorDropPreview(g, colors) {
    dropText := g.colorDrop.Text
    if !dropText || dropText = ""
        return
    baseHex := Trim(StrReplace(dropText, "#"))
    if StrLen(baseHex) = 6
        try g.targetPreview.Opt("Background" baseHex)
}

UpdateHarmonyPreview(g) {
    dropText := g.colorDrop.Text
    if !dropText || dropText = "" {
        g.previewLabel.Text := "Preview: 0 colors"
        return
    }
    baseHex := Trim(StrReplace(dropText, "#"))
    if StrLen(baseHex) != 6 {
        g.previewLabel.Text := "Preview: Invalid color"
        return
    }
    try g.targetPreview.Opt("Background" baseHex)
    harmonyType := g.harmonyDrop.Text
    harmonyColors := CalculateHarmony(baseHex, harmonyType)
    g.previewLabel.Text := "Preview: " harmonyColors.Length " colors"
}

ApplyColorHarmony(app, g) {
    baseHex := Trim(StrReplace(g.colorDrop.Text, "#"))
    harmonyType := g.harmonyDrop.Text
    harmonyColors := CalculateHarmony(baseHex, harmonyType)

    p := app.activePalette
    section := "Harmony"

    for hex in harmonyColors {
        if p.map.Has(hex)
            continue
        rgb := HexToRGB(hex)
        name := GetColorName(hex)
        item := CreateItem(hex, rgb.r "," rgb.g "," rgb.b, name, "Base")
        item.section := section
        item.pinned := 0
        AddColor(p, item)
        AddSectionName(p, section)
    }

    Normalize(p)
    SavePalette(p, app.version)
    g.Destroy()
    ShowToast(app, "Added harmony colors to: " section)
    RefreshPaletteManager(app, app.paletteGui)
    SwitchPalette(app, p.name)
}

OpenColorBlindDialog(app) {
    p := app.activePalette
    colors := []
    for item in p.colors {
        colors.Push(item.hex)
    }
    if colors.Length = 0 {
        ShowToast(app, "No colors in palette")
        return
    }

    cbTypes := ["Protanopia (Red-blind)", "Deuteranopia (Green-blind)", "Tritanopia (Blue-blind)", "Achromatopsia (Monochrome)"]
    g := Gui("+AlwaysOnTop +ToolWindow +Border", "Color Blindness Preview")
    g.BackColor := "323338"
    g.SetFont("s9", "Consolas")
    g.MarginX := 16
    g.MarginY := 12
    rowY := 10
    gap := 8

    g.AddText("x10 y" rowY " cAAAAAA", "Simulation Type")
    rowY += 18
    g.cbDrop := g.AddDropDownList("x10 y" rowY " w230", cbTypes)
    g.cbDrop.Value := 1
    rowY += 28
    g.previewLabel := g.AddText("x10 y" rowY " cFFFFFF", "Preview: " colors.Length " colors")
    rowY += 26
    g.AddText("x10 y" rowY " cAAAAAA", "Actions")
    rowY += 18
    g.btnApply := g.AddButton("x10 y" rowY " w110 h28", "✨ Apply")
    g.btnClose := g.AddButton("x130 y" rowY " w110 h28", "Close")
    g.btnClose.OnEvent("Click", (*) => g.Destroy())
    g.btnApply.OnEvent("Click", (*) => AddColorBlindColors(app, g, colors))
    g.cbDrop.OnEvent("Change", (*) => UpdateColorBlindPreview(g, colors, g.cbDrop.Text))

    g.previewStartY := rowY + 40

    UpdateColorBlindPreview(g, colors, g.cbDrop.Text)

    g.Show("AutoSize Center")
}
ColorBlindApplyColors(app, g, colors) {

    g.AddText("cFFFFFF y+10", "Preview (" colors.Length " colors):")
    g.previewList := g.AddListView("w500 h200 -Multi", ["Original", "Simulated", "Name"])
    g.previewList.SetFont("s8", "Consolas")
    totalW := 500
    hexW := 70
    remaining := totalW - hexW - 20
    each := Floor(remaining / 2)
    g.previewList.ModifyCol(1, hexW)
    Loop 2
        g.previewList.ModifyCol(A_Index + 1, each)

    UpdateColorBlindPreview(g, colors, "Protanopia")

    g.cbDrop.OnEvent("Change", (*) => UpdateColorBlindPreview(g, colors, g.cbDrop.Text))

    g.AddButton("w150 h28 y+10", "Add Simulated").OnEvent("Click", (*) => AddColorBlindColors(app, g, colors))
    g.AddButton("w150 h28 x+10", "Close").OnEvent("Click", (*) => g.Destroy())

    g.Show("AutoSize Center")
}

UpdateColorBlindPreview(g, colors, cbType) {
    if !colors || colors.Length = 0 {
        g.previewLabel.Text := "Preview: 0 colors"
        return
    }

    ; update main preview (top)
    firstColor := colors[1]
    if InStr(firstColor, "|")
        firstColor := StrSplit(firstColor, "|")[1]

    simHex := SimulateColorBlindness(firstColor, cbType)
    try g.targetPreview.Opt("Background" simHex)

    ; 🔥 new visual renderer
    RenderColorBlindPreview(g, colors, cbType)
}

AddColorBlindColors(app, g, colors) {
    cbType := g.cbDrop.Text
    p := app.activePalette
    section := "ColorBlind"

    for hexItem in colors {
        simHex := SimulateColorBlindness(hexItem, cbType)
        if p.map.Has(simHex)
            continue
        rgb := HexToRGB(simHex)
        name := "CB " simHex
        item := CreateItem(simHex, rgb.r "," rgb.g "," rgb.b, name, "Base")
        item.section := section
        item.pinned := 0
        AddColor(p, item)
        AddSectionName(p, section)
    }

    Normalize(p)
    SavePalette(p, app.version)
    g.Destroy()
    ShowToast(app, "Added colorblind simulation colors")
    RefreshPaletteManager(app, app.paletteGui)
    SwitchPalette(app, p.name)
}
RenderColorBlindPreview(g, colors, cbType) {
    ; clear old preview
    if g.HasOwnProp("previewCtrls") {
        for ctrl in g.previewCtrls
            try ctrl.Destroy()
    }
    g.previewCtrls := []

    startY := g.previewStartY
    startX := 10
    boxW := 50
    boxH := 20
    gapY := 6

    for i, hex in colors {
        cleanHex := InStr(hex, "|") ? StrSplit(hex, "|")[1] : hex
        simHex := SimulateColorBlindness(cleanHex, cbType)

        y := startY + (i-1)*(boxH + gapY)

        ; ORIGINAL
        c1 := g.AddText("x" startX " y" y " w" boxW " h" boxH " Background" cleanHex " Border")

        ; SIMULATED
        c2 := g.AddText("x" (startX + boxW + 7) " y" y " w" boxW " h" boxH " Background" simHex " Border")

        ; HEX LABEL (optional but useful)
        t := g.AddText("x" (startX + boxW*2 + 15) " y" y " w120 h" boxH " cAAAAAA"
            , "#" cleanHex " → #" simHex)

        g.previewCtrls.Push(c1)
        g.previewCtrls.Push(c2)
        g.previewCtrls.Push(t)

        if i > 15  ; limit for performance
            break
    }

    g.previewLabel.Text := "Preview: " colors.Length " colors"
}
GetLuminance(hex) {
    r := Integer("0x" SubStr(hex, 1, 2)) / 255
    g := Integer("0x" SubStr(hex, 3, 2)) / 255
    b := Integer("0x" SubStr(hex, 5, 2)) / 255

    r := (r <= 0.03928) ? r / 12.92 : ((r + 0.055) / 1.055) ** 2.4
    g := (g <= 0.03928) ? g / 12.92 : ((g + 0.055) / 1.055) ** 2.4
    b := (b <= 0.03928) ? b / 12.92 : ((b + 0.055) / 1.055) ** 2.4

    return 0.2126 * r + 0.7152 * g + 0.0722 * b
}

Range(start, end) {
    result := []
    i := start
    while i <= end {
        result.Push(i)
        i += 1
    }
    return result
}

StrJoin(arr, sep) {
    text := ""
    for i, v in arr {
        text .= (i > 1 ? sep : "") v
    }
    return text
}

MergeColorsToPalette(app, cg, targetName, sourceSet, srcSet, moveList) {
    targetPal := app.palettes[targetName]
    if !targetPal {
        ShowToast(app, "Target palette not found")
        return
    }

    added := 0
    for hex in moveList {
        if !srcSet.Has(hex) {
            item := sourceSet[hex]
            newItem := { id: item.id, hex: item.hex, rgb: item.rgb, name: item.name, role: item.role, pinned: item.pinned, pinOrder: item.pinOrder, section: item.section }
            targetPal.colors.Push(newItem)
            srcSet[hex] := newItem
            added += 1
        }
    }

    SavePalette(targetPal, app.version)
    ShowToast(app, "Added " added " colors to " targetName)
    cg.Destroy()

    if app.mainGui
        RefreshPaletteManager(app, app.paletteGui)
}

DoMoveColors(app, cg, targetName, moveList, srcSet) {
    targetPal := app.palettes[targetName]
    if !targetPal {
        ShowToast(app, "Target palette not found")
        return
    }

    added := 0
    for hex in moveList {
        item := srcSet[hex]
        newItem := { id: item.id, hex: item.hex, rgb: item.rgb, name: item.name, role: item.role, pinned: item.pinned, pinOrder: item.pinOrder, section: item.section }
        targetPal.colors.Push(newItem)
        added += 1
    }

    SavePalette(targetPal, app.version)
    ShowToast(app, "Moved " added " colors to " targetName)

    if IsObject(cg) {
        try cg.Destroy()
    }

if app.HasOwnProp("mainGui") && app.mainGui {
        RefreshPaletteManager(app, app.paletteGui)
    }
}

RefreshCompareLists(app, cg) {
    nameA := cg.sourceNameA
    nameB := cg.sourceNameB
    pA := app.palettes[nameA]
    pB := app.palettes[nameB]

    if pA.colors.Length = 0 {
        LoadPaletteFromFile(pA)
    }
    if pB.colors.Length = 0 {
        LoadPaletteFromFile(pB)
    }

    setA := Map()
    setB := Map()
    for item in pA.colors
        setA[item.hex] := item
    for item in pB.colors
        setB[item.hex] := item

    cg.setA := setA
    cg.setB := setB

    common := []
    onlyA := []
    onlyB := []

    for hex, item in setA {
        if setB.Has(hex)
            common.Push(hex)
        else
            onlyA.Push(hex)
    }
    for hex, item in setB {
        if !setA.Has(hex)
            onlyB.Push(hex)
    }

    cg.commonList.Delete()
    for hex in common {
        itemA := setA[hex]
        itemB := setB[hex]
        cg.commonList.Add("", "#" hex, itemA.name, itemA.role, itemB.name)
    }

    cg.onlyAList.Delete()
    for hex in onlyA {
        item := setA[hex]
        cg.onlyAList.Add("", "#" hex, item.name, item.role)
    }

    cg.onlyBList.Delete()
    for hex in onlyB {
        item := setB[hex]
        cg.onlyBList.Add("", "#" hex, item.name, item.role)
    }

    cg.summaryText.Value := "Common " common.Length "   |   A " onlyA.Length "   |   B " onlyB.Length

    cg.previewSwatch.Opt("Background808080")
    cg.previewHex.Value := "#000000"
    cg.previewRgb.Value := "RGB: 0,0,0"
    cg.previewName.Value := "-"
    cg.previewRole.Value := "-"
    cg.btnMove.Text := "Move→A"
    cg.btnDup.Text := "Duplicate"
    cg.btnMerge.Text := "Merge"
    cg.btnDel.Text := "Delete"
}

UpdateDeleteButtonState(app, cg) {
    src := cg.selectedSource
    hex := cg.selectedHex

    if !hex {
        row := cg.onlyAList.GetNext(0)
        list := cg.onlyAList
        if !row {
            row := cg.onlyBList.GetNext(0)
            list := cg.onlyBList
        }
        if !row {
            row := cg.commonList.GetNext(0)
            list := cg.commonList
        }
        if !row {
            ShowToast(app, "Select a color first")
            return
        }
        hex := SubStr(list.GetText(row, 1), 2)
        src := (list = cg.onlyAList) ? "A" : (list = cg.onlyBList) ? "B" : "common"
    }

    if src = "common" {
        pA := app.palettes[cg.sourceNameA]
        pB := app.palettes[cg.sourceNameB]
        if pA && pB {
            newColorsA := []
            for c in pA.colors {
                if c.hex != hex
                    newColorsA.Push(c)
            }
            pA.colors := newColorsA

            newColorsB := []
            for c in pB.colors {
                if c.hex != hex
                    newColorsB.Push(c)
            }
            pB.colors := newColorsB

            SavePalette(pA, app.version)
            SavePalette(pB, app.version)
            ShowToast(app, "Deleted #" hex " from both palettes")
            RefreshPaletteManager(app, app.paletteGui)
            RefreshCompareLists(app, cg)
        }
    } else if src = "A" {
        pA := app.palettes[cg.sourceNameA]
        if pA {
            newColors := []
            for c in pA.colors {
                if c.hex != hex
                    newColors.Push(c)
            }
            pA.colors := newColors
            SavePalette(pA, app.version)
            ShowToast(app, "Deleted #" hex " from " cg.sourceNameA)
            RefreshPaletteManager(app, app.paletteGui)
            RefreshCompareLists(app, cg)
        }
    } else if src = "B" {
        pB := app.palettes[cg.sourceNameB]
        if pB {
            newColors := []
            for c in pB.colors {
                if c.hex != hex
                    newColors.Push(c)
            }
            pB.colors := newColors
            SavePalette(pB, app.version)
            ShowToast(app, "Deleted #" hex " from " cg.sourceNameB)
            RefreshPaletteManager(app, app.paletteGui)
            RefreshCompareLists(app, cg)
        }
    }
}

DoMoveOneColor(app, cg, targetName, sourceName, sourceSet, hex) {
    targetPal := app.palettes[targetName]
    sourcePal := app.palettes[sourceName]
    if !targetPal || !sourcePal {
        ShowToast(app, "Palette not found")
        return
    }

    item := sourceSet[hex]
    if !item {
        ShowToast(app, "Color not found")
        return
    }

    newItem := { id: item.id, hex: item.hex, rgb: item.rgb, name: item.name, role: item.role, pinned: item.pinned, pinOrder: item.pinOrder, section: item.section }
    targetPal.colors.Push(newItem)

    newColors := []
    for c in sourcePal.colors {
        if c.hex != hex
            newColors.Push(c)
    }
    sourcePal.colors := newColors

    SavePalette(targetPal, app.version)
    SavePalette(sourcePal, app.version)
    ShowToast(app, "Moved #" hex " to " targetName)

    RefreshPaletteManager(app, app.paletteGui)
    RefreshCompareLists(app, cg)
}

DoDuplicateOneColor(app, cg, targetName, sourceSet, hex) {
    targetPal := app.palettes[targetName]
    if !targetPal {
        ShowToast(app, "Target palette not found")
        return
    }

    if targetPal.map.Has(hex) {
        ShowToast(app, "Color already exists in target")
        return
    }

    item := sourceSet[hex]
    if !item {
        ShowToast(app, "Color not found")
        return
    }

    newItem := { id: item.id, hex: item.hex, rgb: item.rgb, name: item.name, role: item.role, pinned: item.pinned, pinOrder: item.pinOrder, section: item.section }
    targetPal.colors.Push(newItem)
    targetPal.map[hex] := newItem
    SavePalette(targetPal, app.version)
    ShowToast(app, "Duplicated #" hex " to " targetName)
    RefreshPaletteManager(app, app.paletteGui)
    RefreshCompareLists(app, cg)
}

UpdateComparePreview(cg, list, setA, setB, nameA, nameB) {
    row := list.GetNext(0)
    if !row {
        cg.previewSwatch.Opt("Background808080")
        cg.previewHex.Value := "#000000"
cg.previewRgb.Value := "RGB: 0,0,0"
        cg.previewName.Value := "-"
        cg.previewRole.Value := "-"
        cg.btnMove.Text := "Move→A"
        cg.btnDup.Text := "Duplicate"
        cg.btnMerge.Text := "Merge"
        cg.btnDel.Text := "Delete"
        cg.selectedSource := ""
        cg.selectedHex := ""
        return
    }

    hex := SubStr(list.GetText(row, 1), 2)
    cg.selectedHex := hex

    if list = cg.commonList {
        cg.selectedSource := "common"
        cg.btnMove.Text := "Move→?"
        cg.btnDup.Text := "Dup→?"
        cg.btnMerge.Text := "Merge all?"
        cg.btnDel.Text := "Del both"
    } else if list = cg.onlyAList {
        cg.selectedSource := "A"
        cg.btnMove.Text := "Move→B"
        cg.btnDup.Text := "Dup→B"
        cg.btnMerge.Text := "Merge all→B"
        cg.btnDel.Text := "Del from A"
    } else if list = cg.onlyBList {
        cg.selectedSource := "B"
        cg.btnMove.Text := "Move→A"
        cg.btnDup.Text := "Dup→A"
        cg.btnMerge.Text := "Merge all→A"
        cg.btnDel.Text := "Del from B"
    }

    if list = cg.commonList {
        cg.infoSection.Value := "From: Both"
    } else if list = cg.onlyAList {
        cg.infoSection.Value := "From: A only"
    } else if list = cg.onlyBList {
        cg.infoSection.Value := "From: B only"
    }

    item := setA.Has(hex) ? setA[hex] : setB[hex]
    if !item {
        cg.previewSwatch.Opt("Background808080")
        cg.previewHex.Value := "#000000"
        cg.previewRgb.Value := "RGB: 0,0,0"
        cg.previewName.Value := "-"
        cg.previewRole.Value := "-"
        return
    }

    rgb := item.rgb ? item.rgb : "0,0,0"
    try cg.previewSwatch.Opt("Background" item.hex)
    cg.previewHex.Value := "#" hex
    cg.previewRgb.Value := "RGB: " rgb
    cg.previewName.Value := item.name
    cg.previewRole.Value := item.role
}

UpdateCompareButtonState(app, cg) {
    src := cg.selectedSource
    hex := cg.selectedHex

    if !hex || src = "common" {
        row := cg.onlyAList.GetNext(0)
        list := cg.onlyAList
        if !row {
            row := cg.onlyBList.GetNext(0)
            list := cg.onlyBList
        }
        if !row {
            ShowToast(app, "Select a color first")
            return
        }
        hex := SubStr(list.GetText(row, 1), 2)
        src := (list = cg.onlyAList) ? "A" : "B"
    }

    if src = "A" {
        DoMoveOneColor(app, cg, cg.targetB, cg.sourceNameA, cg.setA, hex)
    } else if src = "B" {
        DoMoveOneColor(app, cg, cg.targetA, cg.sourceNameB, cg.setB, hex)
    }
}

UpdateDuplicateButtonState(app, cg) {
    src := cg.selectedSource
    hex := cg.selectedHex

    if !hex || src = "common" {
        row := cg.onlyAList.GetNext(0)
        list := cg.onlyAList
        if !row {
            row := cg.onlyBList.GetNext(0)
            list := cg.onlyBList
        }
        if !row {
            ShowToast(app, "Select a color first")
            return
        }
        hex := SubStr(list.GetText(row, 1), 2)
        src := (list = cg.onlyAList) ? "A" : "B"
    }

    if src = "A" {
        DoDuplicateOneColor(app, cg, cg.targetB, cg.setA, hex)
    } else if src = "B" {
        DoDuplicateOneColor(app, cg, cg.targetA, cg.setB, hex)
    }
}

UpdateMergeButtonState(app, cg) {
    src := cg.selectedSource
    hex := cg.selectedHex

    if !hex || src = "common" {
        row := cg.onlyAList.GetNext(0)
        list := cg.onlyAList
        if !row {
            row := cg.onlyBList.GetNext(0)
            list := cg.onlyBList
        }
        if !row {
            ShowToast(app, "Select a color first")
            return
        }
        hex := SubStr(list.GetText(row, 1), 2)
        src := (list = cg.onlyAList) ? "A" : "B"
    }

    if src = "A" {
        targetPal := app.palettes[cg.targetB]
        sourcePal := app.palettes[cg.sourceNameA]
        if targetPal && sourcePal {
            mergedCount := 0
            for item in sourcePal.colors {
                if !targetPal.map.Has(item.hex) {
                    newItem := { id: item.id, hex: item.hex, rgb: item.rgb, name: item.name, role: item.role, pinned: item.pinned, pinOrder: item.pinOrder, section: item.section }
                    targetPal.colors.Push(newItem)
                    targetPal.map[item.hex] := newItem
                    mergedCount++
                }
            }
            if mergedCount > 0 {
                SavePalette(targetPal, app.version)
                if sourcePal.HasOwnProp("file") && FileExist(sourcePal.file) {
                    FileDelete(sourcePal.file)
                }
                app.palettes.Delete(cg.sourceNameA)
                ShowToast(app, "Merged " mergedCount " colors to " cg.targetB " and deleted " cg.sourceNameA)
                RefreshPaletteManager(app, app.paletteGui)
                cg.Destroy()
            } else {
                ShowToast(app, "No new colors to merge")
            }
        }
    } else if src = "B" {
        targetPal := app.palettes[cg.targetA]
        sourcePal := app.palettes[cg.sourceNameB]
        if targetPal && sourcePal {
            mergedCount := 0
            for item in sourcePal.colors {
                if !targetPal.map.Has(item.hex) {
                    newItem := { id: item.id, hex: item.hex, rgb: item.rgb, name: item.name, role: item.role, pinned: item.pinned, pinOrder: item.pinOrder, section: item.section }
                    targetPal.colors.Push(newItem)
                    targetPal.map[item.hex] := newItem
                    mergedCount++
                }
            }
            if mergedCount > 0 {
                SavePalette(targetPal, app.version)
                if sourcePal.HasOwnProp("file") && FileExist(sourcePal.file) {
                    FileDelete(sourcePal.file)
                }
                app.palettes.Delete(cg.sourceNameB)
                ShowToast(app, "Merged " mergedCount " colors to " cg.targetA " and deleted " cg.sourceNameB)
                RefreshPaletteManager(app, app.paletteGui)
                cg.Destroy()
            } else {
                ShowToast(app, "No new colors to merge")
            }
        }
    }
}

DoMergeAndDeletePalette(app, cg, targetName, sourceName, sourceSet, targetSet, onlyList) {
    targetPal := app.palettes[targetName]
    sourcePal := app.palettes[sourceName]
    if !targetPal || !sourcePal {
        ShowToast(app, "Palette not found")
        return
    }

    added := 0
    for hex in onlyList {
        if !targetSet.Has(hex) {
            item := sourceSet[hex]
            newItem := { id: item.id, hex: item.hex, rgb: item.rgb, name: item.name, role: item.role, pinned: item.pinned, pinOrder: item.pinOrder, section: item.section }
            targetPal.colors.Push(newItem)
            added += 1
        }
    }

    FileDelete(sourcePal.file)

    app.palettes.Delete(sourceName)
    for i, name in app.paletteOrder {
        if name = sourceName {
            app.paletteOrder.RemoveAt(i)
            break
        }
    }

    SavePaletteList(app)
    SavePalette(targetPal, app.version)
    ShowToast(app, "Merged " added " colors to " targetName " | Deleted " sourceName)

    cg.Destroy()
    RefreshPaletteManager(app, app.paletteGui)
}
