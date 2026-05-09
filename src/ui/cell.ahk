CreateCell(app, item) {
    sectionName := GetItemSectionName(item)
    
    token := GetItemToken(item)
    groupTarget := sectionName
    if app.HasOwnProp("characterMode") && app.characterMode
        if app.ui.HasOwnProp("characterGroupByToken") && app.ui.characterGroupByToken.Has(token)
            groupTarget := app.ui.characterGroupByToken[token]

    g := GetOrCreateSectionGui(app, groupTarget)
    if !IsObject(g) || !SafeGetGuiHwnd(g)
        return

    if app.ui.controls.Has(token)
        return

    safeHex := RegExReplace(item.hex, "[^0-9A-Fa-f]")
    if (StrLen(safeHex) != 6)
        safeHex := "808080"

    fullCompact := app.HasOwnProp("fullCompactMode") && app.fullCompactMode
    characterMode := app.HasOwnProp("characterMode") && app.characterMode
    compact := !fullCompact && app.HasOwnProp("compactMode") && app.compactMode
    
    if characterMode {
        role := item.HasOwnProp("role") && item.role != "" ? item.role : "Base"
        if role = "Highlight" || role = "Hi Shadow" {
            w := 15
            h := 15
        } else if role = "Base" || role = "Shadow" || role = "2 Shadow" {
            w := 35
            h := 20
        } else {
            w := 35
            h := 20
        }
    } else if fullCompact {
        w := 24
        h := 24
    } else if compact {
        w := 120
        h := 22
    } else {
        w := app.ui.itemW
        h := app.ui.itemH
    }
    
    g.SetFont(fullCompact ? "s7" : (compact ? "s8" : "s9"), "Consolas")

    try bg := g.AddText("w" w " h" h " Background" safeHex " Border")
    catch
        return

    if !fullCompact && !characterMode {
        paintIconMode := app.HasOwnProp("paintIconMode") ? app.paintIconMode : true
        paintIcon := ""
        if paintIconMode && item.HasOwnProp("paint") && item.paint != "" {
            paintIcon := item.paint = "P" ? "🅟 " : (item.paint = "T" ? "🆃 " : "🆃🅟 ")
        }
        if compact {
            text := (item.HasOwnProp("pinned") && item.pinned ? "📌 " : "") paintIcon FormatColorInfo(item, "compact", app)
        } else {
            text := FormatColorInfo(item, "compact", app)
            prefix := ""
            if (item.HasOwnProp("pinned") && item.pinned)
                prefix := "📌 "
            text := prefix paintIcon text
        }
        
        lblH := compact ? 12 : 14
        try txt := g.AddText("cFFFFFF w" w " h" lblH " Background1A1A1A Center", text)
        catch {
            try bg.Destroy()
            return
        }
    }

    try bg.hex := item.hex, bg.token := token
    catch {
        try bg.Destroy()
        if !fullCompact && !characterMode
            try txt.Destroy()
        return
    }

    if !fullCompact && !characterMode {
        try txt.hex := item.hex, txt.token := token
        catch {
            try bg.Destroy()
            try txt.Destroy()
            return
        }
    }

    try bg.OnEvent("Click", (*) => HistoryClick(app, token))
    catch
        return
    try bg.OnEvent("ContextMenu", (*) => OpenPinMenu(app, token, GetSelectedIds(app, token)))
    catch
        return
    if !fullCompact && !characterMode {
        try txt.OnEvent("Click", (*) => HistoryClick(app, token))
        catch
            return
        try txt.OnEvent("ContextMenu", (*) => OpenPinMenu(app, token, GetSelectedIds(app, token)))
        catch
            return
    }

    sectionId := GetSectionId(app.activePalette, sectionName)
    app.ui.controls[token] := {
        bg: bg,
        txt: (fullCompact || characterMode) ? bg : txt,
        section: sectionName,
        sectionId: sectionId,
        hex: item.hex,
        selected: false
    }

    bg.gen := app.ui.generation
    if !fullCompact && !characterMode
        txt.gen := app.ui.generation

    bgHwnd := SafeGetControlHwnd(bg)
    if bgHwnd
        app.ui.controlHexByHwnd[bgHwnd] := token
    if !fullCompact && !characterMode {
        txtHwnd := SafeGetControlHwnd(txt)
        if txtHwnd
            app.ui.controlHexByHwnd[txtHwnd] := token
    }
}

