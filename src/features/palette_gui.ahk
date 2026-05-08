TogglePalette(app) {
    app.historyVisible := !app.historyVisible

    if app.historyVisible {
        if !HasHistoryPanels(app) {
            InitHistoryGui(app)
            RebuildUI(app)
        } else {
            PrepareSectionPanelsForRestore(app)
            Layout(app)
        }
    } else {
        HideHistoryPanels(app)
    }
}

GetHistoryGui(app) {
    if !HasHistoryPanels(app)
        InitHistoryGui(app)
    return app.historyGui
}

InitHistoryGui(app) {
    DestroyHistoryPanels(app)
    
    app.ui.controls := Map()
    app.ui.sectionHeaders := Map()
    app.ui.panelDragHwnds := Map()
    app.ui.controlHexByHwnd := Map()
    app.ui.batchLastSelected := ""
    app.ui.lastSingleSelected := ""
    app.historyGui := 0
}

RebuildUI(app) {
    currentLayout := app.activePalette.HasOwnProp("layout") ? app.activePalette.layout : "normal"
    characterMode := app.HasOwnProp("characterMode") && app.characterMode
    if characterMode
        currentLayout := "character"

    if app.ui.HasOwnProp("sectionGuis") {
        for _, g in app.ui.sectionGuis {
            try g.Destroy()
        }
    }
    
    for _, ctrl in app.ui.controls {
        try ctrl.bg.Destroy()
        if (ctrl.txt != ctrl.bg)
            try ctrl.txt.Destroy()
    }

    app.ui.controls := Map()
    app.ui.controlHexByHwnd := Map()
    app.ui.sectionByHwnd := Map()
    app.ui.panelDragHwnds := Map()
    app.ui.characterGroupByToken := Map()
    ClearSectionHeaders(app)
    DestroyHistoryPanels(app)
    app.ui.sectionGuis := Map()

    if (currentLayout = "character") {
        app.ui.characterGroups := BuildCharacterGroups(app)
        for _, group in app.ui.characterGroups {
            for _, groupItem in group.items
                app.ui.characterGroupByToken[GetItemToken(groupItem)] := group
        }
    } else {
        app.ui.characterGroups := []
    }

    for _, item in app.activePalette.colors {
        CreateCell(app, item)
    }

    Layout(app)
}

RefreshCellById(app, id) {
    item := GetItemById(app, id)
    if !item
        return

    token := GetItemToken(item)
    if app.ui.controls.Has(token)
        UpdateCellDisplay(app, token)
}

RefreshCellByToken(app, token) {
    if app.ui.controls.Has(token)
        UpdateCellDisplay(app, token)
}

Layout(app, singleSection := "") {
    gap := app.ui.gap
    headerH := GetPanelHeaderHeight()
    
    baseCols := app.activePalette.HasOwnProp("maxCols")
        ? app.activePalette.maxCols
        : app.ui.cols
    
    if (baseCols < 1)
        baseCols := 1
    
    layout := app.activePalette.HasOwnProp("layout") ? app.activePalette.layout : "normal"
    fullCompact := app.HasOwnProp("fullCompactMode") && app.fullCompactMode
    compact := !fullCompact && app.HasOwnProp("compactMode") && app.compactMode
    characterMode := app.HasOwnProp("characterMode") && app.characterMode
    headerCompact := app.HasOwnProp("headerCompactMode") && app.headerCompactMode
    
    if characterMode
        layout := "character"
    
    if (layout = "grid")
        cols := 3
    else if (layout = "vertical")
        cols := 1
    else if (layout = "character")
        cols := 2
    else
        cols := baseCols
    
    if fullCompact {
        itemW := 24
        itemH := 24
    } else if compact {
        itemW := 120
        itemH := 22
    } else {
        itemW := app.ui.itemW
        itemH := app.ui.itemH
    }

    sectionGroups := (singleSection != "")
        ? [BuildSingleSectionGroup(app, singleSection)]
        : (layout = "character"
            ? (app.ui.HasOwnProp("characterGroups") && IsObject(app.ui.characterGroups) ? app.ui.characterGroups : BuildCharacterGroups(app))
            : BuildSectionGroups(app))

    if (singleSection = "" && layout != "character")
        ClearSectionHeaders(app)

    totalW := cols * itemW + Max(0, cols - 1) * gap
    panelIndex := 0
    visibleSections := Map()
    dockOffset := 0

    for _, group in sectionGroups {
        sectionName := group.name
        items := group.items
        characterLayout := characterMode ? BuildCharacterCardLayout(group, headerH) : 0

        g := GetOrCreateSectionGui(app, group)
        if !IsObject(g) || !SafeGetGuiHwnd(g)
            continue

        idx := 0

        for _, item in items {
            token := GetItemToken(item)
            if !app.ui.controls.Has(token)
                continue

            ctrl := app.ui.controls[token]

            if !SafeGetControlHwnd(ctrl.bg) {
                app.ui.controls.Delete(token)
                continue
            }

            if characterMode {
                currentRole := item.HasOwnProp("_normalizedCharacterRole")
                    ? item._normalizedCharacterRole
                    : NormalizeCharacterExportRole(item.HasOwnProp("role") ? item.role : "")

                slot := characterLayout.slots.Has(currentRole)
                    ? characterLayout.slots[currentRole]
                    : GetCharacterCardSlot(currentRole, headerH)
                x := slot.x
                y := slot.y
                cellW := slot.w
                cellH := slot.h
            } else {
                col := Mod(idx, cols)
                row := Floor(idx / cols)
                x := col * (itemW + gap)
                y := headerH + row * (itemH + gap)
                cellW := itemW
                cellH := itemH
            }

            try {
                ctrl.bg.Move(x, y, cellW, cellH)
            } catch {
                if app.ui.controls.Has(token)
                    app.ui.controls.Delete(token)
                continue
            }

            if characterMode {
                paintIconMode := app.HasOwnProp("paintIconMode") ? app.paintIconMode : true
                if paintIconMode {
                    paintVal := item.HasOwnProp("paint") ? item.paint : ""
                    paintIcon := ""
                    if paintVal != "" {
                        paintIcon := paintVal = "P" ? "🅟" : (paintVal = "T" ? "🆃" : "🆃🅟")
                    }
                    if paintIcon != "" {
                        if !ctrl.HasOwnProp("paintLbl") || !SafeGetControlHwnd(ctrl.paintLbl) {
                            try ctrl.paintLbl := g.AddText("x" (x + cellW - 16) " y" (y + cellH - 12) " w14 h10 cFFFFFF Background1A1A1A", paintIcon)
                        } else {
                            try {
                                ctrl.paintLbl.Move(x + cellW - 16, y + cellH - 12, 14, 10)
                                ctrl.paintLbl.Visible := true
                            }
                        }
                    } else if ctrl.HasOwnProp("paintLbl") {
                        try ctrl.paintLbl.Visible := false
                    }
                } else if ctrl.HasOwnProp("paintLbl") {
                    try ctrl.paintLbl.Visible := false
                }
            }

            if (ctrl.txt != ctrl.bg) && SafeGetControlHwnd(ctrl.txt) {
                if characterMode {
                    try ctrl.txt.Visible := false
                } else {
                    lblH := fullCompact ? 0 : (compact ? 12 : 14)
                    try ctrl.txt.Move(x + 2, y + 2, itemW - 4, lblH)
                }
            }

            idx++
        }

   
        usedRowsForSection := (idx > 0) ? Floor((idx - 1) / cols) + 1 : 1
        
        if characterMode {
            totalH := characterLayout.totalH
            panelW := characterLayout.panelW
        } else {
            totalH := IsSectionCollapsed(app.activePalette, sectionName)
                ? headerH
                : headerH + Max(itemH + gap, usedRowsForSection * (itemH + gap))
            panelW := cols * itemW + Max(0, cols - 1) * gap
        }

        if g.HasOwnProp("dragStrip") {
            stripH := Max(8, Floor(totalH * 0.1))
            try g.dragStrip.Move(0, totalH - stripH, panelW, stripH)
        }

        state := GetSectionChromeState(app, sectionName)

        if (!g.HasOwnProp("lastState") || g.lastState != state) {
            UpdateSectionPanelChrome(app, g, sectionName)
            g.lastState := state
        }

        RegisterSectionPanelDrag(app, g)

        panelIndex++
        visibleKey := group.HasOwnProp("key") ? group.key : sectionName
        visibleSections[visibleKey] := true
        
        if characterMode {
            ShowSectionPanel(app, g, group, panelIndex, panelW, totalH, dockOffset)
            if IsPaletteDocked(app.activePalette)
                dockOffset += totalH + 15
        } else {
            ShowSectionPanel(app, g, group, panelIndex, panelW, totalH, dockOffset)
            if IsPaletteDocked(app.activePalette)
                dockOffset += totalH + 15
        }
    }

    RemoveEmptySectionPanels(app, visibleSections)

    maxItems := app.activePalette.historyMax
    app.ui.rows := Ceil(maxItems / cols)
}

