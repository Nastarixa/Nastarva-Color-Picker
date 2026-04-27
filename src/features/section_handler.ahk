RefreshSectionBySectionId(app, sectionId) {
    if sectionId = ""
        return

    sectionName := ""
    if app.activePalette.HasOwnProp("sections") {
        for section in app.activePalette.sections {
            if IsObject(section) && section.HasOwnProp("id") && section.id = sectionId {
                sectionName := section.name
                break
            }
        }
    }

    if sectionName = ""
        return

    tokens := []
    for token, ctrl in app.ui.controls {
        if !ctrl.HasOwnProp("sectionId") || ctrl.sectionId = ""
            continue
        if ctrl.sectionId = sectionId
            tokens.Push(token)
    }

    for token in tokens {
        if app.ui.controls.Has(token)
            UpdateCellDisplay(app, token)
    }

    sectionGui := GetSectionGuiByName(app, sectionName)
    if IsObject(sectionGui) {
        try UpdateSectionPanelChrome(app, sectionGui, sectionName)
    }
}

StartSectionPanelMove(app, sectionName) {
    panelHwnd := 0
    for name, g in app.ui.sectionGuis {
        if name = sectionName {
            panelHwnd := SafeGetGuiHwnd(g)
            break
        }
    }
    if !panelHwnd
        return
    if IsSectionLocked(app.activePalette, sectionName) {
        ShowToast(app, "Unlock the section first")
        return
    }
    MouseGetPos(&mx, &my)
    WinGetPos(&wx, &wy,,, "ahk_id " panelHwnd)
    app.ui.panelMove.pending := true
    app.ui.panelMove.active := false
    app.ui.panelMove.hwnd := panelHwnd
    app.ui.panelMove.startMouseX := mx
    app.ui.panelMove.startMouseY := my
    app.ui.panelMove.offsetX := mx - wx
    app.ui.panelMove.offsetY := my - wy
    app.ui.panelMove.lastX := wx
    app.ui.panelMove.lastY := wy
    app.ui.panelMove.lastMoveTick := 0
    DllCall("SetCapture", "Ptr", panelHwnd)
}

RefreshSectionByItemId(app, itemId) {
    item := GetItemById(app, itemId)
    if !item
        return
    sectionName := GetItemSectionNameForState(item)
    sectionId := GetSectionId(app.activePalette, sectionName)
    RefreshSectionBySectionId(app, sectionId)
}

RefreshSectionByToken(app, token) {
    sectionId := GetSectionIdFromToken(app, token)
    if sectionId
        RefreshSectionBySectionId(app, sectionId)
}

RefreshSectionByName(app, sectionName) {
    sectionId := GetSectionId(app.activePalette, sectionName)
    RefreshSectionBySectionId(app, sectionId)
}

RefreshSectionChromeByName(app, sectionName) {
    g := GetSectionGuiByName(app, sectionName)
    if !g
        return
    UpdateSectionPanelChrome(app, g, sectionName)
}

RefreshSectionBySectionName(app, sectionName) {
    RefreshSectionChromeByName(app, sectionName)
    RefreshSectionByName(app, sectionName)
}