UpdateCellDisplay(app, token) {
    if !app.ui.controls.Has(token)
        return

    ctrl := app.ui.controls[token]
    if !ctrl.HasOwnProp("bg")
        return
    if !SafeGetControlHwnd(ctrl.bg)
        return

    item := GetItemByToken(app, token)
    if !item
        return

    fullCompact := app.HasOwnProp("fullCompactMode") && app.fullCompactMode
    characterMode := app.HasOwnProp("characterMode") && app.characterMode
    safeHex := RegExReplace(item.hex, "[^0-9A-Fa-f]")
    if (StrLen(safeHex) != 6)
        safeHex := "808080"
    
    try ctrl.bg.Opt("Background" safeHex)
    
    if !fullCompact && !characterMode && SafeGetControlHwnd(ctrl.txt) {
        compact := app.HasOwnProp("compactMode") && app.compactMode
        paintIconMode := app.HasOwnProp("paintIconMode") ? app.paintIconMode : true
        paintIcon := ""
        if paintIconMode && item.HasOwnProp("paint") && item.paint != "" {
            paintIcon := item.paint = "P" ? "🅟 " : (item.paint = "T" ? "🆃 " : "🆃🅟 ")
        }
        if compact {
            text := (item.HasOwnProp("pinned") && item.pinned ? "📌 " : "") paintIcon FormatColorInfo(item, "compact", app)
        } else {
            text := FormatColorInfo(item, "compact", app)
            prefix := ""
            if (item.HasOwnProp("pinned") && item.pinned)
                prefix := "📌 "
            text := prefix paintIcon text
        }
        try ctrl.txt.Value := text
    }
}

UpdateCellVisual(app, token, state) {
    if !app.ui.controls.Has(token)
        return

    ctrl := app.ui.controls[token]
    if (state = "selected") {
        try ctrl.bg.Opt("+Border")
        if SafeGetControlHwnd(ctrl.txt)
            try ctrl.txt.Opt("cFFD700")
    } else {
        try ctrl.bg.Opt("-Border")
        if SafeGetControlHwnd(ctrl.txt)
            try ctrl.txt.Opt("cFFFFFF")
    }
}

RefreshCellSelection(app) {
}

GetItemSectionName(item) {
    return item.HasOwnProp("section") && item.section != "" ? item.section : "Default"
}

