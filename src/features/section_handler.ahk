QueueHistoryRebuild(app) {
    static pending := false
    static lastStateHash := ""

    if pending
        return

    p := app.activePalette
    currentHash := p.colors.Length "|"
    for _, item in p.colors {
        currentHash .= item.hex "|" item.id "|"
        if item.HasOwnProp("section")
            currentHash .= item.section "|"
    }
    if p.HasOwnProp("sections") {
        currentHash .= "s" p.sections.Length
    }
    if p.HasOwnProp("layout") {
        currentHash .= "l" p.layout
    }
    if p.HasOwnProp("maxCols") {
        currentHash .= "c" p.maxCols
    }

    if currentHash = lastStateHash {
        return
    }
    lastStateHash := currentHash

    pending := true
    SetTimer(() => (
        pending := false,
        app.ui.generation++,
        RebuildUI(app),
        Emit(app, "history_changed")
    ), -1)
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
    if !app.historyVisible
        return
    QueueHistoryRebuild(app)
}

RefreshCellByIdHandler(app, id) {
    if !app.historyVisible
        return
    item := GetItemById(app, id)
    if !item
        return
    token := GetItemToken(item)
    if app.ui.controls.Has(token)
        UpdateCellDisplay(app, token)
}

RefreshCellByTokenHandler(app, token) {
    if !app.historyVisible
        return
    if app.ui.controls.Has(token)
        UpdateCellDisplay(app, token)
}

RefreshSectionByToken(app, token) {
    if !app.historyVisible
        return
    QueueHistoryRebuild(app)
}

RefreshSectionChromeByName(app, sectionName) {
    g := GetSectionGuiByName(app, sectionName)
    if !g
        return

    state := GetSectionChromeState(app, sectionName)

    if (!g.HasOwnProp("lastState") || g.lastState != state) {
        UpdateSectionPanelChrome(app, g, sectionName)
        g.lastState := state
    }
}

RefreshSectionBySectionName(app, sectionName) {
    if !app.historyVisible
        return
    QueueHistoryRebuild(app)
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
    if app.activePalette && !IsPaletteDocked(app.activePalette) && app.historyVisible
        SaveSectionPanelPositions(app)
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
    RebuildUI(app)
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

    g.AddButton("w80 h28", "Delete").OnEvent("Click", (*) => DeleteSectionConfirm(app, sectionName, g))
    g.AddButton("x+10 w80 h28", "Cancel").OnEvent("Click", (*) => g.Destroy())

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
        if groupMap.Has(name)
            continue
        group := { name: name, items: [] }
        groups.Push(group)
        groupMap[name] := group
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
        SortSectionItems(app, group.items)
    }

    return groups
}

BuildSingleSectionGroup(app, sectionName) {
    p := app.activePalette
    maxPerSection := p.HasOwnProp("maxPerSection") ? p.maxPerSection : 0

    group := { name: sectionName, items: [] }

    for _, item in p.colors {
        itemSection := item.HasOwnProp("section") && item.section != ""
            ? item.section
            : "Default"

        if itemSection != sectionName
            continue

        if maxPerSection > 0 && group.items.Length >= maxPerSection
            continue

        group.items.Push(item)
    }

    SortSectionItems(app, group.items)
    return group
}

BuildCharacterGroups(app) {
    p := app.activePalette
    roleOrder := ["Mask", "Outline", "Black", "Base", "Shadow", "2 Shadow", "Highlight", "Hi Shadow"]
    resultGroups := []
    sectionGroups := BuildSectionGroups(app)

    for _, section in sectionGroups {
        sectionName := section.name
        sectionId := GetSectionId(p, sectionName)
        sectionItems := section.items
        cards := []

        for _, item in sectionItems {
            role := NormalizeCharacterExportRole(item.HasOwnProp("role") ? item.role : "")
            item._normalizedCharacterRole := role
            placed := false

            for _, card in cards {
                if !card.roleMap.Has(role) {
                    card.roleMap[role] := item
                    placed := true
                    break
                }
            }

            if !placed {
                cardIndex := cards.Length + 1
                groupKey := (sectionId != "")
                    ? "character|" sectionId "|" cardIndex
                    : "character|" sectionName "|" cardIndex
                cardName := cardIndex = 1 ? sectionName : sectionName " (" cardIndex ")"
                card := {
                    name: cardName,
                    key: groupKey,
                    positionKey: groupKey,
                    sourceSection: sectionName,
                    roleMap: Map(),
                    items: []
                }
                card.roleMap[role] := item
                cards.Push(card)
            }
        }

        for _, card in cards {
            orderedItems := []
            for _, roleName in roleOrder {
                if card.roleMap.Has(roleName) {
                    item := card.roleMap[roleName]
                    item._roleGroup := card.name
                    orderedItems.Push(item)
                }
            }
            card.items := orderedItems
            resultGroups.Push(card)
        }
    }

    return resultGroups
}

NormalizeCharacterExportRole(role) {
    role := Trim(role)
    if (role = "")
        return "Base"
    if RegExMatch(role, "i)^BL$")
        return "Black"
    if RegExMatch(role, "i)Hi[\s-]*Shadow|High[\s-]*Shadow")
        return "Hi Shadow"
    if RegExMatch(role, "i)2.*Shadow|Shadow.*2|Second Shadow")
        return "2 Shadow"
    return role
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

    if app.ui.sectionGuis.Has(sectionName)
        return app.ui.sectionGuis[sectionName]

    for _, g in app.ui.sectionGuis
        if g.HasOwnProp("sourceSectionName") && g.sourceSectionName = sectionName
            return g

    return ""
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

    ShowChoiceDialog(app, "Merge Section", "Merge '" sectionName "' into:", names, (target) => (
        MergeSection(app, sectionName, target),
        QueueHistoryRebuild(app)
    ))
}

CrossRefFromSection(app, sectionName, menuGui) {
    if menuGui
        try menuGui.Destroy()
    OpenCrossPaletteReference(app, "")
}