BuildCharacterCardLayout(group, headerH) {
    baseTopY := headerH + 8
    leftPad := 6
    rawSlots := Map()

    for _, item in group.items {
        role := item.HasOwnProp("_normalizedCharacterRole")
            ? item._normalizedCharacterRole
            : NormalizeCharacterExportRole(item.HasOwnProp("role") ? item.role : "")
        if !rawSlots.Has(role)
            rawSlots[role] := GetCharacterCardSlot(role, headerH)
    }

    if rawSlots.Count = 0
        return { slots: Map(), panelW: 120, totalH: headerH + 36 }

    minX := 999999
    minY := 999999
    maxRight := 0
    maxBottom := 0
    for _, slot in rawSlots {
        if (slot.x < minX)
            minX := slot.x
        if (slot.y < minY)
            minY := slot.y
        if (slot.x + slot.w > maxRight)
            maxRight := slot.x + slot.w
        if (slot.y + slot.h > maxBottom)
            maxBottom := slot.y + slot.h
    }

    adjustedSlots := Map()
    for role, slot in rawSlots {
        adjustedSlots[role] := {
            x: leftPad + (slot.x - minX),
            y: baseTopY + (slot.y - minY),
            w: slot.w,
            h: slot.h
        }
    }

    panelW := leftPad + (maxRight - minX) + 6
    totalH := baseTopY + (maxBottom - minY) + 8
    return { slots: adjustedSlots, panelW: panelW, totalH: totalH }
}

GetCharacterCardSlot(role, headerH) {
    topY := headerH + 8
    switch role {
        case "Mask":
            return { x: 6, y: topY + 17, w: 30, h: 24 }
        case "Outline":
            return { x: 41, y: topY, w: 30, h: 24 }
        case "Black":
            return { x: 41, y: topY + 36, w: 30, h: 24 }
        case "Base":
            return { x: 106, y: topY, w: 30, h: 24 }
        case "Shadow":
            return { x: 106, y: topY + 24, w: 30, h: 24 }
        case "2 Shadow":
            return { x: 106, y: topY + 48, w: 30, h: 24 }
        case "Highlight":
            return { x: 138, y: topY, w: 18, h: 18 }
        case "Hi Shadow":
            return { x: 138, y: topY + 22, w: 18, h: 18 }
        default:
            return { x: 106, y: topY, w: 30, h: 24 }
    }
}

HasHistoryPanels(app) {
    if !app.ui.HasOwnProp("sectionGuis")
        return false

    for _, g in app.ui.sectionGuis {
        if SafeGetGuiHwnd(g)
            return true
    }

    return false
}

DestroyHistoryPanels(app) {
    if !app.ui.HasOwnProp("sectionGuis")
        return

    for _, g in app.ui.sectionGuis
        try g.Destroy()

    app.ui.sectionGuis := Map()
    app.ui.panelDragHwnds := Map()
    app.ui.sectionByHwnd := Map()
    app.historyGui := 0
}

HideHistoryPanels(app) {
    if app.activePalette && !IsPaletteDocked(app.activePalette) {
        SaveSectionPanelPositions(app)
        SaveHistory(app)
        ShowToast(app, "💾 Section positions saved")
    }

    if !app.ui.HasOwnProp("sectionGuis")
        return

    for _, g in app.ui.sectionGuis
        try g.Hide()
}

ShowHistoryPanels(app) {
    if !app.ui.HasOwnProp("sectionGuis")
        return

    for sectionName, g in app.ui.sectionGuis {
        if SafeGetGuiHwnd(g)
            try g.Show("NA")
    }
}

PrepareSectionPanelsForRestore(app) {
    if !app.ui.HasOwnProp("sectionGuis")
        return

    for _, g in app.ui.sectionGuis {
        if IsObject(g)
            g.hasShown := false
    }
}

SaveSectionPanelPosition(app, sectionName, x, y) {
    if IsPaletteDocked(app.activePalette)
        return
    
    if app.activePalette {
        lookupKey := GetSectionId(app.activePalette, sectionName)
        if (lookupKey = "")
            lookupKey := sectionName
        if !app.activePalette.HasOwnProp("sectionPositions") || !IsObject(app.activePalette.sectionPositions)
            app.activePalette.sectionPositions := Map()
        app.activePalette.sectionPositions[lookupKey] := { x: x, y: y, w: 0, h: 0 }
    }
}

SaveSectionPanelPositions(app) {
    if !app.ui.HasOwnProp("sectionGuis")
        return

    if IsPaletteDocked(app.activePalette)
        return

    savedCount := 0
    for sectionKey, g in app.ui.sectionGuis {
        hwnd := SafeGetGuiHwnd(g)
        if hwnd && WinExist("ahk_id " hwnd) {
            try {
                WinGetPos(&x, &y, &w, &h, "ahk_id " hwnd)
                if app.activePalette {
                    lookupKey := g.HasOwnProp("positionKey") ? g.positionKey : sectionKey
                    if !app.activePalette.HasOwnProp("sectionPositions") || !IsObject(app.activePalette.sectionPositions)
                        app.activePalette.sectionPositions := Map()
                    app.activePalette.sectionPositions[lookupKey] := { x: x, y: y, w: w, h: h }
                    savedCount++
                }
            }
        }
    }
    if savedCount > 0 {
        ShowToast(app, "Saved " savedCount " positions")
        if app.activePalette && app.palettes.Has(app.activePalette.name) {
            app.palettes[app.activePalette.name] := app.activePalette
        }
    }
}
GetSectionChromeState(app, sectionName) {
    p := app.activePalette

    isTarget := GetSelectedSectionName(p) = sectionName
    isCollapsed := IsSectionCollapsed(p, sectionName)
    isLocked := IsSectionLocked(p, sectionName)
    tag := GetSectionTagColor(p, sectionName)

    return sectionName "|" isTarget "|" isCollapsed "|" isLocked "|" tag
}
UpdateSectionPanelChrome(app, g, sectionName) {
    characterMode := app.HasOwnProp("characterMode") && app.characterMode
    headerH := GetPanelHeaderHeight()

    headerCompact := app.HasOwnProp("headerCompactMode") && app.headerCompactMode
    isTarget := GetSelectedSectionName(app.activePalette) = sectionName
    tag := GetSectionTagColor(app.activePalette, sectionName)
   

    if characterMode {
        try g.tag.Move(0, 0, 14, headerH)
        try g.header.Move(14, 0, 120, headerH)
        try g.lock.Move(-1000, 0, 0, 0)
        try g.menu.Move(-1000, 0, 0, 0)
        try g.collapse.Move(-1000, 0, 0, 0)
        try g.refresh.Move(-1000, 0, 0, 0)
        try g.close.Move(-1000, 0, 0, 0)
    } 


    headerText := "  " sectionName
    isCollapsed := IsSectionCollapsed(app.activePalette, sectionName)
    isLocked := IsSectionLocked(app.activePalette, sectionName)

    try g.header.Text := headerText

    try g.header.Opt((isTarget ? "Background6E5919 cFFFFFF" : "Background323338 cFFFFFF"))
    if g.HasOwnProp("tag") && SafeGetControlHwnd(g.tag) {
        bgColor := (tag != "" ? tag : "323338")
        try g.tag.Opt("Background" bgColor)
    }
    try g.collapse.Text := isCollapsed ? "+" : "-"
    try g.lock.Text := isLocked ? "L" : "U"
    try g.lock.Opt(isLocked ? "Background8A5A2F cFFFFFF" : "Background4A3F31 cFFFFFF")
    try g.target.Text := isTarget ? "●" : "○"
    try g.target.Opt(isTarget ? "Background8B7424 cFFFFFF" : "Background4A5A31 cFFFFFF")
    try g.refresh.Opt("Background3B4A31 cFFFFFF")
    try g.menu.Opt("Background3B3D44 cFFFFFF")
    try g.collapse.Opt("Background39414A cFFFFFF")
    try g.close.Opt("Background4A4C52 cFFFFFF")


}