OpenSectionMenu(app, sectionName) {
    if app.HasOwnProp("sectionMenuGui") && SafeGetGuiHwnd(app.sectionMenuGui)
        app.sectionMenuGui.Destroy()

    g := Gui("+AlwaysOnTop -Caption +ToolWindow")
    g.BackColor := "323338"
    g.SetFont("s9", "Consolas")
    g.MarginX := 8
    g.MarginY := 6

    g.AddButton("xm y+4 w182 h22", "➕ New Section")
        .OnEvent("Click", (*) => CreateSectionFromMenu(app, g))

    g.AddButton("xm y+4 w90 h22", "📝 Note")
        .OnEvent("Click", (*) => EditSectionNoteUI(app, sectionName, g))

    g.AddButton("x+2 w90 h22", "🏷️ Color Tag")
        .OnEvent("Click", (*) => EditSectionTagUI(app, sectionName, g))


    g.AddButton("xm y+4 w90 h22", "✏️ Rename")
        .OnEvent("Click", (*) => RenameSectionUI(app, sectionName, g))

    g.AddButton("x+2 w90 h22", "📋 Duplicate")
        .OnEvent("Click", (*) => DuplicateSectionUI(app, sectionName, g))

    collapsed := IsSectionCollapsed(app.activePalette, sectionName)
    label := collapsed ? "▼ Expand" : "▲ Collapse"
    g.AddButton("xm y+4 w90 h22", label)
        .OnEvent("Click", (*) => ToggleSectionCollapsedFromMenu(app, sectionName, g))

    g.AddButton("x+2 w90 h22", IsSectionLocked(app.activePalette, sectionName) ? "🔓 Unlock" : "🔒 Lock")
        .OnEvent("Click", (*) => ToggleSectionLockFromMenu(app, sectionName, g))
    g.AddButton("xm y+4 w182 h22", "🔀 Merge Into...")
        .OnEvent("Click", (*) => MergeSectionUI(app, sectionName, g))

    g.AddButton("xm y+4 w182 h22", "🔄 Refresh")
        .OnEvent("Click", (*) => RefreshSectionFromMenu(app, sectionName, g))

    g.AddButton("xm y+4 w182 h22", "🔍 Cross-Palette Ref")
        .OnEvent("Click", (*) => CrossRefFromSection(app, sectionName, g))

    deleteBtn := g.AddButton("xm y+2 w182 h22", "🗑 Delete Section")
    deleteBtn.OnEvent("Click", (*) => DeleteSectionUI(app, sectionName, g))


    g.hideTick := (*) => AutoHideSectionMenu(app, g)
    SetTimer(g.hideTick, 2000)

g.Show("AutoSize NoActivate")
    WinGetPos(&gX, &gY, &gW, &gH, g)
    MouseGetPos(&mx, &my)
    mL := 0, mT := 0, mR := A_ScreenWidth, mB := A_ScreenHeight
    monitorCount := MonitorGetCount()
    Loop monitorCount {
        MonitorGetWorkArea(A_Index, &wl, &wt, &wr, &wb)
        if mx >= wl && mx <= wr && my >= wt && my <= wb {
            mL := wl, mT := wt, mR := wr, mB := wb
            break
        }
    }
    showX := mx
    showY := my
    if showX + gW > mR
        showX := mR - gW - 4
    if showX < mL
        showX := mL + 4
    if showY + gH > mB
        showY := mB - gH - 4
    if showY < mT
        showY := mT + 4
    g.Show("x" showX " y" showY " NoActivate")

    app.sectionMenuGui := g
}

AutoHideSectionMenu(app, g) {
    MouseGetPos()
    if !GetKeyState("LButton", "P") {
        try g.Destroy()
    }
}

RenameSectionUI(app, sectionName, menuGui) {
    if SafeGetGuiHwnd(menuGui)
        menuGui.Destroy()
    ShowInputDialog(app, "New section name:", "✏ Rename Section", (val) => RenameSectionConfirm(app, sectionName, val), sectionName)
}

RenameSectionConfirm(app, sectionName, val) {
    newName := Trim(val)
    if newName = "" || newName = sectionName
        return
    if RenameSection(app, sectionName, newName) {
        ShowToast(app, "Renamed to: " newName)
    }
}

DuplicateSectionUI(app, sectionName, menuGui) {
    if SafeGetGuiHwnd(menuGui)
        menuGui.Destroy()
    DuplicateSection(app, sectionName)
    ShowToast(app, "Duplicated: " sectionName)
}

ToggleSectionCollapsedFromMenu(app, sectionName, menuGui) {
    if SafeGetGuiHwnd(menuGui)
        menuGui.Destroy()
    ToggleSectionCollapsed(app, sectionName)
}

ToggleSectionLockFromMenu(app, sectionName, menuGui) {
    if SafeGetGuiHwnd(menuGui)
        menuGui.Destroy()
    ToggleSectionLock(app, sectionName)
}