GetOrCreateSectionGui(app, sectionOrName) {
    if !app.ui.HasOwnProp("sectionGuis")
        app.ui.sectionGuis := Map()
    if !app.ui.HasOwnProp("sectionByHwnd")
        app.ui.sectionByHwnd := Map()

    sectionName := IsObject(sectionOrName) ? sectionOrName.name : sectionOrName
    sectionKey := IsObject(sectionOrName) && sectionOrName.HasOwnProp("key")
        ? sectionOrName.key
        : sectionName
    sourceSectionName := IsObject(sectionOrName) && sectionOrName.HasOwnProp("sourceSection") && sectionOrName.sourceSection != ""
        ? sectionOrName.sourceSection
        : sectionName
    positionKey := IsObject(sectionOrName) && sectionOrName.HasOwnProp("positionKey")
        ? sectionOrName.positionKey
        : ""
    if (positionKey = "") {
        sectionId := GetSectionId(app.activePalette, sourceSectionName)
        positionKey := sectionId != "" ? sectionId : sectionKey
    }
    characterMode := app.HasOwnProp("characterMode") && app.characterMode
    headerH := GetPanelHeaderHeight()

    if app.ui.sectionGuis.Has(sectionKey) {
        g := app.ui.sectionGuis[sectionKey]
        if SafeGetGuiHwnd(g)
            return g
        try g.Destroy()
        app.ui.sectionGuis.Delete(sectionKey)
    }

    title := sectionName
    g := Gui("+AlwaysOnTop -Caption +ToolWindow +Border", title)
    g.BackColor := "323338"
    g.SetFont("s9", "Consolas")

    headerH := GetPanelHeaderHeight()
    headerCompact := app.HasOwnProp("headerCompactMode") && app.headerCompactMode
    characterMode := app.HasOwnProp("characterMode") && app.characterMode
    
    tagColor := GetSectionTagColor(app.activePalette, sourceSectionName)
    tagBg := (tagColor != "" ? tagColor : "323338")

        g.tag := g.AddText("x0 y0 w14 h" headerH " Background" tagBg)
 
    g.header := g.AddText("x14 y0 h" headerH " 0x200 Background323338 cFFFFFF", "  " title)
    g.headerContainer := g.AddText("x14 y0 w148 h" headerH " BackgroundTrans")
    
    g.target := g.AddText("y0 w24 h" headerH " Center 0x200 Background4A5A31 cFFFFFF", "○")
    g.lock := g.AddText("y0 w24 h" headerH " Center 0x200 Background4A3F31 cFFFFFF", "U")
    g.SetFont("s12", "Consolas")
    g.refresh := g.AddText("y0 w24 h" headerH " Center 0x200 Background3B4A31 cFFFFFF", "↻")
    g.SetFont("s12", "Consolas")
    g.collapse := g.AddText("y0 w24 h" headerH " Center 0x200 Background39414A cFFFFFF", "-")
    g.SetFont("s15", "Consolas")
    g.menu := g.AddText("y0 w24 h" headerH " Center 0x200 Background3B3D44 cFFFFFF", "⋯")
    g.SetFont("s10", "Consolas")
    g.close := g.AddText("y0 w24 h" headerH " Center 0x200 Background39414A cFFFFFF", "x")
    
    g.tag.OnEvent("Click", (*) => SetSelectedSection(app, sourceSectionName))
    g.header.OnEvent("Click", (*) => SetSelectedSection(app, sourceSectionName))
    g.tag.OnEvent("DoubleClick", (*) => EditSectionNoteUI(app, sourceSectionName))
    g.header.OnEvent("DoubleClick", (*) => EditSectionNoteUI(app, sourceSectionName))
    g.tag.OnEvent("ContextMenu", (*) => OpenSectionMenu(app, sourceSectionName))
    g.header.OnEvent("ContextMenu", (*) => OpenSectionMenu(app, sourceSectionName))
    g.target.OnEvent("Click", (*) => SetSelectedSection(app, sourceSectionName))
    g.collapse.OnEvent("Click", (*) => ToggleSectionCollapsed(app, sourceSectionName))
    g.lock.OnEvent("Click", (*) => ToggleSectionLock(app, sourceSectionName))
    g.menu.OnEvent("Click", (*) => OpenSectionMenu(app, sourceSectionName))
    g.refresh.OnEvent("Click", (*) => RefreshSectionFromHeader(app, sourceSectionName))
    g.close.OnEvent("Click", (*) => HideSectionPanel(app, sectionKey))
    


    try g.target.Visible := true
    try g.header.Visible := true
    try g.tag.Visible := true
    try g.headerContainer.Visible := true

    if characterMode {
        try g.tag.Move(0, 0, 14, headerH)
        try g.header.Move(14, 0, 120, headerH)
        try g.lock.Visible := false
        try g.menu.Visible := false
        try g.collapse.Visible := false
        try g.refresh.Visible := false
        try g.close.Visible := false
    } else {
        try g.lock.Visible := true
        try g.menu.Visible := true
        try g.collapse.Visible := true
        try g.refresh.Visible := true
        try g.close.Visible := true
    }

    g.hasShown := false

    for _, ctrl in [g.tag, g.header, g.target, g.lock, g.refresh, g.menu, g.collapse, g.close] {
        try {
            hwnd := SafeGetControlHwnd(ctrl)
            if hwnd && !app.ui.sectionByHwnd.Has(hwnd)
                app.ui.sectionByHwnd[hwnd] := sourceSectionName
        }
    }

    g.dragStrip := g.AddText("x0 y9999 w100 h8 Background424348")
    g.dragStrip.OnEvent("Click", (*) => SetSelectedSection(app, sourceSectionName))
    g.sectionKey := sectionKey
    g.sourceSectionName := sourceSectionName
    g.positionKey := positionKey

    app.ui.sectionGuis[sectionKey] := g
    return g
}

HideSectionPanel(app, sectionName) {
    g := GetOrCreateSectionGui(app, sectionName)
    hwnd := SafeGetGuiHwnd(g)
    if hwnd {
        try app.ui.panelDragHwnds.Delete(hwnd)
        try g.Hide()
    }
}

SetSectionActive(app, sectionName) {
    if IsObject(sectionName)
        sectionName := sectionName.name
    if app.HasOwnProp("sectionMenuGui") && SafeGetGuiHwnd(app.sectionMenuGui)
        try app.sectionMenuGui.Hide()
    SetSelectedSection(app, sectionName, true)
}

GetPanelHeaderHeight() {
    global App
    compact := App.HasOwnProp("headerCompactMode") && App.headerCompactMode
    return compact ? 14 : 24
}