RefreshAllSectionChrome(app) {
    if !app.ui.HasOwnProp("sectionGuis")
        return

    for sectionKey, g in app.ui.sectionGuis {
        if SafeGetGuiHwnd(g)
            state := GetSectionChromeState(app, g.HasOwnProp("sourceSectionName") ? g.sourceSectionName : sectionKey)

            if (!g.HasOwnProp("lastState") || g.lastState != state) {
                UpdateSectionPanelChrome(app, g, g.HasOwnProp("sourceSectionName") ? g.sourceSectionName : sectionKey)
                g.lastState := state
            }
    }
}

IsPaletteDocked(p) {
    return p.HasOwnProp("guiMode") && StrLower(p.guiMode) = "docked"
}

ShouldItemComeAfter(app, left, right) {
    leftPinned := left.HasOwnProp("pinned") && left.pinned
    rightPinned := right.HasOwnProp("pinned") && right.pinned

    if (leftPinned && !rightPinned)
        return false
    if (!leftPinned && rightPinned)
        return true

    if (leftPinned && rightPinned) {
        leftOrder := left.HasOwnProp("pinOrder") ? left.pinOrder : 0
        rightOrder := right.HasOwnProp("pinOrder") ? right.pinOrder : 0
        return leftOrder > rightOrder
    }

    return false
}

GetRoleRank(app, role) {
    p := app.activePalette

    if !p.HasOwnProp("roleOrder") || p.roleOrder.Length = 0
        return 0

    for index, roleName in p.roleOrder {
        if (roleName = role)
            return index
    }

    return 999
}

InitToast(app) {
    if IsObject(app.toast.gui)
        return

    g := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20")
    g.BackColor := "323338"
    g.SetFont("s9", "Consolas")
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

    historyHwnd := SafeGetGuiHwnd(app.historyGui)
    if historyHwnd && WinExist("ahk_id " historyHwnd) {
        WinGetPos(&hx, &hy, &hw, &hh, historyHwnd)
        mon := GetMonitorFromPoint(hx + 20, hy + 20)
    } else {
        MouseGetPos(&mx, &my)
        mon := GetMonitorFromPoint(mx, my)
    }

    MonitorGetWorkArea(mon, &L, &T, &R, &B)

    app.toast.x := L + 12
    app.toast.curY := T - 20
    app.toast.endY := T + 20
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

    if (app.toast.curY < app.toast.endY)
        app.toast.curY := Min(app.toast.curY + app.toast.step, app.toast.endY)

    g.Show("x" app.toast.x " y" app.toast.curY " NoActivate")
}

StopToast(app) {
    app.toast.running := false

    if IsObject(app.toastTick)
        SetTimer(app.toastTick, 0)

    if IsObject(app.toast.gui)
        app.toast.gui.Hide()
}

HistoryClick(app, token) {
    if SafeGetGuiHwnd(app.pinMenuGui)
        try app.pinMenuGui.Hide()
    if SafeGetGuiHwnd(app.roleMenuGui)
        try app.roleMenuGui.Hide()

    isShift := GetKeyState("Shift")
    isCtrl := GetKeyState("Ctrl")

    if isShift && isCtrl {
        HandleShiftClick(app, token)
        return
    }

    if isShift {
        HandleCtrlClick(app, token)
        return
    }

    HandleNormalClick(app, token)

    item := GetItemByToken(app, token)
    if !item
        return

    DoHighlight(app, token)

    rgb := GetRGBFromHex(item.hex)
    
    if app.displayMode = "rgb" {
        copyValue := isCtrl ? item.hex : rgb
        app.lastCopyType := isCtrl ? "hex" : "rgb"
    } else {
        copyValue := isCtrl ? rgb : item.hex
        app.lastCopyType := isCtrl ? "rgb" : "hex"
    }

    A_Clipboard := copyValue
    ShowToast(app, "✔ COPIED " (app.lastCopyType = "rgb" ? "RGB: " rgb : "HEX: #" item.hex))
}

HandleShiftClick(app, token) {
    lastToken := app.ui.batchLastSelected
    if !lastToken || !app.ui.controls.Has(lastToken) {
        HandleNormalClick(app, token)
        return
    }

    tokens := GetRangeTokens(app, lastToken, token)

    for _, t in tokens {
        if app.ui.controls.Has(t) && t != token {
            app.ui.controls[t].selected := true
            UpdateCellVisual(app, t, "selected")
        }
    }

    if app.ui.controls.Has(token) {
        app.ui.controls[token].selected := true
        UpdateCellVisual(app, token, "selected")
    }

    app.ui.batchLastSelected := token
    count := GetSelectedCount(app)
    ShowToast(app, "Selected " count " color" (count > 1 ? "s" : ""))
}

HandleCtrlClick(app, token) {
    if !app.ui.controls.Has(token)
        return

    ctrl := app.ui.controls[token]
    ctrl.selected := !ctrl.selected

    UpdateCellVisual(app, token, ctrl.selected ? "selected" : "normal")

    if ctrl.selected {
        app.ui.batchLastSelected := token
    }

    count := GetSelectedCount(app)
    ShowToast(app, "Selected " count " color" (count > 1 ? "s" : ""))
}

GetSelectedCount(app) {
    count := 0
    for token, ctrl in app.ui.controls {
        if ctrl.selected {
            count++
        }
    }
    return count
}

ClearBatchSelection(app) {
    for token, ctrl in app.ui.controls {
        if ctrl.selected {
            ctrl.selected := false
            UpdateCellVisual(app, token, "normal")
        }
    }
    app.ui.batchLastSelected := ""
    app.ui.lastSingleSelected := ""
}

HandleNormalClick(app, token) {
    for tkn, ctrl in app.ui.controls {
        if ctrl.selected {
            ctrl.selected := false
            UpdateCellVisual(app, tkn, "normal")
        }
    }

    if app.ui.controls.Has(token) {
        app.ui.controls[token].selected := true
        UpdateCellVisual(app, token, "selected")
    }

    app.ui.lastSingleSelected := token
    app.ui.batchLastSelected := token
}

GetCurrentlySelected(app) {
    selected := []
    for token, ctrl in app.ui.controls {
        if ctrl.selected {
            selected.Push(token)
        }
    }
    return selected
}

ClearAllSelections(app) {
}

GetSelectedIds(app, clickedToken) {
    selectedIds := []

    if !app.ui.HasOwnProp("controls") || app.ui.controls.Count = 0
        return selectedIds

    highlightToken := app.activePalette.highlightToken
    
    if highlightToken != "" && app.ui.controls.Has(highlightToken) {
        highlightItem := GetItemByToken(app, highlightToken)
        if highlightItem && highlightItem.HasOwnProp("id")
            selectedIds.Push(highlightItem.id)
    }

    if clickedToken != "" && (!app.ui.controls.Has(highlightToken) || clickedToken != highlightToken) {
        clickedItem := GetItemByToken(app, clickedToken)
        if clickedItem && clickedItem.HasOwnProp("id") {
            alreadyAdded := false
            for id in selectedIds {
                if id = clickedItem.id {
                    alreadyAdded := true
                    break
                }
            }
            if !alreadyAdded
                selectedIds.Push(clickedItem.id)
        }
    }

    for token, ctrl in app.ui.controls {
        if ctrl.selected {
            item := GetItemByToken(app, token)
            if item && item.HasOwnProp("id")
                selectedIds.Push(item.id)
        }
    }

    return selectedIds
}

BatchTogglePin(app, ids) {
    for _, id in ids {
        item := GetItemById(app, id)
        if !item
            continue
        token := GetItemToken(item)
        TogglePin(app, token)
    }

    if SafeGetGuiHwnd(app.pinMenuGui)
        try app.pinMenuGui.Hide()
    if SafeGetGuiHwnd(app.roleMenuGui)
        try app.roleMenuGui.Hide()

    ShowToast(app, "Toggled " ids.Length " color(s)")

    if app.historyVisible
        QueueHistoryRebuild(app)
}

BatchDeleteColor(app, ids) {
    for _, id in ids {
        item := GetItemById(app, id)
        if !item
            continue
        token := GetItemToken(item)
        DeleteColor(app, token)
    }

    if SafeGetGuiHwnd(app.pinMenuGui)
        try app.pinMenuGui.Hide()
    if SafeGetGuiHwnd(app.roleMenuGui)
        try app.roleMenuGui.Hide()

    ShowToast(app, "Deleted " ids.Length " color" (ids.Length > 1 ? "s" : ""))
}