RefreshSectionFromHeader(app, sectionName) {
    RefreshSectionConfirm(app, sectionName)
}

RefreshSectionFromMenu(app, sectionName, menuGui) {
    if SafeGetGuiHwnd(menuGui)
        menuGui.Destroy()
    RefreshSectionConfirm(app, sectionName)
}

RefreshSectionConfirm(app, sectionName) {
    SaveHistory(app)
    app.ui.generation++
    InitHistoryGui(app)
    RebuildUI(app)
    Emit(app, "history_changed")
    ShowToast(app, "🔄 Section refreshed: " sectionName)
}

EditSectionNoteUI(app, sectionName, menuGui := 0) {
    if SafeGetGuiHwnd(menuGui)
        menuGui.Destroy()
    current := GetSectionNote(app.activePalette, sectionName)

    g := Gui("+AlwaysOnTop +Border", "Section Note - " sectionName)
    g.BackColor := "323338"
    g.SetFont("s9", "Consolas")
    g.MarginX := 12
    g.MarginY := 10

    g.input := g.AddEdit("w200 h60 -Wrap", current)

    g.AddButton("w140 h28", "✓ Save").OnEvent("Click", SectionNoteSave.Bind(app, sectionName, g))
    g.AddButton("w40 h28 x+5", "✕").OnEvent("Click", (*) => g.Destroy())

    g.Show("Center")
}

SectionNoteSave(app, sectionName, g, *) {
    EditSectionNoteConfirm(app, sectionName, g.input.Value)
    g.Destroy()
}

EditSectionNoteConfirm(app, sectionName, val) {
    SetSectionNote(app, sectionName, val)
    SaveHistory(app)
    ShowToast(app, "Section note saved")
}

EditSectionTagUI(app, sectionName, menuGui := 0) {
    if SafeGetGuiHwnd(menuGui)
        menuGui.Destroy()
    current := GetSectionTagColor(app.activePalette, sectionName)
    currentColor := (current != "") ? current : "808080"

    g := Gui("+AlwaysOnTop +Border", "Section Color Tag")
    g.BackColor := "323338"
    g.SetFont("s10", "Segoe UI")
    g.MarginX := 12
    g.MarginY := 10
    app.tagDialog := g

    panelW := 320
    headerY := 10
    headerH := 32

    g.AddText("x12 y" headerY " w" panelW " h" headerH " Background38383D Border")

    g.AddText("x22 y" headerY+8 " cAAAAAA", "Section:")
    g.AddText("x+6 y" headerY+8 " cFFD76A", sectionName)

    previewY := headerY + headerH + 10
    previewH := 70

    g.AddText("x12 y" previewY " w" panelW " h" previewH " Background38383D Border")

    g.AddText("x22 y" previewY+6 " cAAAAAA", "Preview")

    g.preview := g.AddText(
        "x22 y" previewY+26 " w" (panelW-20) " h32 Background" currentColor " Border cFFFFFF Center",
        sectionName
    )

    colorY := previewY + previewH + 10
    colorH := 110

    g.AddText("x12 y" colorY " w" panelW " h" colorH " Background38383D Border")

    g.AddText("x22 y" colorY+6 " cAAAAAA", "Quick Colors")

    colors := [
        "FF0000","FF6600","FFAA00","FFD580","FFFF00",
        "CCFFCC","88FF00","00FF00","00FF88","00FFFF",
        "AACCFF","0088FF","0000FF","B388FF","8800FF",
        "FF00FF","FFAACC","FF0088",

        "FFFFFF","CCCCCC","999999","666666","333333","000000"
    ]

    cols := 12
    cell := 20
    gap := 6
    gridStartX := 19
    gridStartY := colorY + 28

    for i, color in colors {
        col := Mod(i-1, cols)
        row := Floor((i-1)/cols)
        x := gridStartX + (col * (cell + gap))
        y := gridStartY + (row * (cell + gap))
        box := g.AddText("x" x " y" y " w" cell " h" cell " Background" color " Border")
        box.color := color
        box.OnEvent("Click", (ctrl, *) => g.input.Value := ctrl.color)
    }

    g.AddText("xm y+20 w" panelW " h100 Background38383D Border")
    g.AddText("xp+10 yp+8 cAAAAAA", "Custom HEX")
    g.input := g.AddEdit("xp+10 yp+22 w120")

    g.AddButton("w70 h22 y+6", "Apply").OnEvent("Click", (*) => SectionTagApplyManual(app, sectionName, g))
    g.AddButton("w70 h22 x+5", "Clear").OnEvent("Click", (*) => SectionTagClear(app, sectionName, g))
    g.AddButton("w70 h22 x+5", "Cancel").OnEvent("Click", (*) => g.Destroy())

    g.OnEvent("Close", (*) => ClearTagDialog(app))
    g.Show("AutoSize Center")
}

