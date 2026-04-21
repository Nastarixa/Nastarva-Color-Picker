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
    g := GetOrCreateSectionGui(app, sectionName)
    if !IsObject(g) || !SafeGetGuiHwnd(g)
        return

    if app.ui.controls.Has(item.hex)
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
    catch {
        try bg.Destroy()
        try txt.Destroy()
        return
    }

    try txt.hex := item.hex
    catch {
        try bg.Destroy()
        try txt.Destroy()
        return
    }

    try bg.OnEvent("Click", (*) => HistoryClick(app, item.hex))
    catch {
        try bg.Destroy()
        try txt.Destroy()
        return
    }

    try bg.OnEvent("ContextMenu", (*) => OpenRoleMenu(app, item.hex))
    catch {
        try bg.Destroy()
        try txt.Destroy()
        return
    }

    try txt.OnEvent("Click", (*) => HistoryClick(app, item.hex))
    catch {
        try bg.Destroy()
        try txt.Destroy()
        return
    }

    try txt.OnEvent("ContextMenu", (*) => OpenRoleMenu(app, item.hex))
    catch {
        try bg.Destroy()
        try txt.Destroy()
        return
    }

    app.ui.controls[item.hex] := { bg: bg, txt: txt, section: sectionName }
    bg.gen := app.ui.generation
    txt.gen := app.ui.generation

    bgHwnd := SafeGetControlHwnd(bg)
    txtHwnd := SafeGetControlHwnd(txt)
    if bgHwnd
        app.ui.controlHexByHwnd[bgHwnd] := item.hex
    if txtHwnd
        app.ui.controlHexByHwnd[txtHwnd] := item.hex
}