DoHighlight(app, token) {
    for tkn, ctrl in app.ui.controls {
        if ctrl.selected {
            ctrl.selected := false
            try ctrl.bg.Opt("-Border")
        }
    }

    p := app.activePalette
    item := GetItemByToken(app, token)
    if !item
        return

    oldToken := p.highlightToken
    if (oldToken != "" && oldToken != token && app.ui.controls.Has(oldToken)) {
        oldCtrl := app.ui.controls[oldToken]
        oldItem := GetItemByToken(app, oldToken)
        if oldItem && oldCtrl.HasOwnProp("txt") {
            try oldCtrl.txt.Opt("cFFFFFF")
            if (oldItem.hex != "" && StrLen(oldItem.hex) = 6)
                try oldCtrl.bg.Opt("Background" oldItem.hex)
        }
    }

    p.selectedHex := item.hex
    p.highlightHex := item.hex
    p.highlightToken := token

    tokens := GetVisibleOrderedTokens(app)
    for i, t in tokens {
        if t = token {
            app.navIndex := i
            break
        }
    }

    if !app.ui.controls.Has(token)
        return

    ctrl := app.ui.controls[token]
    if !ctrl.HasOwnProp("txt")
        return

    try {
        ctrl.txt.Opt("cFFD700")
        if (item.hex != "" && StrLen(item.hex) = 6)
            ctrl.bg.Opt("Background" item.hex)
    }
}

GetRangeTokens(app, fromToken, toToken) {
    tokens := []
    fromSection := ""
    toSection := ""

    if app.ui.controls.Has(fromToken)
        fromSection := app.ui.controls[fromToken].section
    if app.ui.controls.Has(toToken)
        toSection := app.ui.controls[toToken].section

    if (fromSection != toSection)
        return [toToken]

    sectionItems := []
    for item in app.activePalette.colors {
        itemSection := item.HasOwnProp("section") && item.section != "" ? item.section : "Default"
        if itemSection == fromSection {
            sectionItems.Push(item)
        }
    }

    fromIdx := 0
    toIdx := 0
    foundStart := false
    foundEnd := false

    Loop sectionItems.Length {
        itemToken := GetItemToken(sectionItems[A_Index])
        if itemToken == fromToken {
            fromIdx := A_Index
            foundStart := true
        }
        if itemToken == toToken {
            toIdx := A_Index
            foundEnd := true
        }
    }

    if (!foundStart || !foundEnd)
        return [toToken]

    startIdx := fromIdx
    endIdx := toIdx

    if fromIdx > toIdx {
        startIdx := toIdx
        endIdx := fromIdx
    }

    Loop endIdx - startIdx + 1 {
        idx := startIdx + A_Index - 1
        if idx >= 1 && idx <= sectionItems.Length {
            tokens.Push(GetItemToken(sectionItems[idx]))
        }
    }

    return tokens
}

GetSectionIndexMap(app) {
    sectionMap := Map()
    sectionList := []

    g := BuildSectionGroups(app)

    for _, group in g {
        for _, item in group.items {
            token := GetItemToken(item)
            if app.ui.controls.Has(token) {
                sectionMap[token] := group.name
                sectionList.Push(token)
            }
        }
    }

    return { map: sectionMap, list: sectionList }
}


OpenPinMenu(app, token, targetIds) {
    if SafeGetGuiHwnd(app.pinMenuGui)
        app.pinMenuGui.Hide()

    g := Gui("+AlwaysOnTop -Caption +ToolWindow")
    g.BackColor := "323338"
    g.SetFont("s9", "Consolas")

    label := (targetIds.Length > 1)
        ? "Pin (" targetIds.Length " colors):"
        : "Pin:"
    g.AddText("cFFFFFF", label)

    batchLabel := (targetIds.Length > 1) ? "📌 Toggle Pin" : "📌 Pin/Unpin"
    g.AddButton("w160", batchLabel)
        .OnEvent("Click", (*) => BatchTogglePin(app, targetIds))

    if targetIds.Length = 1 {
        favItem := GetItemByToken(app, targetIds[1])
        favLabel := IsFavoriteColor(app, favItem.hex) ? "⭐ Unfavorite" : "⭐ Favorite"
        g.AddButton("w160", favLabel)
            .OnEvent("Click", (*) => ToggleFavoriteFromPin(app, targetIds[1]))

        g.AddButton("w160", "◀📌 Move Pinned Left")
            .OnEvent("Click", (*) => MovePinnedColorFromMenu(app, token, -1))

        g.AddButton("w160", "📌▶ Move Pinned Right")
            .OnEvent("Click", (*) => MovePinnedColorFromMenu(app, token, 1))

        g.AddButton("w160", "🗑 Delete Color")
            .OnEvent("Click", (*) => DeleteColorFromMenu(app, token))

        g.AddButton("w160", "📦 Move To Palette...")
            .OnEvent("Click", (*) => OpenMoveColorDialog(app, token))

        g.AddButton("w160", "🧩 Move To Section...")
            .OnEvent("Click", (*) => OpenMoveSectionDialog(app, token))

        currentPaint := favItem.HasOwnProp("paint") ? favItem.paint : ""
        g.AddText("cAAAAAA", "Paint:")
        if currentPaint = "P" {
            g.AddButton("w160", "🅟 Paint")
                .OnEvent("Click", (*) => SetPaint(app, token, ""))
        } else {
            g.AddButton("w160", "🅟 Set Paint")
                .OnEvent("Click", (*) => SetPaint(app, token, "P"))
        }
        if currentPaint = "T" {
            g.AddButton("w160", "🆃 Trace")
                .OnEvent("Click", (*) => SetPaint(app, token, ""))
        } else {
            g.AddButton("w160", "🆃 Set Trace")
                .OnEvent("Click", (*) => SetPaint(app, token, "T"))
        }
        if currentPaint = "TP" {
            g.AddButton("w160", "🆃🅟 Trace-Paint")
                .OnEvent("Click", (*) => SetPaint(app, token, ""))
        } else {
            g.AddButton("w160", "🆃🅟 Set Trace-Paint")
                .OnEvent("Click", (*) => SetPaint(app, token, "TP"))
        }

        paintIconMode := app.HasOwnProp("paintIconMode") ? app.paintIconMode : true
        paintIconLabel := paintIconMode ? "🎨 Hide Paint Icons" : "🎨 Show Paint Icons"
        g.AddButton("w160", paintIconLabel)
            .OnEvent("Click", (*) => TogglePaintIconModeFromMenu(app))
    } else {
        batchDeleteLabel := (targetIds.Length > 1) ? "🗑 Delete Colors" : "🗑 Delete Color"
        g.AddButton("w160", batchDeleteLabel)
            .OnEvent("Click", (*) => BatchDeleteColor(app, targetIds))

        g.AddButton("w160", "◀📌 Move Pinned Left")
            .OnEvent("Click", (*) => BatchMovePinnedFromMenu(app, targetIds, -1))

        g.AddButton("w160", "📌▶ Move Pinned Right")
            .OnEvent("Click", (*) => BatchMovePinnedFromMenu(app, targetIds, 1))

        g.AddButton("w160", "📦 Move To Palette...")
            .OnEvent("Click", (*) => OpenMovePaletteDialog(app, targetIds))

        g.AddButton("w160", "🧩 Move To Section...")
            .OnEvent("Click", (*) => OpenMoveSectionDialog(app, "", targetIds))

        g.AddText("cAAAAAA", "Paint (" targetIds.Length " colors):")
        g.AddButton("w160", "🅟 Set Paint")
            .OnEvent("Click", (*) => BatchSetPaint(app, targetIds, "P"))
        g.AddButton("w160", "🆃 Set Trace")
            .OnEvent("Click", (*) => BatchSetPaint(app, targetIds, "T"))
        g.AddButton("w160", "🆃🅟 Set Trace-Paint")
            .OnEvent("Click", (*) => BatchSetPaint(app, targetIds, "TP"))
        g.AddButton("w160", "🅟 Clear Paint")
            .OnEvent("Click", (*) => BatchSetPaint(app, targetIds, ""))

        paintIconMode := app.HasOwnProp("paintIconMode") ? app.paintIconMode : true
        paintIconLabel := paintIconMode ? "🎨 Hide Paint Icons" : "🎨 Show Paint Icons"
        g.AddButton("w160", paintIconLabel)
            .OnEvent("Click", (*) => TogglePaintIconModeFromMenu(app))
    }

    GetCursorPosForCapture(app, &x, &y)

    g.Show("AutoSize Hide")
    g.GetPos(,, &w, &h)

    mon := GetMonitorFromPoint(x, y)
    MonitorGetWorkArea(mon, &L, &T, &R, &B)
    xPos := Min(Max(L, x + 10), R - w)
    yPos := y - h - 10
    if (yPos < T)
        yPos := Min(y + 10, B - h)

    g.Show("x" xPos " y" yPos " NoActivate")

    app.pinMenuGui := g

    if !app.HasOwnProp("pinMenuTimerFn") {
        app.pinMenuTimerFn := (*) => ClosePinMenuTimer(app)
    }
    SetTimer(app.pinMenuTimerFn, -5000)
}