ClearTagDialog(app) {
    if app.HasOwnProp("tagDialog")
        app.tagDialog := 0
}

SectionTagApplyManual(app, sectionName, g, *) {
    EditSectionTagConfirm(app, sectionName, g.input.Value)
}

SectionTagClear(app, sectionName, g, *) {
    EditSectionTagConfirm(app, sectionName, "")
}

EditSectionTagConfirm(app, sectionName, val) {
    tag := StrUpper(RegExReplace(Trim(val), "(?i)[^0-9A-F]"))
    if (tag != "" && StrLen(tag) != 6) {
        ShowToast(app, "Use 6-digit HEX like FFAA33")
        return
    }
    SetSectionTagColor(app, sectionName, tag)
    SaveHistory(app)
    RefreshSectionByName(app, sectionName)
    ShowToast(app, "Tag updated")
    if app.HasOwnProp("tagDialog") && SafeGetGuiHwnd(app.tagDialog)
        app.tagDialog.Destroy()
}

DeleteSectionUI(app, sectionName, menuGui) {
    if SafeGetGuiHwnd(menuGui)
        menuGui.Destroy()

    g := Gui("+AlwaysOnTop +Border", "Confirm Delete")
    g.BackColor := "323338"
    g.SetFont("s9", "Consolas")
    g.MarginX := 16
    g.MarginY := 12

    g.AddText("cFFFFFF", "Delete section " sectionName "?")
    g.AddText("cAAAAAA", "Colors will be removed from palette.")

    g.AddButton("w80 h28", "Cancel").OnEvent("Click", (*) => g.Destroy())
    g.AddButton("x+10 w80 h28", "Delete").OnEvent("Click", (*) => DeleteSectionConfirm(app, sectionName, g))

    g.Show("Center")
}

DeleteSectionConfirm(app, sectionName, g) {
    g.Destroy()
    DeleteSection(app, sectionName)
    ShowToast(app, "Deleted: " sectionName)
}

CreateSectionHeader(app, sectionName, totalW, headerH) {
    g := app.ui.panelContainer
    ctrl := g.AddText("x0 y0 w" totalW " h" headerH " -Background")
    ctrl.SetFont("s9", "Consolas")
    ctrl.Opt("+BackgroundTrans")
    ctrl.Value := sectionName
}

ClearSectionHeaders(app) {
    if !app.ui.HasOwnProp("sectionHeaders")
        app.ui.sectionHeaders := Map()

    for _, header in app.ui.sectionHeaders
        try header.Destroy()

    app.ui.sectionHeaders := Map()
}


