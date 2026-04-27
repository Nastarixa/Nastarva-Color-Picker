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

    g := Gui("+AlwaysOnTop +Resize +OwnDialogs", "🎨 Nastarva Palette Manager v" app.version)
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
    g := app.paletteGui
    if !IsObject(g)
        return

    p := app.activePalette

    if g.HasOwnProp("inputRoleOrder") {
        roleOrder := ParseRoleOrder(g.inputRoleOrder.Value)
        if (roleOrder.Length > 0)
            p.roleOrder := roleOrder
    }

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

    ShowToast(app, "✅ GUI: " (newMode = "docked" ? "Docked" : "Undocked"))
}

ToggleLayout(app) {
    p := app.activePalette
    current := p.HasOwnProp("layout") ? p.layout : "normal"

    switch current {
        case "normal": p.layout := "grid"
        case "grid": p.layout := "vertical"
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
        case "grid": return "🔲 Layout: Grid"
        case "vertical": return "📱 Layout: Vertical"
        default: return "📄 Layout: Normal"
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

GetRoleOrderLabel(app) {
    p := app.activePalette
    frozen := p.HasOwnProp("lockLayoutOrder") && p.lockLayoutOrder
    return frozen ? "📌 Role Order: Locked" : "🔄 Role Order: Auto"
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

GetPaletteRoleOrderText(p) {
    if !p.HasOwnProp("roleOrder")
        p.roleOrder := DefaultRoleOrder()

    return JoinRoleOrder(p.roleOrder)
}

GetPaletteGuiModeLabel(p) {
    mode := p.HasOwnProp("guiMode") ? StrLower(p.guiMode) : "undocked"
    return (mode = "docked") ? "Docked" : "Undocked"
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
    if g.HasOwnProp("inputRoleOrder")
        g.inputRoleOrder.Value := GetPaletteRoleOrderText(app.activePalette)
    if g.HasOwnProp("btnLayout")
        g.btnLayout.Text := GetLayoutLabel(app)
    if g.HasOwnProp("noteEdit")
        g.noteEdit.Value := GetPaletteNote(selectedPalette)
    if g.HasOwnProp("btnRoleOrder")
        g.btnRoleOrder.Text := GetRoleOrderLabel(app)
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
    InitHistoryGui(app)
    app.ui.generation++
    RebuildUI(app)
    RefreshPaletteList(app, g)
    g.inputMax.Value := app.activePalette.historyMax
    g.inputCols.Value := app.activePalette.maxCols
    if g.HasOwnProp("btnGuiMode")
        g.btnGuiMode.Text := GetGuiModeLabel(app)
    if g.HasOwnProp("inputRoleOrder")
        g.inputRoleOrder.Value := GetPaletteRoleOrderText(app.activePalette)
    if g.HasOwnProp("btnLayout")
        g.btnLayout.Text := GetLayoutLabel(app)
    if g.HasOwnProp("noteEdit")
        g.noteEdit.Value := GetPaletteNote(app.activePalette)
    if g.HasOwnProp("btnRoleOrder")
        g.btnRoleOrder.Text := GetRoleOrderLabel(app)

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
        clone.isSaved := true

        p.colors.Push(clone)
        if !p.map.Has(clone.hex)
            p.map[clone.hex] := clone
        p.idMap[clone.id] := clone
    }

    p.historyMax := src.historyMax
    p.maxCols := src.maxCols
    p.guiMode := src.HasOwnProp("guiMode") ? src.guiMode : "undocked"
    p.roleOrder := src.HasOwnProp("roleOrder") ? CloneRoleOrder(src.roleOrder) : DefaultRoleOrder()
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

CloneRoleOrder(roleOrder) {
    result := []
    for _, role in roleOrder
        result.Push(role)
    return result
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
TogglePaletteLockLayout(app) {
    p := app.activePalette

    if !p.HasOwnProp("lockLayoutOrder")
        p.lockLayoutOrder := false

    p.lockLayoutOrder := !p.lockLayoutOrder

    g := app.paletteGui
    if IsObject(g) && g.HasOwnProp("btnRoleOrder")
        g.btnRoleOrder.Text := GetRoleOrderLabel(app)

    ShowToast(app, p.lockLayoutOrder
        ? "📌 Role order LOCKED"
        : "🔄 Role order AUTO")

    Layout(app)
}
ImportPaletteImageUI(app) {
    path := FileSelect(1, , "Import Character Sheet Palette", "Images (*.png; *.jpg; *.jpeg; *.bmp)")
    if (path = "")
        return

    ShowImportModeDialog(app, path)
}

ImportFolderImages(app) {
    folderPath := ShowFolderSelectDialog(app)
    if (folderPath = "")
        return

    imageExtensions := "png;jpg;jpeg;bmp;gif;webp"
    imageFiles := []

    Loop Files, folderPath "\*", "F" {
        ext := SubStr(A_LoopFileName, InStr(A_LoopFileName, ".") + 1)
        if InStr(imageExtensions, ext) {
            imageFiles.Push(A_LoopFileFullPath)
        }
    }

    if imageFiles.Length = 0 {
        ShowToast(app, "No images found in folder")
        return
    }

    ShowImportFolderPreview(app, folderPath, imageFiles)
}

ShowFolderSelectDialog(app) {
    g := Gui("+AlwaysOnTop +ToolWindow +Border", "Select Folder")
    g.BackColor := "323338"
    g.SetFont("s9", "Consolas")
    g.MarginX := 16
    g.MarginY := 12

    g.AddText("cFFFFFF", "Select folder with images:")
    g.folderEdit := g.AddEdit("w300 y+4")
    g.AddButton("x+5 yp w30 h24", "...").OnEvent("Click", (*) => DoBrowseFolder(app, g))

    g.AddText("cFFFFFF y+10", "Or enter path:")
    g.pathEdit := g.AddEdit("w300 y+4")

    g.AddButton("w120 h28 y+15", "Select").OnEvent("Click", (*) => DoSelectFolder(app, g))
    g.AddButton("w120 h28 x+10", "Cancel").OnEvent("Click", (*) => g.Destroy())

    g.Show("AutoSize Center")
    app.folderSelectGui := g
    return ""
}

DoBrowseFolder(app, g) {
    folderPath := DirSelect(, 3, "Select folder with images")
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

    imageExtensions := "png;jpg;jpeg;bmp;gif;webp"
    imageFiles := []

    Loop Files, folderPath "\*", "F" {
        ext := SubStr(A_LoopFileName, InStr(A_LoopFileName, ".") + 1)
        if InStr(imageExtensions, ext) {
            imageFiles.Push(A_LoopFileFullPath)
        }
    }

    if imageFiles.Length = 0 {
        ShowToast(app, "No images found in folder")
        return
    }

    ShowImportFolderPreview(app, folderPath, imageFiles)
}

ShowImportMenu(app, g) {
    menu := Gui("+AlwaysOnTop -Caption +ToolWindow", "Import")
    menu.BackColor := "323338"
    menu.SetFont("s9", "Consolas")
    menu.MarginX := 0
    menu.MarginY := 0

    menu.AddButton("w130 h28", "📷 Screenshot").OnEvent("Click", (*) => (menu.Destroy(), DispatchAction(app, g, "Snip")))
    menu.AddButton("w130 h28", "🖼️ Image File").OnEvent("Click", (*) => (menu.Destroy(), DispatchAction(app, g, "Import")))
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
    g.AddButton("x+5 yp w30 h20", "📁").OnEvent("Click", (*) => Run('explorer.exe "' folderPath '"'))

    g.AddText("cAAAAAA y+5", "Found " imageFiles.Length " images:")
    g.fileList := g.AddListView("w450 h200 -Multi", ["#", "File Name"])
    g.fileList.SetFont("s8", "Consolas")
    g.fileList.ModifyCol(1, 40)
    g.fileList.ModifyCol(2, 380)

    for i, fpath in imageFiles {
        fname := SubStr(fpath, InStr(fpath, "\",, -1) + 1)
        g.fileList.Add("", i, fname)
    }

    totalColors := 0
    for imgPath in imageFiles {
        tempPath := A_Temp "\nastarva_import_" A_Index ".png"
        colors := ExtractColorsFromImage(imgPath, tempPath)
        if colors.Length > 0
            totalColors += colors.Length
    }

    g.AddText("y+5 cAAAAAA", "Est. ~" totalColors " colors (top 10 per image)")

    g.AddButton("w140 h28 y+10", "🔍 Import Colors").OnEvent("Click", (*) => DoImportFolderImages(app, g, folderPath, imageFiles))
    g.AddButton("w140 h28 x+10", "Cancel").OnEvent("Click", (*) => g.Destroy())

    g.Show("AutoSize Center")
}

DoImportFolderImages(app, g, folderPath, imageFiles) {
    g.Destroy()
    ShowToast(app, "Processing " imageFiles.Length " images...")

    successCount := 0
    for imgPath in imageFiles {
        try {
            tempPath := A_Temp "\nastarva_import_" A_Index ".png"
            if ProcessSingleImageImport(app, imgPath, tempPath) {
                successCount++
            }
        }
    }

    if successCount > 0 {
        ShowToast(app, "Imported " successCount " images")
        RefreshPaletteManager(app, app.paletteGui)
        SwitchPalette(app, app.activePalette.name)
    } else {
        ShowToast(app, "No colors extracted from images")
    }
}

ExtractColorsFromImage(imgPath, tempPath) {
    colors := []
    scriptPath := A_Temp "\nastarva_color_extract.ps1"

    script := "param([string]`$ImagePath, [string]`$OutPath)`nAdd-Type -AssemblyName System.Drawing`ntry {`n`$img = [System.Drawing.Image]::FromFile(`$ImagePath)`n`$bmp = New-Object System.Drawing.Bitmap(`$img)`n`$colors = @{}`nfor (`$y = 0; `$y -lt `$bmp.Height; `$y += 5) {`nfor (`$x = 0; `$x -lt `$bmp.Width; `$x += 5) {`n`$c = `$bmp.GetPixel(`$x, `$y)`n`$key = (`"{0:X2}{1:X2}{2:X2}`" -f `$c.R, `$c.G, `$c.B)`nif (-not `$colors.ContainsKey(`$key)) { `$colors[`$key] = 1 } else { `$colors[`$key]++ } } } }`n`$sorted = `$colors.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 10`n`$result = (`$sorted | ForEach-Object { `$_.Key }) -join `,`n`$result | Out-File -FilePath `$OutPath -Encoding UTF8`n`$bmp.Dispose()`n`$img.Dispose()`nexit 0 } catch { exit 1 }"

    if FileExist(scriptPath)
        FileDelete(scriptPath)
    FileAppend(script, scriptPath, "UTF-8")

    outputPath := A_Temp "\nastarva_colors_output.txt"
    if FileExist(outputPath)
        FileDelete(outputPath)

    cmd := Format('powershell -NoProfile -ExecutionPolicy Bypass -File "{}" "{}" "{}"', scriptPath, imgPath, outputPath)
    RunWait(cmd, , "Hide")

    if FileExist(outputPath) {
        hexList := StrSplit(Trim(FileRead(outputPath)), ",")
        for hex in hexList {
            hex := Trim(hex)
            if (StrLen(hex) = 6)
                colors.Push(hex)
        }
    }

    return colors
}

ProcessSingleImageImport(app, imgPath, tempPath) {
    scriptPath := A_Temp "\nastarva_single_import.ps1"

    script := "param([string]`$ImagePath, [string]`$OutPath)`nAdd-Type -AssemblyName System.Drawing`ntry {`n`$img = [System.Drawing.Image]::FromFile(`$ImagePath)`n`$bmp = New-Object System.Drawing.Bitmap(`$img)`n`$colors = @{}`nfor (`$y = 0; `$y -lt `$bmp.Height; `$y += 5) {`nfor (`$x = 0; `$x -lt `$bmp.Width; `$x += 5) {`n`$c = `$bmp.GetPixel(`$x, `$y)`n`$key = (`"{0:X2}{1:X2}{2:X2}`" -f `$c.R, `$c.G, `$c.B)`nif (-not `$colors.ContainsKey(`$key)) { `$colors[`$key] = 1 } else { `$colors[`$key]++ } } } }`n`$sorted = `$colors.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 10`n`$result = (`$sorted | ForEach-Object { `$_.Key }) -join `,`n`$result | Out-File -FilePath `$OutPath -Encoding UTF8`n`$bmp.Dispose()`n`$img.Dispose()`nexit 0 } catch { exit 1 }"

    FileDelete(scriptPath)
    FileAppend(script, scriptPath, "UTF-8")

    outputPath := A_Temp "\nastarva_colors_output.txt"
    FileDelete(outputPath)

    cmd := Format('powershell -NoProfile -ExecutionPolicy Bypass -File "{}" "{}" "{}"', scriptPath, imgPath, outputPath)
    RunWait(cmd, , "Hide")

    if !FileExist(outputPath)
        return false

    hexList := StrSplit(Trim(FileRead(outputPath)), ",")
    if hexList.Length = 0
        return false

    p := app.activePalette
    for hex in hexList {
        hex := Trim(hex)
        if StrLen(hex) != 6
            continue
        if p.map.Has(hex)
            continue
        rgb := HexToRGB(hex)
        name := GetColorName(hex)
        item := CreateItem(hex, rgb.r "," rgb.g "," rgb.b, name, "Base")
        item.section := "Imported"
        item.pinned := 0
        AddColor(p, item)
        AddSectionName(p, "Imported")
    }
}

ShowImportModeDialog(app, imagePath) {
    g := Gui("+AlwaysOnTop +ToolWindow", "📥 Import")
    g.BackColor := "323338"
    g.SetFont("s9", "Consolas")

    shortPath := imagePath
    slashPos := InStr(imagePath, "\",, -60)
    if (slashPos > 0)
        shortPath := "..." SubStr(imagePath, slashPos)

    g.AddText("xm y+5 c888888 w320", shortPath)

    g.AddButton("xm y+10 w320 h32", "🔍 Review Import Colors")
        .OnEvent("Click", (*) => (g.Destroy(), ImportPaletteImage(app, imagePath)))

    g.AddButton("xm y+3 w320 h28", "❌ Cancel")
        .OnEvent("Click", (*) => g.Destroy())

    g.Show("AutoSize Center")
}

ImportPaletteImage(app, imagePath) {
    outPath := A_Temp "\nastarva_palette_import.txt"
    scriptPath := A_Temp "\nastarva_palette_import.ps1"

    if FileExist(outPath)
        FileDelete(outPath)
    if FileExist(scriptPath)
        FileDelete(scriptPath)

    FileAppend(GetPaletteImageImportScript(), scriptPath, "UTF-8")

    cmd := Format(
        'powershell -NoProfile -ExecutionPolicy Bypass -File "{}" "{}" "{}"',
        scriptPath,
        imagePath,
        outPath
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
    ShowImportReview(app, imported, outPath, isTemp, importMode)
}

GetPaletteImageImportScript() {
    return FileRead(A_ScriptDir "\src\features\palette_image_import.ps1")
}

StartPaletteScreenshotImport(app) {
    if app.screenshotCapture.active {
        ShowToast(app, "Screenshot capture already running")
        return
    }

    if !IsObject(app.screenshotPollFn)
        app.screenshotPollFn := PollPaletteScreenshotImport.Bind(app)

    app.screenshotCapture.savedClipboard := ClipboardAll()
    app.screenshotCapture.active := true
    app.screenshotCapture.deadline := A_TickCount + 120000
    app.screenshotCapture.tempPath := A_Temp "\nastarva_palette_capture.png"

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

    try currentClip := ClipboardAll()
    if currentClip = "" || currentClip = app.screenshotCapture.savedClipboard {
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

    SetTimer(app.screenshotPollFn, 0)
    CancelPaletteScreenshotImport(app, "Screenshot canceled")
}

CancelPaletteScreenshotImport(app, message := "") {
    app.screenshotCapture.active := false
    SetTimer(app.screenshotPollFn, 0)

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
    scriptPath := A_Temp "\nastarva_clipboard_image_save.ps1"

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

    g.chkSkipDup := g.AddCheckbox("Checked y+4", "Skip duplicates (keep existing)")

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
        AddColor(tgt, newItem)
        added++
        if !tgt.sections.Has(item.section)
            tgt.sections.Push(item.section)
    }

    Normalize(tgt)
    SaveHistory(app)
    g.Destroy()
    ShowToast(app, "Merged: " added " added, " skipped " skipped (duplicates)")
}

OpenPaletteCompareDialog(app) {
    palNames := []
    for name in app.paletteOrder
        palNames.Push(name)

    if palNames.Length < 2 {
        ShowToast(app, "Need at least 2 palettes to compare")
        return
    }

    g := Gui("+AlwaysOnTop +ToolWindow +Border", "Compare Palettes")
    g.BackColor := "323338"
    g.SetFont("s9", "Consolas")
    g.MarginX := 16
    g.MarginY := 12

    g.AddText("cFFFFFF", "Palette A:")
    g.listA := g.AddDropDownList("w220 y+4", palNames)
    g.listA.Value := 1

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
    g.Destroy()

    pA := app.palettes[nameA]
    pB := app.palettes[nameB]

    setA := Map()
    setB := Map()
    for item in pA.colors
        setA[item.hex] := item
    for item in pB.colors
        setB[item.hex] := item

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

    cg := Gui("+AlwaysOnTop +ToolWindow +Border", "Comparison: " nameA " vs " nameB)
    cg.BackColor := "323338"
    cg.SetFont("s9", "Consolas")
    cg.MarginX := 12
    cg.MarginY := 10

    cg.AddText("cFFD76A", "Summary:")
    cg.AddText("cFFFFFF", "Common: " common.Length " | Only in " nameA ": " onlyA.Length " | Only in " nameB ": " onlyB.Length)

    cg.AddText("c00FF88 y+10", "In Both (" common.Length "):")
    cg.commonList := cg.AddListView("w480 h100 -Multi", ["HEX", "Name", "Role", "A Name", "B Name"])
    cg.commonList.SetFont("s8", "Consolas")
    for hex in common {
        itemA := setA[hex]
        itemB := setB[hex]
        cg.commonList.Add("", "#" hex, itemA.name, itemA.role, itemA.name, itemB.name)
    }
    if common.Length > 0
        cg.commonList.Modify(1, "Select")

    cg.AddText("cFF6B6B y+8", "Only in " nameA " (" onlyA.Length "):")
    cg.onlyAList := cg.AddListView("w480 h80 -Multi", ["HEX", "Name", "Role"])
    cg.onlyAList.SetFont("s8", "Consolas")
    for hex in onlyA {
        item := setA[hex]
        cg.onlyAList.Add("", "#" hex, item.name, item.role)
    }
    if onlyA.Length > 0
        cg.onlyAList.Modify(1, "Select")

    cg.AddText("c6B9FFF y+8", "Only in " nameB " (" onlyB.Length "):")
    cg.onlyBList := cg.AddListView("w480 h80 -Multi", ["HEX", "Name", "Role"])
    cg.onlyBList.SetFont("s8", "Consolas")
    for hex in onlyB {
        item := setB[hex]
        cg.onlyBList.Add("", "#" hex, item.name, item.role)
    }
    if onlyB.Length > 0
        cg.onlyBList.Modify(1, "Select")

    cg.AddButton("w150 h28 y+8", "Copy All HEX (A only)").OnEvent("Click", (*) => CopyHexList(app, onlyA))
    cg.AddButton("w150 h28 x+10", "Copy All HEX (B only)").OnEvent("Click", (*) => CopyHexList(app, onlyB))
    cg.AddButton("w150 h28 x+10", "Close").OnEvent("Click", (*) => cg.Destroy())

    cg.Show("AutoSize Center")
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

RefreshPaletteManager(app, g) {
    SaveSectionPanelPositions(app)
    SaveHistory(app)

    LoadHistory(app)

    g.inputMax.Value := app.activePalette.historyMax
    g.inputCols.Value := app.activePalette.maxCols
    if g.HasOwnProp("btnGuiMode")
        g.btnGuiMode.Text := GetGuiModeLabel(app)
    if g.HasOwnProp("inputRoleOrder")
        g.inputRoleOrder.Value := GetPaletteRoleOrderText(app.activePalette)
    if g.HasOwnProp("btnLayout")
        g.btnLayout.Text := GetLayoutLabel(app)
    if g.HasOwnProp("noteEdit")
        g.noteEdit.Value := GetPaletteNote(app.activePalette)
    if g.HasOwnProp("btnRoleOrder")
        g.btnRoleOrder.Text := GetRoleOrderLabel(app)


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
    tpl := templates[selName]
    g.previewLabel.Text := "Preview: " GetTemplateColorCount(tpl) " colors"

    g.Show("AutoSize Center")
}
UpdateTemplatePreview(g, templates) {
    selName := g.tplList.Text
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
    newFile := newName ".txt"

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
    item := CreateItem(hex, rgb, name, role)
    item.pinned := 0
    if section = ""
        section := "Imported"
    item.section := section
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
    RefreshSectionByName(app, section)
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

    inputGui.AddText("cAAAAAA y+10", "Section name:")
    inputGui.AddEdit("w280 y+4", p.name).Name := "sectionEdit"

    inputGui.AddButton("w130 h28 y+15", "Save").OnEvent("Click", (*) => DoSaveTemplate(app, g, inputGui))
    inputGui.AddButton("w130 h28 x+10", "Cancel").OnEvent("Click", (*) => inputGui.Destroy())

    inputGui.Show("AutoSize Center")
}

DoSaveTemplate(app, g, inputGui) {
    nameEdit := inputGui["nameEdit"]
    sectionEdit := inputGui["sectionEdit"]
    tplName := Trim(nameEdit.Value)
    tplSection := Trim(sectionEdit.Value)
    if tplName = "" {
        ShowToast(app, "Name cannot be empty")
        return
    }
    p := app.activePalette
    SavePaletteAsTemplateFile(app, tplName, tplSection, p)
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
            sectionEdit := gui["sectionEdit"]
            p := App.activePalette
            tplName := Trim(nameEdit.Value)
            tplSection := Trim(sectionEdit.Value)
            if tplName = "" {
                ShowToast(App, "Name cannot be empty")
                return
            }
            SavePaletteAsTemplateFile(App, tplName, tplSection, p)
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

SavePaletteAsTemplateFile(app, tplName, tplSection, p) {
    tplDir := A_ScriptDir "\templates"
    DirCreate(tplDir)
    tplPath := tplDir "\" tplName ".txt"

    lines := []
    lines.Push("#TEMPLATE|" tplName)
    if p.HasOwnProp("sections") && IsObject(p.sections) {
        for sec in p.sections {
            lines.Push("#SECTION|" sec.name "|" sec.id)
        }
    }
    for item in p.colors {
        lines.Push("#COLOR|" item.hex "|" item.rgb "|" item.name "|" item.role "|" item.section)
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
        tpl := Map("section", "", "items", Map())
        for i, line in lines {
            if i = 1
                continue
            if InStr(line, "#COLOR|") {
                cparts := StrSplit(line, "|")
                if cparts.Length >= 6 {
                    colorData := cparts[2] "|" cparts[4] "|" cparts[5]
                    section := cparts.Length >= 6 ? cparts[6] : ""
                    tpl["items"][cparts[3]] := colorData
                    if section != "" && tpl["section"] = ""
                        tpl["section"] := section
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

    g.colorDrop.OnEvent("Change", (*) => UpdateHarmonyPreview(g))
    g.harmonyDrop.OnEvent("Change", (*) => UpdateHarmonyPreview(g))

    ; =========================
    ; INITIAL STATE
    ; =========================
    UpdateHarmonyPreview(g)

    g.Show("AutoSize Center")
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
    try g.targetPreview.Opt("c" baseHex)
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
    g.targetPreview := g.AddProgress("x10 y" rowY " w230 h1 Background4A4A4A")
    rowY += 12
    g.previewLabel := g.AddText("x10 y" rowY " cAAAAAA", "Preview: " colors.Length " colors")
    rowY += 26
    g.AddText("x10 y" rowY " cAAAAAA", "Actions")
    rowY += 18
    g.btnApply := g.AddButton("x10 y" rowY " w110 h28", "✨ Apply")
g.btnClose := g.AddButton("x130 y" rowY " w110 h28", "✖ Close")
    g.btnClose.OnEvent("Click", (*) => g.Destroy())
    g.cbDrop.OnEvent("Change", (*) => UpdateColorBlindPreview(g, colors, g.cbDrop.Text))

    UpdateColorBlindPreview(g, colors, g.cbDrop.Text)

    g.Show("AutoSize Center")
}
ColorBlindApplyColors(app, g, colors) {

    g.AddText("cFFFFFF y+10", "Preview (" colors.Length " colors):")
    g.previewList := g.AddListView("w500 h200 -Multi", ["Original", "Simulated", "Name"])
    g.previewList.SetFont("s8", "Consolas")
    g.previewList.ModifyCol(1, 60)
    g.previewList.ModifyCol(2, 60)
    g.previewList.ModifyCol(3, 150)

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
    firstColor := colors[1]
    if InStr(firstColor, "|")
        firstColor := StrSplit(firstColor, "|")[1]
    simHex := SimulateColorBlindness(firstColor, cbType)
    try g.targetPreview.Opt("c" simHex)

    if !g.HasOwnProp("previewList") || !g.previewList {
        g.previewLabel.Text := "Preview: " colors.Length " colors"
        return
    }
    count := 0
    g.previewList.Delete()
    for hex in colors {
        cleanHex := InStr(hex, "|") ? StrSplit(hex, "|")[1] : hex
        simHex := SimulateColorBlindness(cleanHex, cbType)
        g.previewList.Add("", "#" cleanHex, "#" simHex)
        count++
    }
    g.previewLabel.Text := "Preview: " count " colors"
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