ClosePinMenuTimer(app) {
    if SafeGetGuiHwnd(app.pinMenuGui) {
        try app.pinMenuGui.Destroy()
        app.pinMenuGui := 0
    }
}

ResetPinMenuTimer(app) {
    if app.HasOwnProp("pinMenuTimerFn") {
        SetTimer(app.pinMenuTimerFn, 0)
        SetTimer(app.pinMenuTimerFn, -5000)
    }
}

MovePinnedColorFromMenu(app, token, dir) {
    if SafeGetGuiHwnd(app.pinMenuGui)
        try app.pinMenuGui.Hide()
    if SafeGetGuiHwnd(app.roleMenuGui)
        try app.roleMenuGui.Hide()

    MovePinnedColor(app, token, dir)
}

BatchMovePinnedFromMenu(app, targetIds, dir) {
    if SafeGetGuiHwnd(app.pinMenuGui)
        try app.pinMenuGui.Hide()
    if SafeGetGuiHwnd(app.roleMenuGui)
        try app.roleMenuGui.Hide()

    BatchMovePinnedColor(app, targetIds, dir)
}

SetPaint(app, token, paintType) {
    if SafeGetGuiHwnd(app.pinMenuGui)
        try app.pinMenuGui.Hide()
    if SafeGetGuiHwnd(app.roleMenuGui)
        try app.roleMenuGui.Hide()

    ResetPinMenuTimer(app)

    item := GetItemByToken(app, token)
    if !item
        return

    oldPaint := item.HasOwnProp("paint") ? item.paint : ""
    item.paint := paintType

    SaveHistory(app)
    RefreshCellByToken(app, token)
}

BatchSetPaint(app, targetIds, paintType) {
    if SafeGetGuiHwnd(app.pinMenuGui)
        try app.pinMenuGui.Hide()
    if SafeGetGuiHwnd(app.roleMenuGui)
        try app.roleMenuGui.Hide()

    ResetPinMenuTimer(app)

    for token in targetIds {
        item := GetItemByToken(app, token)
        if item
            item.paint := paintType
    }

    SaveHistory(app)
    RefreshPaletteManager(app, app.paletteGui)
}

ClearPaint(app, token) {
    if SafeGetGuiHwnd(app.pinMenuGui)
        try app.pinMenuGui.Hide()
    if SafeGetGuiHwnd(app.roleMenuGui)
        try app.roleMenuGui.Hide()

    item := GetItemByToken(app, token)
    if !item
        return

    item.paint := ""

    SaveHistory(app)
    RefreshCellByToken(app, token)
}

TogglePaintIconModeFromMenu(app) {
    if SafeGetGuiHwnd(app.pinMenuGui)
        try app.pinMenuGui.Hide()
    if SafeGetGuiHwnd(app.roleMenuGui)
        try app.roleMenuGui.Hide()

    ResetPinMenuTimer(app)

    current := app.HasOwnProp("paintIconMode") ? app.paintIconMode : true
    app.paintIconMode := !current
    app.ui.generation++
    RebuildUI(app)
    ShowToast(app, "Paint Icon: " (app.paintIconMode ? "On" : "Off"))
}

DeleteColorFromMenu(app, token) {
    if SafeGetGuiHwnd(app.pinMenuGui)
        try app.pinMenuGui.Hide()
    if SafeGetGuiHwnd(app.roleMenuGui)
        try app.roleMenuGui.Hide()

    DeleteColor(app, token)
    item := GetItemByToken(app, token)
    if item && item.HasOwnProp("id") {
        RefreshCellById(app, item.id)
    }
}

OpenMoveColorDialog(app, token) {
    if SafeGetGuiHwnd(app.pinMenuGui)
        app.pinMenuGui.Hide()

    names := []
    for _, name in app.paletteOrder {
        if (name != app.activePalette.name)
            names.Push(name)
    }

    if (names.Length = 0) {
        ShowToast(app, "No other palette to move into")
        return
    }

    item := GetItemByToken(app, token)
    if !item
        return

    g := Gui("+AlwaysOnTop +ToolWindow", "Move Color")
    g.BackColor := "323338"
    g.SetFont("s9", "Consolas")
    g.AddText("cFFFFFF", "Move #" item.hex " to:")
    g.list := g.AddListBox("w220 h120", names)
    g.list.Value := 1

    btn := g.AddButton("w220", "Move")
    btn.OnEvent("Click", (*) => ConfirmMoveColor(app, token, g))

    g.Show("AutoSize Center")
}

ConfirmMoveColor(app, token, g) {
    sel := g.list.Value
    if !sel
        return

    targetName := g.list.Text
    g.Destroy()
    MoveColorToPalette(app, token, targetName)
}

OpenMovePaletteDialog(app, targetIds) {
    if SafeGetGuiHwnd(app.pinMenuGui)
        app.pinMenuGui.Hide()

    names := []
    for _, name in app.paletteOrder {
        if (name != app.activePalette.name)
            names.Push(name)
    }

    if (names.Length = 0) {
        ShowToast(app, "No other palette to move into")
        return
    }

    g := Gui("+AlwaysOnTop +ToolWindow", "Move " targetIds.Length " Colors")
    g.BackColor := "323338"
    g.SetFont("s9", "Consolas")
    g.AddText("cFFFFFF", "Move to palette:")
    g.list := g.AddListBox("w220 h120", names)
    g.list.Value := 1

    btn := g.AddButton("w220", "Move")
    btn.OnEvent("Click", (*) => ConfirmBatchMovePalette(app, targetIds, g))

    g.Show("AutoSize Center")
}

ConfirmBatchMovePalette(app, targetIds, g) {
    sel := g.list.Value
    if !sel
        return

    targetName := g.list.Text
    g.Destroy()
    
    BatchMoveColorToPalette(app, targetIds, targetName)
}

ConfirmMoveSection(app, token, g) {
    sel := g.list.Value
    if !sel
        return

    sectionName := g.list.Text
    MoveColorToSection(app, token, sectionName)
    g.Destroy()
}

ConfirmBatchMoveSection(app, targetIds, g) {
    sel := g.list.Value
    if !sel
        return

    sectionName := g.list.Text
    g.Destroy()
    
    BatchMoveColorToSection(app, targetIds, sectionName)
}

OpenMoveSectionDialog(app, token, targetIds := 0) {
    if SafeGetGuiHwnd(app.pinMenuGui)
        app.pinMenuGui.Hide()

    isBatch := IsObject(targetIds) && targetIds.Length > 1
    
    names := []
    currentSection := ""
    if isBatch {
        item := GetItemByToken(app, targetIds[1])
        currentSection := item ? GetItemSectionNameForState(item) : ""
    } else {
        currentSection := GetItemSectionNameForState(GetItemByToken(app, token))
    }
    
    for section in app.activePalette.sections {
        sectionName := IsObject(section) ? section.name : section
        if (sectionName != currentSection)
            names.Push(sectionName)
    }

    if (names.Length = 0) {
        ShowToast(app, "No other section to move into")
        return
    }

    title := isBatch ? "Move " targetIds.Length " Colors" : "Move To Section"
    g := Gui("+AlwaysOnTop", title)
    g.BackColor := "323338"
    g.SetFont("s9", "Consolas")
    g.AddText("cFFFFFF", "Move to section:")
    g.list := g.AddListBox("w220 h120", names)
    g.list.Value := 1

    btn := g.AddButton("w220", "Move")
    if isBatch {
        btn.OnEvent("Click", (*) => ConfirmBatchMoveSection(app, targetIds, g))
    } else {
        btn.OnEvent("Click", (*) => ConfirmMoveSection(app, token, g))
    }

    g.Show("AutoSize Center")
}