GetSectionPositionKey(app, sectionOrName) {
    paletteName := (app.activePalette && app.activePalette.HasOwnProp("name")) ? app.activePalette.name : ""
    sectionName := IsObject(sectionOrName) && sectionOrName.HasOwnProp("positionKey")
        ? sectionOrName.positionKey
        : (IsObject(sectionOrName) ? sectionOrName.name : sectionOrName)
    return paletteName "|" sectionName
}

LogSectionPanelRestoreDebug(app, sectionName, positionKey, legacyPositionKey, matchedKey, showX, showY, totalW, totalH) {
    try {
        logPath := "C:\tmp\section-position-debug.log"
        paletteName := (app.activePalette && app.activePalette.HasOwnProp("name")) ? app.activePalette.name : ""
        line := FormatTime(, "yyyy-MM-dd HH:mm:ss")
            . " | palette=" paletteName
            . " | section=" sectionName
            . " | key=" positionKey
            . " | legacy=" legacyPositionKey
            . " | matched=" matchedKey
            . " | x=" showX
            . " | y=" showY
            . " | w=" totalW
            . " | h=" totalH
            . "`r`n"
        FileAppend(line, logPath, "UTF-8")
    }
}

ShowSectionPanel(app, g, sectionOrName, panelIndex, totalW, totalH, dockOffset := 0, xOffset := 0) {
    sectionName := IsObject(sectionOrName) ? sectionOrName.name : sectionOrName
    if !app.historyVisible || !SafeGetGuiHwnd(g)
        return

    MouseGetPos(&mx, &my)
    mon := GetMonitorFromPoint(mx, my)
    MonitorGetWorkArea(mon, &L, &T, &R, &B)

    totalH := Min(totalH, B - T - 40)

    isDocked := IsPaletteDocked(app.activePalette)

    characterMode := app.HasOwnProp("characterMode") && app.characterMode
    positionKey := IsObject(sectionOrName) && sectionOrName.HasOwnProp("positionKey")
        ? sectionOrName.positionKey
        : (g.HasOwnProp("positionKey") ? g.positionKey : sectionName)

    legacyPositionKey := g.HasOwnProp("sourceSectionName") ? g.sourceSectionName : sectionName
    matchedKey := "default"

    if isDocked {
        showX := L + 10 + xOffset
        showY := Max(T, B - totalH - 25 - dockOffset)
        matchedKey := "docked"
    } else if app.activePalette.HasOwnProp("sectionPositions") && app.activePalette.sectionPositions.Has(positionKey) {
        pos := app.activePalette.sectionPositions[positionKey]
        showX := pos.x
        showY := pos.y
        matchedKey := positionKey
    } else if app.activePalette.HasOwnProp("sectionPositions") && app.activePalette.sectionPositions.Has(legacyPositionKey) {
        pos := app.activePalette.sectionPositions[legacyPositionKey]
        showX := pos.x
        showY := pos.y
        matchedKey := legacyPositionKey
    } else {
        showX := L + 10 + xOffset
        showY := Max(T, B - totalH - 25)
    }

    if (totalW = 0)
        totalW := 200

    headerH := GetPanelHeaderHeight()
    btnW := 24
    btnCount := 6
    rightWidth := btnW * btnCount

    characterMode := app.HasOwnProp("characterMode") && app.characterMode
    tagW := 14
    try g.tag.Move(0, 0, tagW, headerH)
    if characterMode {
        try g.header.Move(14, 0, 140, headerH)
    } else {
        try g.header.Move(14, 0, totalW - (14 + rightWidth), headerH)
    }

    x := totalW - btnW
    try g.close.Move(x, 0, btnW, headerH)
    x -= btnW
    try g.menu.Move(x, 0, btnW, headerH)
    x -= btnW
    try g.collapse.Move(x, 0, btnW, headerH)
    x -= btnW
    try g.refresh.Move(x, 0, btnW, headerH)
    x -= btnW
    try g.lock.Move(x, 0, btnW, headerH)
    x -= btnW
        if characterMode {
        try g.target.Move(140, 0, btnW, headerH)
    } else {
        try g.target.Move(x, 0, btnW, headerH)
    }

        try g.Show("x" showX " y" showY " w" totalW " h" totalH)
    LogSectionPanelRestoreDebug(app, sectionName, positionKey, legacyPositionKey, matchedKey, showX, showY, totalW, totalH)

    g.hasShown := true
}