BuildSectionGroups(app) {
    p := app.activePalette
    groups := []
    groupMap := Map()
    maxPerSection := p.HasOwnProp("maxPerSection") ? p.maxPerSection : 0

    EnsureDefaultSection(p)

    for _, section in p.sections {
        name := IsObject(section) ? section.name : section
        name := (name = "") ? "Default" : name
        group := { name: name, items: [] }
        groups.Push(group)
        groupMap[name] := group
    }

    for _, item in p.colors {
        sectionName := item.HasOwnProp("section") && item.section != ""
            ? item.section
            : "Default"

        if !groupMap.Has(sectionName) {
            group := { name: sectionName, items: [] }
            groups.Push(group)
            groupMap[sectionName] := group
        }

        if maxPerSection > 0 && groupMap[sectionName].items.Length >= maxPerSection
            continue

        groupMap[sectionName].items.Push(item)
    }

    for _, group in groups {
        p := app.activePalette
        hasRoleOrder := p.HasOwnProp("roleOrder") && p.roleOrder.Length > 0
        if hasRoleOrder || !(p.HasOwnProp("lockLayoutOrder") && p.lockLayoutOrder)
            SortSectionItems(app, group.items)
    }

    return groups
}

RegisterSectionPanelDrag(app, g) {
    if IsPaletteDocked(app.activePalette)
        return

    if !app.ui.HasOwnProp("panelDragHwnds")
        app.ui.panelDragHwnds := Map()

    panelHwnd := SafeGetGuiHwnd(g)
    if panelHwnd
        app.ui.panelDragHwnds[panelHwnd] := panelHwnd

    for _, ctrlName in ["tag", "header", "headerContainer", "target", "lock", "refresh", "collapse", "menu", "close", "dragStrip"] {
        if g.HasOwnProp(ctrlName) {
            hwnd := SafeGetControlHwnd(g.%ctrlName%)
            if hwnd
                app.ui.panelDragHwnds[hwnd] := panelHwnd
        }
    }
}

RemoveEmptySectionPanels(app, visibleSections) {
    if !app.ui.HasOwnProp("sectionGuis")
        return

    toDelete := []
    for sectionName, g in app.ui.sectionGuis {
        if !visibleSections.Has(sectionName)
            toDelete.Push(sectionName)
    }

    for _, sectionName in toDelete {
        if !app.ui.sectionGuis.Has(sectionName)
            continue

        try app.ui.sectionGuis[sectionName].Destroy()
        app.ui.sectionGuis.Delete(sectionName)
    }

    app.historyGui := 0
    for _, g in app.ui.sectionGuis {
        if SafeGetGuiHwnd(g) {
            app.historyGui := g
            break
        }
    }
}

SortSectionItems(app, items) {
    Loop items.Length {
        swapped := false
        Loop items.Length - 1 {
            if ShouldItemComeAfter(app, items[A_Index], items[A_Index + 1]) {
                temp := items[A_Index]
                items[A_Index] := items[A_Index + 1]
                items[A_Index + 1] := temp
                swapped := true
            }
        }
        if !swapped
            break
    }
}


GetSectionGuiByName(app, sectionName) {
    if !app.HasProp("ui")
        return ""

    if !app.ui.HasProp("sectionGuis")
        return ""

    return app.ui.sectionGuis.Has(sectionName)
        ? app.ui.sectionGuis[sectionName]
        : ""
}


GetSectionIdFromToken(app, token) {
    if !app.HasProp("ui")
        return ""

    if !app.ui.HasProp("controls")
        return ""

    if !app.ui.controls.Has(token)
        return ""

    ctrl := app.ui.controls[token]

    return (IsObject(ctrl) && ctrl.HasOwnProp("sectionId"))
        ? ctrl.sectionId
        : ""
}

MergeSectionUI(app, sectionName, menuGui := 0) {
    if IsObject(menuGui)
        try menuGui.Hide()

    names := []
    for _, section in app.activePalette.sections {
        name := IsObject(section) ? section.name : section
        if (name != sectionName)
            names.Push(name)
    }

    if (names.Length = 0) {
        ShowToast(app, "No section to merge into")
        return
    }

    ShowChoiceDialog(app, "Merge Section", "Merge '" sectionName "' into:", names, (target) => MergeSection(app, sectionName, target))
}

CrossRefFromSection(app, sectionName, menuGui) {
    if menuGui
        try menuGui.Destroy()
    OpenCrossPaletteReference(app, "")
}