OpenCrossPaletteReference(app, token) {
    if SafeGetGuiHwnd(app.pinMenuGui)
        app.pinMenuGui.Hide()

    names := []
    hasFavorites := app.favorites.Length > 0
    if hasFavorites
        names.Push("⭐ Favorites")
    
    for i, name in app.paletteOrder {
        if (name != app.activePalette.name) {
            names.Push(name)
        }
    }

    if (names.Length = 0) {
        ShowToast(app, "No other palette available")
        return
    }

    g := Gui("+AlwaysOnTop +ToolWindow", "🔍 Cross-Palette Reference")
    g.BackColor := "323338"
    g.SetFont("s9", "Consolas")
    
    g.AddText("cFFFFFF", "Select palette:")
    g.paletteList := g.AddListBox("w350 h100", names)
    g.paletteList.Choose(1)
    g.paletteNames := names
    
    g.AddText("cFFFFFF xm y+10", "Tap a color row to select it:")
    g.colorList := g.AddListView("xm w350 h180 -Hdr -Multi", ["#", "HEX", "Name", "Role"])
    totalW := 350
    idxW := 80
    hexW := 140
    roleW := 100

    remaining := totalW - idxW - hexW - roleW - 10
    nameW := remaining  ; auto-fill leftover space

    g.colorList.ModifyCol(1, idxW)
    g.colorList.ModifyCol(2, hexW)
    g.colorList.ModifyCol(3, roleW)
    g.colorList.ModifyCol(4, nameW)
    
    g.previewRow := g.AddProgress("xm y+8 w30 h24 Background808080")
    g.previewHex := g.AddText("x+5 yp w100 h24 cFFFFFF", "#808080")
    g.previewRGB := g.AddText("x+10 yp w120 h24 cAAAAAA", "0,0,0")
    
    btnCopyHex := g.AddButton("xm y+8 w172 h28", "📋 Copy HEX")
    btnCopyHex.OnEvent("Click", (*) => ReferenceCopyHEX(app, g, token))
    
    btnCopyRGB := g.AddButton("x+6 w172 h28", "📋 Copy RGB")
    btnCopyRGB.OnEvent("Click", (*) => ReferenceCopyRGB(app, g, token))
    
    btnAdd := g.AddButton("xm w350 h28", "➕ Add to Current Section")
    btnAdd.OnEvent("Click", (*) => ReferenceAddToSection(app, g, token))
    
    g.AddButton("xm w350 h28", "Close").OnEvent("Click", (*) => g.Destroy())
    
    g.paletteList.OnEvent("Change", (*) => ReferenceLoadColors(app, g))
    g.colorList.OnEvent("ItemFocus", (ctrl, item) => ReferenceColorFocus(app, g, item))
    
    g.refColorMap := Map()
    ReferenceLoadColors(app, g)
    g.Show("AutoSize Center")
}

ReferenceColorFocus(app, g, item) {
    if !item
        return
    g.selectedIdx := item
    ReferenceUpdatePreview(g, item)
}

ReferenceLoadColors(app, g) {
    sel := g.paletteList.Value
    if !sel
        return
    
    name := g.paletteNames[sel]
    
    g.colorList.Delete()
    g.refColorMap := Map()
    
    idx := 0
    if (name = "⭐ Favorites") {
        for fav in app.favorites {
            idx++
            g.colorList.Add("", "#" fav.hex, fav.name, fav.role)
            g.refColorMap[idx] := fav.hex
        }
    } else {
        p := app.palettes[name]
        if !p
            return
        
        for item in p.colors {
            idx++
            g.colorList.Add("", "#" item.hex, item.name, item.role)
            g.refColorMap[idx] := item.hex
        }
    }
    
    if idx > 0 {
        g.colorList.Modify(1, "Select Focus")
        g.selectedIdx := 1
        ReferenceUpdatePreview(g, 1)
    } else {
        g.previewRow.Opt("Background808080")
        g.previewHex.Value := ""
        g.previewRGB.Value := ""
    }
}

ReferenceUpdatePreview(g, sel) {
    if !sel || !g.HasOwnProp("refColorMap") || !g.refColorMap.Has(sel)
        return
    
    hex := g.refColorMap[sel]
    if !hex
        return
    
    rgb := GetRGBFromHex(hex)
    g.previewRow.Opt("Background" hex)
    g.previewHex.Value := "#" hex
    g.previewRGB.Value := rgb
}

ReferenceCopyHEX(app, g, token) {
    sel := g.HasOwnProp("selectedIdx") ? g.selectedIdx : 0
    if !sel || !g.HasOwnProp("refColorMap")
        return
    
    hex := g.refColorMap[sel]
    if !hex
        return
    
    A_Clipboard := hex
    ShowToast(app, "✔ COPIED HEX: #" hex)
    
    if token {
        item := GetItemByToken(app, token)
        if item {
            targetSection := GetItemSectionNameForState(item)
            MoveColorToSection(app, token, targetSection)
        }
    }
}

ReferenceCopyRGB(app, g, token) {
    sel := g.HasOwnProp("selectedIdx") ? g.selectedIdx : 0
    if !sel || !g.HasOwnProp("refColorMap")
        return
    
    hex := g.refColorMap[sel]
    if !hex
        return
    
    rgb := GetRGBFromHex(hex)
    A_Clipboard := rgb
    ShowToast(app, "✔ COPIED RGB: " rgb)
    
    if token {
        item := GetItemByToken(app, token)
        if item {
            targetSection := GetItemSectionNameForState(item)
            MoveColorToSection(app, token, targetSection)
        }
    }
}

ReferenceAddToSection(app, g, token) {
    sel := g.HasOwnProp("selectedIdx") ? g.selectedIdx : 0
    if !sel || !g.HasOwnProp("refColorMap")
        return
    
    hex := g.refColorMap[sel]
    if !hex
        return
    
    targetSection := GetSelectedSectionName(app.activePalette)
    
    item := GetItemByHex(app, hex)
    if item {
        MoveColorToSection(app, GetItemToken(item), targetSection)
        ShowToast(app, "➕ Added #" hex " to " targetSection)
    } else {
        rgb := GetRGBFromHex(hex)
        newItem := CreateItem(hex, rgb, GetColorName(hex), "Base")
        newItem.section := targetSection
        newItem.isSaved := true
        Mutate(app, (p) => (
            AddSectionName(p, targetSection),
            AddColor(p, newItem)
        ))
        SaveHistory(app)
        app.ui.generation++
        RebuildUI(app)
        ShowToast(app, "➕ Added #" hex " to " targetSection)
    }
}

CreateSectionFromMenu(app, menuGui := 0) {
    if IsObject(menuGui) {
        try menuGui.Hide()
    } else if SafeGetGuiHwnd(app.roleMenuGui) {
        app.roleMenuGui.Hide()
    }

    ShowInputDialog(app, "Section name:", "New Micro Palette", (val) => CreateSectionConfirm(app, val))
}

CreateSectionConfirm(app, val) {
    sectionName := Trim(val)
    if (sectionName = "")
        return

    CreateSection(app, sectionName)
}

HistoryPanelHitTest(app, wParam, lParam, msg, hwnd) {
    return false
}

SignedLowWord(value) {
    n := value & 0xFFFF
    return (n & 0x8000) ? n - 0x10000 : n
}

SignedHighWord(value) {
    n := (value >> 16) & 0xFFFF
    return (n & 0x8000) ? n - 0x10000 : n
}

HistoryDragMouseDown(app, wParam, lParam, msg, hwnd) {
    if !app.historyVisible
        return

    if app.ui.HasOwnProp("panelDragHwnds") && app.ui.panelDragHwnds.Has(hwnd) {
        panelHwnd := app.ui.panelDragHwnds[hwnd]
        QueueSectionPanelMove(app, panelHwnd)
        return
    }

    token := GetHistoryTokenFromHwnd(app, hwnd)
    if (token = "")
        return
}

HistoryMouseMove(app, wParam, lParam, msg, hwnd) {
if app.ui.panelMove.pending {
        if !GetKeyState("LButton", "P") {
            CancelSectionPanelMove(app)
            return
        }

        MouseGetPos(&mx, &my)
        newX := mx - app.ui.panelMove.offsetX
        newY := my - app.ui.panelMove.offsetY
        
        if (newX != app.ui.panelMove.lastX || newY != app.ui.panelMove.lastY) {
            hwnd := app.ui.panelMove.hwnd
            if hwnd && WinExist("ahk_id " hwnd) {
                try DllCall(
                    "SetWindowPos",
                    "ptr", hwnd,
                    "ptr", 0,
                    "int", newX,
                    "int", newY,
                    "int", 0,
                    "int", 0,
                    "uint", 0x0015
                )
                app.ui.panelMove.lastX := newX
                app.ui.panelMove.lastY := newY
            }
        }
    }
}