RefreshHistoryUI(app) {
    if !HasHistoryPanels(app)
        return

    ApplyHighlight(app, app.activePalette.selectedHex)

    toDelete := []

    for hex, ctrl in app.ui.controls {
        if !SafeGetControlHwnd(ctrl.bg) || !SafeGetControlHwnd(ctrl.txt) {
            toDelete.Push(hex)
            continue
        }

        if (ctrl.txt.gen != app.ui.generation)
            toDelete.Push(hex)
    }

    for _, hex in toDelete {
        if !app.ui.controls.Has(hex)
            continue

        ctrl := app.ui.controls[hex]

        bgHwnd := SafeGetControlHwnd(ctrl.bg)
        txtHwnd := SafeGetControlHwnd(ctrl.txt)

        try ctrl.bg.Destroy()
        try ctrl.txt.Destroy()

        if bgHwnd && app.ui.controlHexByHwnd.Has(bgHwnd)
            app.ui.controlHexByHwnd.Delete(bgHwnd)
        if txtHwnd && app.ui.controlHexByHwnd.Has(txtHwnd)
            app.ui.controlHexByHwnd.Delete(txtHwnd)

        app.ui.controls.Delete(hex)
    }

    for _, item in app.activePalette.colors {
        itemSection := GetItemSectionName(item)
        if app.ui.controls.Has(item.hex) && app.ui.controls[item.hex].section != itemSection {
            ctrl := app.ui.controls[item.hex]
            try ctrl.bg.Destroy()
            try ctrl.txt.Destroy()
            app.ui.controls.Delete(item.hex)
        }

        ctrl := GetOrCreateCtrl(app, item)
        if !ctrl
            continue

        if !SafeGetControlHwnd(ctrl.bg) || !SafeGetControlHwnd(ctrl.txt) {
            if app.ui.controls.Has(item.hex)
                app.ui.controls.Delete(item.hex)
            continue
        }

        text := FormatColorInfo(item, "compact")

        if item.pinned
            text := "ðŸ“Œ " text

        try ctrl.txt.Value := text
        catch {
            if app.ui.controls.Has(item.hex)
                app.ui.controls.Delete(item.hex)
            continue
        }

        isSelected := (item.hex = app.activePalette.highlightHex)

        if app.ui.drag.active && item.hex = app.ui.drag.hex {
            try ctrl.txt.Opt("Background00D7FF c000000")
        } else if app.ui.drag.active && item.hex = app.ui.drag.targetHex {
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

    for _, group in sectionGroups {
        sectionName := group.name
        items := group.items

        g := GetOrCreateSectionGui(app, sectionName)
        if !IsObject(g) || !SafeGetGuiHwnd(g)
            continue

        idx := 0

        for _, item in items {
            if !app.ui.controls.Has(item.hex)
                continue

            ctrl := app.ui.controls[item.hex]

            if !SafeGetControlHwnd(ctrl.bg) || !SafeGetControlHwnd(ctrl.txt) {
                app.ui.controls.Delete(item.hex)
                continue
            }

            col := Mod(idx, cols)
            row := Floor(idx / cols)

            x := col * (itemW + gap)
            y := headerH + row * (itemH + gap)

            try ctrl.bg.Move(x, y)
            catch {
                if app.ui.controls.Has(item.hex)
                    app.ui.controls.Delete(item.hex)
                continue
            }

            try ctrl.txt.Move(x + 10, y + 2)
            catch {
                if app.ui.controls.Has(item.hex)
                    app.ui.controls.Delete(item.hex)
                continue
            }

            idx++
        }

        usedRowsForSection := (idx > 0) ? Floor((idx - 1) / cols) + 1 : 1
        totalH := headerH + Max(itemH + gap, usedRowsForSection * (itemH + gap))
        panelIndex++
        visibleSections[sectionName] := true
        ShowSectionPanel(app, g, sectionName, panelIndex, totalW, totalH)
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

ShowSectionPanel(app, g, sectionName, panelIndex, totalW, totalH) {
    if !app.historyVisible || !SafeGetGuiHwnd(g)
        return

    MouseGetPos(&mx, &my)
    mon := GetMonitorFromPoint(mx, my)
    MonitorGetWorkArea(mon, &L, &T, &R, &B)

    totalH := Min(totalH, B - T - 40)
    headerH := GetPanelHeaderHeight()

    if app.ui.HasOwnProp("sectionPositions") && app.ui.sectionPositions.Has(sectionName) {
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

    MouseGetPos(&x, &y)
    g.Show("AutoSize x" (x + 8) " y" (y + 8) " NoActivate")
    app.roleMenuGui := g
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
    SetTimer(() => (
        app.historyVisible ? Emit(app, "history_changed") : ""
    ), -900)
}

OpenRoleMenu(app, hex) {
    app.activePalette.selectedHex := hex

    ApplyHighlight(app, hex)
    Emit(app, "history_changed")

    if app.historyVisible
        Emit(app, "history_changed")

    if SafeGetGuiHwnd(app.roleMenuGui)
        app.roleMenuGui.Hide()

    g := Gui("+AlwaysOnTop -Caption +ToolWindow")
    g.BackColor := "202020"
    g.SetFont("s10", "Consolas")

    g.AddText("cFFFFFF", "Set Role:")

    roles := ["⚫ Base","✨ Highlight","⬛ Shadow","♻️ 2 Shadow","💞 Hi Shadow"]

    for role in roles {
        btn := g.AddButton("w160", role)
        btn.OnEvent("Click", RoleClick.Bind(app, role, hex))
    }

    g.AddButton("w160", "📌 Pin/Unpin")
        .OnEvent("Click", (*) => TogglePin(app, hex))

    g.AddButton("w160", "◀📌 Move Pinned Left")
        .OnEvent("Click", (*) => MovePinnedColorFromMenu(app, hex, -1))

    g.AddButton("w160", "📌▶ Move Pinned Right")
        .OnEvent("Click", (*) => MovePinnedColorFromMenu(app, hex, 1))

    g.AddButton("w160", "🗑 Delete Color")
        .OnEvent("Click", (*) => DeleteColorFromMenu(app, hex))

    g.AddButton("w160", "📦 Move To Palette...")
        .OnEvent("Click", (*) => OpenMoveColorDialog(app, hex))

    g.AddButton("w160", "🧩 Move To Section...")
        .OnEvent("Click", (*) => OpenMoveSectionDialog(app, hex))


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

MovePinnedColorFromMenu(app, hex, dir) {
    if SafeGetGuiHwnd(app.roleMenuGui)
        app.roleMenuGui.Hide()

    MovePinnedColor(app, hex, dir)
}

DeleteColorFromMenu(app, hex) {
    if SafeGetGuiHwnd(app.roleMenuGui)
        app.roleMenuGui.Hide()

    DeleteColor(app, hex)
}

OpenMoveColorDialog(app, hex) {
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

    g := Gui("+AlwaysOnTop +ToolWindow", "Move Color")
    g.BackColor := "202020"
    g.SetFont("s10", "Consolas")
    g.AddText("cFFFFFF", "Move #" hex " to:")
    g.list := g.AddListBox("w220 h120", names)
    g.list.Value := 1

    btn := g.AddButton("w220", "Move")
    btn.OnEvent("Click", (*) => ConfirmMoveColor(app, hex, g))

    g.Show("AutoSize Center")
}

ConfirmMoveColor(app, hex, g) {
    sel := g.list.Value
    if !sel
        return

    targetName := g.list.Text
    moved := MoveColorToPalette(app, hex, targetName)

    if moved
        g.Destroy()
}

OpenMoveSectionDialog(app, hex) {
    if SafeGetGuiHwnd(app.roleMenuGui)
        app.roleMenuGui.Hide()

    EnsureDefaultSection(app.activePalette)

    g := Gui("+AlwaysOnTop +ToolWindow", "Move To Section")
    g.BackColor := "202020"
    g.SetFont("s10", "Consolas")
    g.AddText("cFFFFFF", "Move #" hex " to section:")
    g.list := g.AddListBox("w220 h140", app.activePalette.sections)
    g.list.Value := 1

    btn := g.AddButton("w220", "Move")
    btn.OnEvent("Click", (*) => ConfirmMoveSection(app, hex, g))

    g.Show("AutoSize Center")
}

ConfirmMoveSection(app, hex, g) {
    sel := g.list.Value
    if !sel
        return

    sectionName := g.list.Text
    moved := MoveColorToSection(app, hex, sectionName)

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

    hex := GetHistoryHexFromHwnd(app, hwnd)
    if (hex = "")
        return

    item := GetItemByHex(app, hex)
    if !item || !item.pinned
        return

    app.ui.drag.active := true
    app.ui.drag.hex := hex
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

    targetHex := GetHistoryHexFromHwnd(app, hwnd)
    if (targetHex = app.ui.drag.hex)
        targetHex := ""

    if (targetHex != app.ui.drag.targetHex) {
        app.ui.drag.targetHex := targetHex
        RefreshHistoryUI(app)
    }

    SetCursor(targetHex = "" ? "SizeAll" : "Hand")
}

HistoryDragMouseUp(app, wParam, lParam, msg, hwnd) {
    if app.ui.panelMove.active {
        app.ui.panelMove.active := false
        SaveSectionPanelPositions(app)
    }

    if !app.ui.drag.active
        return

    sourceHex := app.ui.drag.hex
    app.ui.drag.active := false
    app.ui.drag.hex := ""
    app.ui.drag.targetHex := ""
    SetCursor("Arrow")
    RefreshHistoryUI(app)

    targetHex := GetHistoryHexFromHwnd(app, hwnd)
    if (targetHex = "" || targetHex = sourceHex)
        return

    ReorderPinnedColorToTarget(app, sourceHex, targetHex)
}

GetHistoryHexFromHwnd(app, hwnd) {
    if !hwnd
        return ""

    if !app.ui.controlHexByHwnd.Has(hwnd)
        return ""

    hex := app.ui.controlHexByHwnd[hwnd]
    if !app.activePalette.map.Has(hex)
        return ""

    return hex
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
