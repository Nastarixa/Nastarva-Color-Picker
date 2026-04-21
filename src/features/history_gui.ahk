ToggleHistory(app) {
    app.historyVisible := !app.historyVisible

    if app.historyVisible {
        if !HasHistoryPanels(app) {
            InitHistoryGui(app)
            RebuildUI(app)
        }

        RefreshHistoryUI(app)
        Layout(app)
        ShowHistoryPanels(app)
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
    SaveSectionPanelPositions(app)
    DestroyHistoryPanels(app)

    app.ui.controls := Map()
    app.ui.sectionHeaders := Map()
    app.ui.sectionGuis := Map()
    app.ui.panelDragHwnds := Map()
    app.ui.controlHexByHwnd := Map()
    app.historyGui := 0
}

RebuildUI(app) {
    SaveSectionPanelPositions(app)

    for _, ctrl in app.ui.controls {
        try ctrl.bg.Destroy()
        try ctrl.txt.Destroy()
    }

    app.ui.controls := Map()
    app.ui.controlHexByHwnd := Map()
    app.ui.panelDragHwnds := Map()
    ClearSectionHeaders(app)
    DestroyHistoryPanels(app)
    app.ui.sectionGuis := Map()

    for _, item in app.activePalette.colors {
        CreateCell(app, item)
    }

    Layout(app)
}

CreateCell(app, item) {
    sectionName := GetItemSectionName(item)
    token := GetItemToken(item)
    g := GetOrCreateSectionGui(app, sectionName)
    if !IsObject(g) || !SafeGetGuiHwnd(g)
        return

    if app.ui.controls.Has(token)
        return

    safeHex := RegExReplace(item.hex, "[^0-9A-Fa-f]")
    if (StrLen(safeHex) != 6)
        safeHex := "808080"

    w := app.ui.itemW
    h := app.ui.itemH

    opt := "w" w " h" h " Background" safeHex " Border"

    try bg := g.AddText(opt)
    catch
        return

    try txt := g.AddText("cFFFFFF w150 Center", item.hex)
    catch {
        try bg.Destroy()
        return
    }

    try bg.hex := item.hex
    try bg.token := token
    catch {
        try bg.Destroy()
        try txt.Destroy()
        return
    }

    try txt.hex := item.hex
    try txt.token := token
    catch {
        try bg.Destroy()
        try txt.Destroy()
        return
    }

    try bg.OnEvent("Click", (*) => HistoryClick(app, token))
    catch {
        try bg.Destroy()
        try txt.Destroy()
        return
    }

    try bg.OnEvent("ContextMenu", (*) => OpenRoleMenu(app, token))
    catch {
        try bg.Destroy()
        try txt.Destroy()
        return
    }

    try txt.OnEvent("Click", (*) => HistoryClick(app, token))
    catch {
        try bg.Destroy()
        try txt.Destroy()
        return
    }

    try txt.OnEvent("ContextMenu", (*) => OpenRoleMenu(app, token))
    catch {
        try bg.Destroy()
        try txt.Destroy()
        return
    }

    app.ui.controls[token] := { bg: bg, txt: txt, section: sectionName, hex: item.hex }
    bg.gen := app.ui.generation
    txt.gen := app.ui.generation

    bgHwnd := SafeGetControlHwnd(bg)
    txtHwnd := SafeGetControlHwnd(txt)
    if bgHwnd
        app.ui.controlHexByHwnd[bgHwnd] := token
    if txtHwnd
        app.ui.controlHexByHwnd[txtHwnd] := token
}

RefreshHistoryUI(app) {
    if !HasHistoryPanels(app)
        return

    ApplyHighlight(app, app.activePalette.highlightToken ? app.activePalette.highlightToken : app.activePalette.selectedHex)

    toDelete := []

    for token, ctrl in app.ui.controls {
        if !SafeGetControlHwnd(ctrl.bg) || !SafeGetControlHwnd(ctrl.txt) {
            toDelete.Push(token)
            continue
        }

        if (ctrl.txt.gen != app.ui.generation)
            toDelete.Push(token)
    }

    for _, token in toDelete {
        if !app.ui.controls.Has(token)
            continue

        ctrl := app.ui.controls[token]

        bgHwnd := SafeGetControlHwnd(ctrl.bg)
        txtHwnd := SafeGetControlHwnd(ctrl.txt)

        try ctrl.bg.Destroy()
        try ctrl.txt.Destroy()

        if bgHwnd && app.ui.controlHexByHwnd.Has(bgHwnd)
            app.ui.controlHexByHwnd.Delete(bgHwnd)
        if txtHwnd && app.ui.controlHexByHwnd.Has(txtHwnd)
            app.ui.controlHexByHwnd.Delete(txtHwnd)

        app.ui.controls.Delete(token)
    }

    for _, item in app.activePalette.colors {
        itemSection := GetItemSectionName(item)
        token := GetItemToken(item)
        if app.ui.controls.Has(token) && app.ui.controls[token].section != itemSection {
            ctrl := app.ui.controls[token]
            try ctrl.bg.Destroy()
            try ctrl.txt.Destroy()
            app.ui.controls.Delete(token)
        }

        ctrl := GetOrCreateCtrl(app, item)
        if !ctrl
            continue

        if !SafeGetControlHwnd(ctrl.bg) || !SafeGetControlHwnd(ctrl.txt) {
            if app.ui.controls.Has(token)
                app.ui.controls.Delete(token)
            continue
        }

        text := FormatColorInfo(item, "compact")

        if item.pinned
            text := "ðŸ“Œ " text

        try ctrl.txt.Value := text
        catch {
            if app.ui.controls.Has(token)
                app.ui.controls.Delete(token)
            continue
        }

        isSelected := (GetItemToken(item) = app.activePalette.highlightToken)

        if app.ui.drag.active && token = app.ui.drag.hex {
            try ctrl.txt.Opt("Background00D7FF c000000")
        } else if app.ui.drag.active && token = app.ui.drag.targetHex {
            try ctrl.txt.Opt("Background7CFF6B c000000")
        } else if isSelected {
            try ctrl.txt.Opt("BackgroundFFD700 c000000")
        } else {
            try ctrl.txt.Opt("Background202020 cFFFFFF")
        }
    }

    Layout(app)
}

Layout(app) {
    itemW := app.ui.itemW
    itemH := app.ui.itemH
    gap := app.ui.gap
    headerH := GetPanelHeaderHeight()
    cols := app.activePalette.HasOwnProp("maxCols")
        ? app.activePalette.maxCols
        : app.ui.cols

    if (cols < 1)
        cols := 1

    sectionGroups := BuildSectionGroups(app)
    ClearSectionHeaders(app)

    totalW := cols * itemW + Max(0, cols - 1) * gap
    panelIndex := 0
    visibleSections := Map()
    dockOffset := 0

    for _, group in sectionGroups {
        sectionName := group.name
        items := group.items

        g := GetOrCreateSectionGui(app, sectionName)
        if !IsObject(g) || !SafeGetGuiHwnd(g)
            continue

        idx := 0

        for _, item in items {
            token := GetItemToken(item)
            if !app.ui.controls.Has(token)
                continue

            ctrl := app.ui.controls[token]

            if !SafeGetControlHwnd(ctrl.bg) || !SafeGetControlHwnd(ctrl.txt) {
                app.ui.controls.Delete(token)
                continue
            }

            col := Mod(idx, cols)
            row := Floor(idx / cols)

            x := col * (itemW + gap)
            y := headerH + row * (itemH + gap)

            try ctrl.bg.Move(x, y)
            catch {
                if app.ui.controls.Has(token)
                    app.ui.controls.Delete(token)
                continue
            }

            try ctrl.txt.Move(x + 10, y + 2)
            catch {
                if app.ui.controls.Has(token)
                    app.ui.controls.Delete(token)
                continue
            }

            idx++
        }

        usedRowsForSection := (idx > 0) ? Floor((idx - 1) / cols) + 1 : 1
        totalH := headerH + Max(itemH + gap, usedRowsForSection * (itemH + gap))
        panelIndex++
        visibleSections[sectionName] := true
        ShowSectionPanel(app, g, sectionName, panelIndex, totalW, totalH, dockOffset)
        if IsPaletteDocked(app.activePalette)
            dockOffset += totalH + 8
    }

    RemoveEmptySectionPanels(app, visibleSections)

    maxItems := app.activePalette.historyMax
    app.ui.rows := Ceil(maxItems / cols)
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
    app.historyGui := 0
}

HideHistoryPanels(app) {
    SaveSectionPanelPositions(app)

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

SaveSectionPanelPositions(app) {
    if !app.ui.HasOwnProp("sectionGuis")
        return

    if !app.ui.HasOwnProp("sectionPositions")
        app.ui.sectionPositions := Map()

    for sectionName, g in app.ui.sectionGuis {
        hwnd := SafeGetGuiHwnd(g)
        if hwnd && WinExist("ahk_id " hwnd) {
            try {
                WinGetPos(&x, &y, &w, &h, "ahk_id " hwnd)
                app.ui.sectionPositions[sectionName] := { x: x, y: y, w: w, h: h }
            }
        }
    }
}

GetOrCreateSectionGui(app, sectionName) {
    if !app.ui.HasOwnProp("sectionGuis")
        app.ui.sectionGuis := Map()

    if app.ui.sectionGuis.Has(sectionName) {
        g := app.ui.sectionGuis[sectionName]
        if SafeGetGuiHwnd(g)
            return g
    }

    title := sectionName
    g := Gui("+AlwaysOnTop -Caption +ToolWindow +Border", title)
    g.BackColor := "202020"
    g.SetFont("s9", "Consolas")

    g.header := g.AddText("x0 y0 h" GetPanelHeaderHeight() " Background323338 cFFFFFF +E0x20", "  " title)
    g.menu := g.AddText("y0 h" GetPanelHeaderHeight() " w24 Center Background3B3D44 cFFFFFF", "...")
    g.close := g.AddText("y0 h" GetPanelHeaderHeight() " w24 Center Background4A4C52 cFFFFFF", "x")
    g.menu.OnEvent("Click", (*) => OpenSectionMenu(app, sectionName))
    g.close.OnEvent("Click", (*) => HideSectionPanel(app, sectionName))

    app.ui.sectionGuis[sectionName] := g
    RegisterSectionPanelDrag(app, g)
    if !IsObject(app.historyGui)
        app.historyGui := g

    return g
}

ShowSectionPanel(app, g, sectionName, panelIndex, totalW, totalH, dockOffset := 0) {
    if !app.historyVisible || !SafeGetGuiHwnd(g)
        return

    MouseGetPos(&mx, &my)
    mon := GetMonitorFromPoint(mx, my)
    MonitorGetWorkArea(mon, &L, &T, &R, &B)

    totalH := Min(totalH, B - T - 40)
    headerH := GetPanelHeaderHeight()

    if IsPaletteDocked(app.activePalette) {
        showX := L + 10
        showY := Max(T, B - totalH - 25 - dockOffset)
    } else if app.ui.HasOwnProp("sectionPositions") && app.ui.sectionPositions.Has(sectionName) {
        pos := app.ui.sectionPositions[sectionName]
        showX := Max(L, Min(pos.x, R - totalW))
        showY := Max(T, Min(pos.y, B - totalH))
    } else {
        perRow := Max(1, Floor((R - L) / Max(1, totalW + 18)))
        col := Mod(panelIndex - 1, perRow)
        row := Floor((panelIndex - 1) / perRow)
        showX := L + col * (totalW + 18)
        showY := Max(T, B - totalH - 25 - row * (totalH + 34))
    }

    try g.header.Move(0, 0, totalW - 48, headerH)
    try g.menu.Move(totalW - 48, 0, 24, headerH)
    try g.close.Move(totalW - 24, 0, 24, headerH)
    try g.Show("NA x" showX " y" showY " w" totalW " h" totalH)
}

IsPaletteDocked(p) {
    return p.HasOwnProp("guiMode") && StrLower(p.guiMode) = "docked"
}

GetPanelHeaderHeight() {
    return 20
}

RegisterSectionPanelDrag(app, g) {
    if !app.ui.HasOwnProp("panelDragHwnds")
        app.ui.panelDragHwnds := Map()

    headerHwnd := SafeGetControlHwnd(g.header)
    if !headerHwnd
        return

    panelHwnd := SafeGetGuiHwnd(g)
    if panelHwnd
        app.ui.panelDragHwnds[headerHwnd] := panelHwnd
}

HideSectionPanel(app, sectionName) {
    if app.ui.HasOwnProp("sectionGuis") && app.ui.sectionGuis.Has(sectionName) {
        SaveSectionPanelPositions(app)
        try app.ui.sectionGuis[sectionName].Hide()
    }
}

OpenSectionMenu(app, sectionName) {
    if SafeGetGuiHwnd(app.roleMenuGui)
        app.roleMenuGui.Hide()

    g := Gui("+AlwaysOnTop -Caption +ToolWindow +Border")
    g.BackColor := "202020"
    g.SetFont("s9", "Consolas")

    g.AddText("xm ym w170 cFFD76A Center", sectionName)

    g.AddButton("xm y+6 w170 h26", "➕ New Section")
        .OnEvent("Click", (*) => CreateSectionFromMenu(app, g))

    g.AddButton("xm y+4 w170 h26", "✏ Rename Section")
        .OnEvent("Click", (*) => RenameSectionUI(app, sectionName, g))

    g.AddButton("xm y+4 w170 h26", "📋 Duplicate Section")
        .OnEvent("Click", (*) => DuplicateSectionUI(app, sectionName, g))

    deleteBtn := g.AddButton("xm y+4 w170 h26", "🗑 Delete Section")
    deleteBtn.OnEvent("Click", (*) => DeleteSectionUI(app, sectionName, g))

    g.hideTick := (*) => AutoHideSectionMenu(app, g)
    g.hideAfter := A_TickCount + 1200

    MouseGetPos(&x, &y)
    g.Show("AutoSize Hide")
    g.GetPos(,, &w, &h)

    mon := GetMonitorFromPoint(x, y)
    MonitorGetWorkArea(mon, &L, &T, &R, &B)
    xPos := Min(Max(L, x + 8), R - w)
    yPos := Min(Max(T, y + 8), B - h)

    g.Show("x" xPos " y" yPos " NoActivate")
    app.roleMenuGui := g
    SetTimer(g.hideTick, 100)
}

AutoHideSectionMenu(app, g) {
    if (app.roleMenuGui != g) {
        try SetTimer(g.hideTick, 0)
        return
    }

    hwnd := SafeGetGuiHwnd(g)
    if !hwnd || !WinExist("ahk_id " hwnd) {
        try SetTimer(g.hideTick, 0)
        return
    }

    MouseGetPos(&mx, &my)
    WinGetPos(&gx, &gy, &gw, &gh, "ahk_id " hwnd)

    if (mx >= gx && mx <= gx + gw && my >= gy && my <= gy + gh) {
        g.hideAfter := A_TickCount + 1200
        return
    }

    if (A_TickCount < g.hideAfter)
        return

    try SetTimer(g.hideTick, 0)
    try g.Hide()
    if (app.roleMenuGui = g)
        app.roleMenuGui := 0
}

RenameSectionUI(app, sectionName, menuGui) {
    try menuGui.Hide()

    if (sectionName = "Default") {
        ShowToast(app, "Default section cannot be renamed")
        return
    }

    result := InputBox("New section name:", "✏ Rename Section", "", sectionName)
    if (result.Result != "OK")
        return

    newName := Trim(result.Value)
    if (newName = "")
        return

    if RenameSection(app, sectionName, newName) {
        if app.ui.HasOwnProp("sectionPositions") && app.ui.sectionPositions.Has(sectionName) {
            app.ui.sectionPositions[newName] := app.ui.sectionPositions[sectionName]
            app.ui.sectionPositions.Delete(sectionName)
        }
    }
}

DuplicateSectionUI(app, sectionName, menuGui) {
    try menuGui.Hide()
    DuplicateSection(app, sectionName)
}

DeleteSectionUI(app, sectionName, menuGui) {
    try menuGui.Hide()

    if (sectionName = "Default") {
        ShowToast(app, "Default section cannot be deleted")
        return
    }

    result := MsgBox("🗑 Delete section '" sectionName "' and all colors inside it?", "Delete Section", "YesNo Icon!")
    if (result != "Yes")
        return

    if DeleteSection(app, sectionName) {
        if app.ui.HasOwnProp("sectionPositions") && app.ui.sectionPositions.Has(sectionName)
            app.ui.sectionPositions.Delete(sectionName)
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

GetItemSectionName(item) {
    return item.HasOwnProp("section") && item.section != ""
        ? item.section
        : "Default"
}

GetHoveredHistoryPanelRect(app, x, y, &hx, &hy, &hw, &hh) {
    hx := 0, hy := 0, hw := 0, hh := 0

    if !app.ui.HasOwnProp("sectionGuis")
        return false

    for _, g in app.ui.sectionGuis {
        hwnd := SafeGetGuiHwnd(g)
        if !hwnd || !WinExist("ahk_id " hwnd)
            continue

        WinGetPos(&px, &py, &pw, &ph, "ahk_id " hwnd)
        if (x >= px && x <= px + pw && y >= py && y <= py + ph) {
            hx := px, hy := py, hw := pw, hh := ph
            return true
        }
    }

    return false
}

ClearSectionHeaders(app) {
    if !app.ui.HasOwnProp("sectionHeaders")
        app.ui.sectionHeaders := Map()

    for _, header in app.ui.sectionHeaders
        try header.Destroy()

    app.ui.sectionHeaders := Map()
}

CreateSectionHeader(app, sectionName, totalW, headerH) {
    g := app.historyGui
    if !IsObject(g) || !SafeGetGuiHwnd(g)
        return 0

    title := (sectionName = "") ? "Default" : sectionName

    try header := g.AddText("x0 y0 w" totalW " h" headerH " Background303030 cFFD76A Center", "  " title)
    catch
        return 0

    app.ui.sectionHeaders[title] := header
    return header
}

BuildSectionGroups(app) {
    p := app.activePalette
    groups := []
    groupMap := Map()

    EnsureDefaultSection(p)

    for _, sectionName in p.sections {
        name := (sectionName = "") ? "Default" : sectionName
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

        groupMap[sectionName].items.Push(item)
    }

    for _, group in groups
        SortSectionItems(app, group.items)

    return groups
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

    return GetRoleRank(app, left.role) > GetRoleRank(app, right.role)
}

GetRoleRank(app, role) {
    p := app.activePalette

    if !p.HasOwnProp("roleOrder")
        p.roleOrder := DefaultRoleOrder()

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

    hx := 0, hy := 0, hw := 0, hh := 0

    historyHwnd := SafeGetGuiHwnd(app.historyGui)
    if historyHwnd && WinExist("ahk_id " historyHwnd) {
        WinGetPos(&hx, &hy, &hw, &hh, historyHwnd)
    } else {
        MouseGetPos(&mx, &my)
        mon := GetMonitorFromPoint(mx, my)
        MonitorGetWorkArea(mon, &L, &T, &R, &B)

        hx := L
        hy := B
    }

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

HistoryClick(app, token) {
    item := GetItemByToken(app, token)
    if !item
        return

    Mutate(app, (p) => (
        p.selectedHex := item.hex,
        p.highlightToken := token
    ))
    Commit(app)

    rgb := GetRGBFromHex(item.hex)

    A_Clipboard := GetKeyState("Ctrl")
        ? rgb
        : item.hex

    app.lastCopyType := GetKeyState("Ctrl") ? "rgb" : "hex"

    ShowToast(app, "✔ COPIED " (app.lastCopyType = "rgb" ? "RGB: " rgb : "HEX: #" item.hex ))
    ApplyHighlight(app, token)
    SetTimer(() => (
        app.historyVisible ? Emit(app, "history_changed") : ""
    ), -900)
}

OpenRoleMenu(app, token) {
    item := GetItemByToken(app, token)
    if !item
        return

    app.activePalette.selectedHex := item.hex
    app.activePalette.highlightToken := token

    ApplyHighlight(app, token)
    Emit(app, "history_changed")

    if app.historyVisible
        Emit(app, "history_changed")

    if SafeGetGuiHwnd(app.roleMenuGui)
        app.roleMenuGui.Hide()

    g := Gui("+AlwaysOnTop -Caption +ToolWindow")
    g.BackColor := "202020"
    g.SetFont("s10", "Consolas")

    g.AddText("cFFFFFF", "Set Role:")

    roles := app.activePalette.HasOwnProp("roleOrder")
        ? app.activePalette.roleOrder
        : DefaultRoleOrder()

    for role in roles {
        role := NormalizeRoleName(role)
        btn := g.AddButton("w160", GetRoleButtonLabel(role))
        btn.OnEvent("Click", RoleClick.Bind(app, role, token))
    }

    g.AddButton("w160", "📌 Pin/Unpin")
        .OnEvent("Click", (*) => TogglePin(app, token))

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

RoleClick(app, role, token, *) {
    ApplyRole(app, role, token)
}

MovePinnedColorFromMenu(app, token, dir) {
    if SafeGetGuiHwnd(app.roleMenuGui)
        app.roleMenuGui.Hide()

    MovePinnedColor(app, token, dir)
}

DeleteColorFromMenu(app, token) {
    if SafeGetGuiHwnd(app.roleMenuGui)
        app.roleMenuGui.Hide()

    DeleteColor(app, token)
}

OpenMoveColorDialog(app, token) {
    if SafeGetGuiHwnd(app.roleMenuGui)
        app.roleMenuGui.Hide()

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
    g.BackColor := "202020"
    g.SetFont("s10", "Consolas")
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
    moved := MoveColorToPalette(app, token, targetName)

    if moved
        g.Destroy()
}

OpenMoveSectionDialog(app, token) {
    if SafeGetGuiHwnd(app.roleMenuGui)
        app.roleMenuGui.Hide()

    EnsureDefaultSection(app.activePalette)

    item := GetItemByToken(app, token)
    if !item
        return

    g := Gui("+AlwaysOnTop +ToolWindow", "Move To Section")
    g.BackColor := "202020"
    g.SetFont("s10", "Consolas")
    g.AddText("cFFFFFF", "Move #" item.hex " to section:")
    g.list := g.AddListBox("w220 h140", app.activePalette.sections)
    g.list.Value := 1

    btn := g.AddButton("w220", "Move")
    btn.OnEvent("Click", (*) => ConfirmMoveSection(app, token, g))

    g.Show("AutoSize Center")
}

ConfirmMoveSection(app, token, g) {
    sel := g.list.Value
    if !sel
        return

    sectionName := g.list.Text
    moved := MoveColorToSection(app, token, sectionName)

    if moved
        g.Destroy()
}

CreateSectionFromMenu(app, menuGui := 0) {
    if IsObject(menuGui) {
        try menuGui.Hide()
    } else if SafeGetGuiHwnd(app.roleMenuGui) {
        app.roleMenuGui.Hide()
    }

    result := InputBox("Section name:", "New Micro Palette")
    if (result.Result != "OK")
        return

    sectionName := Trim(result.Value)
    if (sectionName = "")
        return

    CreateSection(app, sectionName)
}

HistoryPanelHitTest(app, wParam, lParam, msg, hwnd) {
    if !app.historyVisible || !app.ui.HasOwnProp("sectionGuis")
        return

    if !IsSectionPanelHwnd(app, hwnd)
        return

    x := SignedLowWord(lParam)
    y := SignedHighWord(lParam)

    try WinGetPos(&wx, &wy, &ww, &wh, "ahk_id " hwnd)
    catch
        return

    headerH := GetPanelHeaderHeight()
    closeW := 48

    if (y >= wy && y < wy + headerH && x >= wx && x < wx + ww - closeW)
        return 2
}

IsSectionPanelHwnd(app, hwnd) {
    if !hwnd
        return false

    for _, g in app.ui.sectionGuis {
        if (SafeGetGuiHwnd(g) = hwnd)
            return true
    }

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
        StartSectionPanelMove(app, panelHwnd)
        return
    }

    token := GetHistoryTokenFromHwnd(app, hwnd)
    if (token = "")
        return

    item := GetItemByToken(app, token)
    if !item || !item.pinned
        return

    app.ui.drag.active := true
    app.ui.drag.hex := token
    app.ui.drag.targetHex := ""
    SetCursor("SizeAll")
    RefreshHistoryUI(app)
}

HistoryMouseMove(app, wParam, lParam, msg, hwnd) {
    if app.ui.panelMove.active {
        MouseGetPos(&mx, &my)
        newX := mx - app.ui.panelMove.offsetX
        newY := my - app.ui.panelMove.offsetY

        try WinMove(newX, newY,,, "ahk_id " app.ui.panelMove.hwnd)
        return
    }

    if !app.ui.drag.active
        return

    targetToken := GetHistoryTokenFromHwnd(app, hwnd)
    if (targetToken = app.ui.drag.hex)
        targetToken := ""

    if (targetToken != app.ui.drag.targetHex) {
        app.ui.drag.targetHex := targetToken
        RefreshHistoryUI(app)
    }

    SetCursor(targetToken = "" ? "SizeAll" : "Hand")
}

HistoryDragMouseUp(app, wParam, lParam, msg, hwnd) {
    if app.ui.panelMove.active {
        app.ui.panelMove.active := false
        SaveSectionPanelPositions(app)
    }

    if !app.ui.drag.active
        return

    sourceToken := app.ui.drag.hex
    app.ui.drag.active := false
    app.ui.drag.hex := ""
    app.ui.drag.targetHex := ""
    SetCursor("Arrow")
    RefreshHistoryUI(app)

    targetToken := GetHistoryTokenFromHwnd(app, hwnd)
    if (targetToken = "" || targetToken = sourceToken)
        return

    ReorderPinnedColorToTarget(app, sourceToken, targetToken)
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

StartSectionPanelMove(app, panelHwnd) {
    if !panelHwnd || !WinExist("ahk_id " panelHwnd)
        return

    MouseGetPos(&mx, &my)
    WinGetPos(&wx, &wy,,, "ahk_id " panelHwnd)

    app.ui.panelMove.active := true
    app.ui.panelMove.hwnd := panelHwnd
    app.ui.panelMove.offsetX := mx - wx
    app.ui.panelMove.offsetY := my - wy
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