HistoryDragMouseUp(app, wParam, lParam, msg, hwnd) {
    if app.ui.panelMove.pending || app.ui.panelMove.active
        FinishSectionPanelMove(app)

if app.ui.HasOwnProp("panelDragHwnds") && app.ui.panelDragHwnds.Has(hwnd) {
        panelHwnd := app.ui.panelDragHwnds[hwnd]
        FinishSectionPanelMove(app)
    }
}

GetHistoryTokenFromHwnd(app, hwnd) {
    if !hwnd
        return ""

    if !app.ui.controlHexByHwnd.Has(hwnd)
        return ""

    token := app.ui.controlHexByHwnd[hwnd]
    if !GetItemByToken(app, token)
        return ""

    return token
}

GetSectionHeaderSectionFromMouse(app) {
    MouseGetPos(,,, &hwnd, 2)
    if !hwnd || !app.ui.HasOwnProp("sectionByHwnd")
        return ""
    return app.ui.sectionByHwnd.Has(hwnd) ? app.ui.sectionByHwnd[hwnd] : ""
}

IsMouseOverSectionHeader(app) {
    return GetSectionHeaderSectionFromMouse(app) != ""
}

HandleSectionHeaderMiddleClick(app) {
    sectionName := GetSectionHeaderSectionFromMouse(app)
    if (sectionName = "")
        return false
    EditSectionNoteUI(app, sectionName)
    return true
}

GetHistoryTokenFromMouse(app) {
    MouseGetPos(,,, &hwnd, 2)
    return GetHistoryTokenFromHwnd(app, hwnd)
}

HandleHistoryMiddleClick(app) {
    token := GetHistoryTokenFromMouse(app)
    if (token = "")
        return false
    OpenRoleMenu(app, token)
    return true
}

GetHistorySectionFromHwnd(app, hwnd) {
    if !hwnd || !app.ui.HasOwnProp("sectionGuis")
        return ""

    for sectionKey, g in app.ui.sectionGuis {
        panelHwnd := SafeGetGuiHwnd(g)
        if (panelHwnd = hwnd)
            return g.HasOwnProp("sourceSectionName") ? g.sourceSectionName : sectionKey

        if SafeGetControlHwnd(g.header) = hwnd
            return g.HasOwnProp("sourceSectionName") ? g.sourceSectionName : sectionKey
        if SafeGetControlHwnd(g.tag) = hwnd
            return g.HasOwnProp("sourceSectionName") ? g.sourceSectionName : sectionKey
        if SafeGetControlHwnd(g.target) = hwnd
            return g.HasOwnProp("sourceSectionName") ? g.sourceSectionName : sectionKey
        if SafeGetControlHwnd(g.collapse) = hwnd
            return g.HasOwnProp("sourceSectionName") ? g.sourceSectionName : sectionKey
        if SafeGetControlHwnd(g.lock) = hwnd
            return g.HasOwnProp("sourceSectionName") ? g.sourceSectionName : sectionKey
        if SafeGetControlHwnd(g.close) = hwnd
            return g.HasOwnProp("sourceSectionName") ? g.sourceSectionName : sectionKey
    }

    try parent := DllCall("GetParent", "Ptr", hwnd, "Ptr")
    catch
        return ""

    if !parent
        return ""

    for sectionKey, g in app.ui.sectionGuis {
        if (SafeGetGuiHwnd(g) = parent)
            return g.HasOwnProp("sourceSectionName") ? g.sourceSectionName : sectionKey
    }

    return ""
}

QueueSectionPanelMove(app, panelHwnd) {
    if !panelHwnd || !WinExist("ahk_id " panelHwnd)
        return

    sectionName := ""
    for name, g in app.ui.sectionGuis {
        if SafeGetGuiHwnd(g) = panelHwnd {
            sectionName := g.HasOwnProp("sourceSectionName") ? g.sourceSectionName : name
            break
        }
    }

    if (sectionName != "" && IsSectionLocked(app.activePalette, sectionName)) {
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

StartQueuedSectionPanelMove(app, mx := "", my := "") {
    if !app.ui.panelMove.pending
        return

    if (mx = "" || my = "")
        MouseGetPos(&mx, &my)

    app.ui.panelMove.pending := false
    app.ui.panelMove.active := true
    app.ui.panelMove.lastMoveTick := 0

    for _, g in app.ui.sectionGuis {
        if (SafeGetGuiHwnd(g) = app.ui.panelMove.hwnd) {
            g.hasShown := true
            break
        }
    }
}

CancelSectionPanelMove(app) {
    hwnd := app.ui.panelMove.hwnd
    if hwnd
        DllCall("ReleaseCapture")
    
    if app.ui.panelMove.tickFn
        SetTimer(app.ui.panelMove.tickFn, 0)
    app.ui.panelMove.pending := false
    app.ui.panelMove.active := false
    app.ui.panelMove.hwnd := 0
    app.ui.panelMove.startMouseX := 0
    app.ui.panelMove.startMouseY := 0
    app.ui.panelMove.offsetX := 0
    app.ui.panelMove.offsetY := 0
    app.ui.panelMove.lastX := ""
    app.ui.panelMove.lastY := ""
    app.ui.panelMove.lastMoveTick := 0
    app.ui.panelMove.nextX := ""
    app.ui.panelMove.nextY := ""
}

FinishSectionPanelMove(app) {
    moved := app.ui.panelMove.active
    hwnd := app.ui.panelMove.hwnd
    CancelSectionPanelMove(app)
    if moved && !IsPaletteDocked(app.activePalette) {
        if hwnd && WinExist("ahk_id " hwnd) {
            sectionName := GetHistorySectionFromHwnd(app, hwnd)
            if (sectionName != "") {
                WinGetPos(&x, &y, &w, &h, "ahk_id " hwnd)
                if app.activePalette {
                        panelGui := ""
                        for _, panel in app.ui.sectionGuis {
                            if SafeGetGuiHwnd(panel) = hwnd {
                                panelGui := panel
                                break
                            }
                        }
                        if IsObject(panelGui) {
                            positionKey := panelGui.HasOwnProp("positionKey") ? panelGui.positionKey : sectionName
                            if !app.activePalette.HasOwnProp("sectionPositions") || !IsObject(app.activePalette.sectionPositions)
                                app.activePalette.sectionPositions := Map()
                            app.activePalette.sectionPositions[positionKey] := { x: x, y: y, w: w, h: h }
                            SaveHistory(app)
                            ShowToast(app, "💾 Section position saved: " sectionName)
                        }
                }
            }
        }
    }
}

RunSectionPanelMoveTick(app) {
    if !app.ui.panelMove.active {
        if app.ui.panelMove.tickFn
            SetTimer(app.ui.panelMove.tickFn, 0)
        return
    }

    hwnd := app.ui.panelMove.hwnd
    if !hwnd || !WinExist("ahk_id " hwnd) {
        FinishSectionPanelMove(app)
        return
    }

    newX := app.ui.panelMove.nextX
    newY := app.ui.panelMove.nextY
    if (newX = "" || newY = "")
        return

    if (newX = app.ui.panelMove.lastX && newY = app.ui.panelMove.lastY)
        return

    try DllCall(
        "SetWindowPos",
        "ptr", hwnd,
        "ptr", 0,
        "int", newX,
        "int", newY,
        "int", 0,
        "int", 0,
        "uint", 0x0015
    )
    app.ui.panelMove.lastX := newX
    app.ui.panelMove.lastY := newY
    app.ui.panelMove.lastMoveTick := A_TickCount
}

SetCursor(name) {
    cursorId := 32512

    switch name {
        case "Hand":
            cursorId := 32649
        case "SizeAll":
            cursorId := 32646
        case "Arrow":
            cursorId := 32512
    }

    cursor := DllCall("LoadCursor", "Ptr", 0, "Ptr", cursorId, "Ptr")
    if cursor
        DllCall("SetCursor", "Ptr", cursor)
}

ShowConfirmDialog(app, message, title, callback) {
    g := Gui("+AlwaysOnTop -Caption +ToolWindow +Border", title)
    g.BackColor := "323338"
    g.SetFont("s9", "Consolas")
    g.MarginX := 16

    g.AddText("cFFFFFF w280", message)
    btnOk := g.AddButton("w130 h28 y+10", "OK")
    btnCancel := g.AddButton("w130 h28 x+10", "Cancel")
    btnOk.OnEvent("Click", (*) => (callback(), g.Destroy()))
    btnCancel.OnEvent("Click", (*) => g.Destroy())

    g.Show("AutoSize Center")
}

ShowInputDialog(app, prompt, title, callback, default := "") {
    g := Gui("+AlwaysOnTop -Caption +ToolWindow +Border", title)
    g.BackColor := "323338"
    g.SetFont("s9", "Consolas")
    g.MarginX := 16

    g.AddText("cFFFFFF w280", prompt)
    input := g.AddEdit("w280 y+6", default)
    btnOk := g.AddButton("w130 h28 y+10", "OK")
    btnCancel := g.AddButton("w130 h28 x+10", "Cancel")
    btnOk.OnEvent("Click", (*) => (callback(input.Value), g.Destroy()))
    btnCancel.OnEvent("Click", (*) => g.Destroy())

    g.Show("AutoSize Center")
}

ShowChoiceDialog(app, title, prompt, items, callback) {
    g := Gui("+AlwaysOnTop -Caption +ToolWindow +Border", title)
    g.BackColor := "323338"
    g.SetFont("s9", "Consolas")
    g.MarginX := 16
    g.MarginY := 12

    g.AddText("cFFFFFF w280", prompt)
    g.list := g.AddListBox("w280 h120 y+6", items)
    g.list.Value := 1

    btnOk := g.AddButton("w130 h28 y+10", "OK")
    btnCancel := g.AddButton("w130 h28 x+10", "Cancel")
    btnOk.OnEvent("Click", (*) => (callback(g.list.Text), g.Destroy()))
    btnCancel.OnEvent("Click", (*) => g.Destroy())

    g.Show("AutoSize Center")
        
    QueueHistoryRebuild(app)
}

InitKeyboardNav(app) {
    app.navIndex := 0
    app.navSection := ""
    app.navLocked := false
    app.navVisible := Map()
}

GetVisibleOrderedTokens(app) {
    tokens := []
    groups := BuildSectionGroups(app)
    for group in groups {
        sectionName := group.name
        if IsSectionCollapsed(app.activePalette, sectionName)
            continue
        for item in group.items {
            token := GetItemToken(item)
            if app.ui.controls.Has(token)
                tokens.Push(token)
        }
    }
    return tokens
}

NavigateToToken(app, token) {
    if !app.ui.controls.Has(token)
        return

    ctrl := app.ui.controls[token]
    sectionName := ctrl.section

    if sectionName != app.navSection {
        app.navSection := sectionName
    }

    p := app.activePalette
    oldToken := p.highlightToken

    if oldToken && oldToken != "" && app.ui.controls.Has(oldToken) {
        oldCtrl := app.ui.controls[oldToken]
        oldItem := GetItemByToken(app, oldToken)
        if oldItem {
            try oldCtrl.bg.Opt("Background" oldItem.hex)
            try oldCtrl.txt.Opt("cFFFFFF")
        }
    }

    p.highlightHex := ctrl.hex
    p.highlightToken := token

    tokens := GetVisibleOrderedTokens(app)
    for i, t in tokens {
        if t = token {
            app.navIndex := i
            break
        }
    }

    try {
        ctrl.txt.Opt("cFFD700")
        if ctrl.hex != "" && StrLen(ctrl.hex) = 6
            ctrl.bg.Opt("Background" ctrl.hex)
    }
}

NavigateKeyboard(app, key) {
    if !app.historyVisible
        return

    tokens := GetVisibleOrderedTokens(app)
    if tokens.Length = 0
        return

    if app.navIndex < 1 || app.navIndex > tokens.Length
        app.navIndex := 1

    curIdx := app.navIndex
    cols := GetVisibleColCount(app)

    if key = "Left" {
        newIdx := Max(1, curIdx - 1)
    } else if key = "Right" {
        newIdx := Min(tokens.Length, curIdx + 1)
    } else if key = "Up" {
        newIdx := Max(1, curIdx - cols)
    } else if key = "Down" {
        newIdx := Min(tokens.Length, curIdx + cols)
    } else if key = "Home" {
        newIdx := 1
    } else if key = "End" {
        newIdx := tokens.Length
    } else {
        return
    }

    if newIdx = curIdx
        return

    app.navIndex := newIdx
    NavigateToToken(app, tokens[newIdx])
}

GetVisibleColCount(app) {
    p := app.activePalette
    layout := p.HasOwnProp("layout") ? p.layout : "normal"
    switch layout {
        case "grid": return 3
        case "vertical": return 1
        default: return p.maxCols > 0 ? p.maxCols : 4
    }
}

EnterSelectedColor(app) {
    if !app.historyVisible
        return

    tokens := GetVisibleOrderedTokens(app)
    if app.navIndex < 1 || app.navIndex > tokens.Length
        return

    token := tokens[app.navIndex]
    item := GetItemByToken(app, token)
    if !item
        return

    isCtrl := DllCall("GetAsyncKeyState", "Int", 0x11, "Short") < 0
    EnterSelectedColorCore(app, item, isCtrl)
}

EnterSelectedColorCore(app, item, isCtrl) {
    if isCtrl {
        rgb := HexToRGB(item.hex)
        copy := rgb.r "," rgb.g "," rgb.b
        A_Clipboard := copy
        ShowToast(app, "RGB copied: " copy)
    } else {
        A_Clipboard := "#" item.hex
        ShowToast(app, "HEX copied: #" item.hex)
    }
}

ToggleNavSelection(app) {
    if !app.historyVisible
        return

    tokens := GetVisibleOrderedTokens(app)
    if app.navIndex < 1 || app.navIndex > tokens.Length
        return

    token := tokens[app.navIndex]
    if !app.ui.controls.Has(token)
        return

    ctrl := app.ui.controls[token]
    app.ui.controls[token].selected := !ctrl.selected

    if app.ui.controls[token].selected {
        try ctrl.bg.Opt("Border")
        RefreshCellVisual(app, token)
    } else {
        try ctrl.bg.Opt("-Border")
        RefreshCellVisual(app, token)
    }
}

RefreshCellVisual(app, token) {
    if !app.ui.controls.Has(token)
        return
    ctrl := app.ui.controls[token]
    item := GetItemByToken(app, token)
    if !item
        return

    try ctrl.bg.Opt("Background" item.hex)
    UpdateCellDisplay(app, token)
}

ChangeRoleByKeyboard(app, dir) {
    if !app.historyVisible
        return

    tokens := GetVisibleOrderedTokens(app)
    if tokens.Length = 0
        return

    if app.navIndex < 1
        app.navIndex := tokens.Length
    else if app.navIndex > tokens.Length
        app.navIndex := 1

    token := tokens[app.navIndex]
    if !app.ui.controls.Has(token)
        return

    item := GetItemByToken(app, token)
    if !item
        return

    roles := app.activePalette.HasOwnProp("roleOrder")
        ? app.activePalette.roleOrder
        : DefaultRoleOrder()

    curRole := item.role != "" ? item.role : "Base"
    curIdx := 1
    for i, r in roles {
        if r = curRole {
            curIdx := i
            break
        }
    }

    newIdx := curIdx + dir
    if newIdx < 1
        newIdx := roles.Length
    else if newIdx > roles.Length
        newIdx := 1

    newRole := roles[newIdx]

    item := GetItemByToken(app, token)
    if item && item.HasOwnProp("id") {
        ApplyRoleMutationById(app.activePalette, newRole, item.id)
        RefreshCellById(app, item.id)
    }

    SaveHistory(app)
    ShowToast(app, "Role: " newRole)
}

NavigateColorCell(app, dir) {
    if !app.ui.HasOwnProp("controls") || app.ui.controls.Count = 0
        return

    tokens := GetVisibleOrderedTokens(app)
    if tokens.Length = 0
        return

    for token, ctrl in app.ui.controls {
        if ctrl.selected {
            ctrl.selected := false
            try ctrl.bg.Opt("-Border")
        }
    }

    if app.navIndex < 1
        app.navIndex := tokens.Length
    else if app.navIndex > tokens.Length
        app.navIndex := 1

    curIdx := app.navIndex
    newIdx := curIdx + dir

    if newIdx < 1
        newIdx := tokens.Length
    if newIdx > tokens.Length
        newIdx := 1

    if newIdx = curIdx
        return

app.navIndex := newIdx
    newToken := tokens[newIdx]
    
    NavigateToToken(app, newToken)
    
    if app.ui.controls.Has(newToken) {
        try {
            app.ui.controls[newToken].selected := true
            try app.ui.controls[newToken].bg.Opt("+Border")
        }
    }
}

