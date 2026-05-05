InitPalettes(app) {
    base := A_ScriptDir "\color\"
    paletteFile := base "palettes.txt"

    if FileExist(paletteFile) {
        for name in StrSplit(FileRead(paletteFile), "`n", "`r") {
            name := Trim(name)
            if (name = "")
                continue

            p := CreatePalette(name, base name ".txt")
            LoadPaletteFromFile(p)
            app.palettes[name] := p
            app.paletteOrder.Push(name)
        }

        loop files base "*.txt" {
            fname := SubStr(A_LoopFileName, 1, -4)
            if !app.palettes.Has(fname) && (fname != "palettes") {
                p := CreatePalette(fname, base fname ".txt")
                LoadPaletteFromFile(p)
                app.palettes[fname] := p
                app.paletteOrder.Push(fname)
            }
        }

        SavePaletteList(app)
        SortPaletteOrderByPriority(app)
    } else {
        defaults := ["Default", "UI", "Shadow"]

        for name in defaults {
            app.palettes[name] := CreatePalette(name, base name ".txt")
            app.paletteOrder.Push(name)
        }

        SavePaletteList(app)
    }
}

LoadPaletteFromFile(p) {
    if !FileExist(p.file)
        return

    for line in StrSplit(FileRead(p.file), "`n", "`r") {
        line := Trim(line)
        if (line = "")
            continue

        if (SubStr(line, 1, 5) = "#META") {
            if RegExMatch(line, "priority=(\d+)", &m5)
                p.priority := Integer(m5[1])
            if RegExMatch(line, "guiMode=(\w+)", &m6)
                p.guiMode := m6[1]
            continue
        }

        if (SubStr(line, 1, 10) = "#POSITION|") {
            if TryParseSectionPositionLine(line, &sectionId, &x, &y, &w, &h) {
                p.sectionPositions[sectionId] := {
                    x: x,
                    y: y,
                    w: w,
                    h: h
                }
            }
            continue
        }
        
        if (SubStr(line, 1, 9) = "#SECTION|") {
            secData := Trim(SubStr(line, 10))
            parts := StrSplit(secData, "|")
            if (parts.Length >= 2) {
                secId := Trim(parts[1])
                secName := UnescapeSectionMeta(Trim(parts[2]))
                locked := 0
                collapsed := 0
                tag := ""
                note := ""
                if (parts.Length >= 3) {
                    for i, partValue in parts {
                        if (i <= 2)
                            continue
                        if InStr(partValue, "locked=") {
                            partsKV := StrSplit(partValue, "=", , 2)
                            locked := (partsKV.Length >= 2 && Trim(partsKV[2]) = "1") ? 1 : 0
                        }
                        if InStr(partValue, "collapsed=") {
                            partsKV := StrSplit(partValue, "=", , 2)
                            collapsed := (partsKV.Length >= 2 && Trim(partsKV[2]) = "1") ? 1 : 0
                        }
                        if InStr(partValue, "tag=")
                            tag := SubStr(partValue, 5)
                        if InStr(partValue, "note=")
                            note := UnescapeSectionMeta(SubStr(partValue, 6))
                    }
                }
                if (secName != "" && !HasSectionName(p, secName)) {
                    p.sections.Push({ id: secId, name: secName, isDefault: false, locked: locked, collapsed: collapsed, tag: tag, note: note })
                }
            }
            continue
        }

        if (SubStr(line, 1, 1) = "#")
            continue

        parts := StrSplit(line, "|")
        if parts.Length < 8
            continue

        p.colors.Push({
            id: parts[8],
            hex: parts[1],
            rgb: parts[2],
            name: parts[3],
            role: parts[4],
            pinned: parts[5] = "1",
            pinOrder: Integer(parts[6]),
            section: parts[7]
        })
    }
}

SortPaletteOrderByPriority(app) {
    sorted := []
    for name, p in app.palettes {
        sorted.Push(name)
    }
    
    Loop sorted.Length {
        swapped := false
        Loop sorted.Length - A_Index {
            i := A_Index
            j := i + 1
            p1 := app.palettes[sorted[i]]
            p2 := app.palettes[sorted[j]]
            pri1 := p1.HasOwnProp("priority") ? p1.priority : 999
            pri2 := p2.HasOwnProp("priority") ? p2.priority : 999
            if pri1 > pri2 {
                temp := sorted[i]
                sorted[i] := sorted[j]
                sorted[j] := temp
                swapped := true
            }
        }
        if !swapped
            break
    }
    
    app.paletteOrder := sorted
}

SavePaletteList(app) {
    paletteFile := A_ScriptDir "\color\palettes.txt"
    DirCreate(A_ScriptDir "\color")

    f := FileOpen(paletteFile, "w")
    for name in app.paletteOrder
        f.WriteLine(name)
    f.Close()
}

CreatePalette(name, file) {
    static counter := 0
    counter++
    return {
        name: name,
        file: file,
        colors: [],
        map: Map(),
        idMap: Map(),
        selectedHex: "",
        highlightHex: "",
        highlightToken: 0,
        selectedSection: "Default",
        sections: ["Default"],
        sectionPositions: Map(),
        roleOrder: DefaultRoleOrder(),
        guiMode: "docked",
        historyMax: 20,
        maxCols: 10,
        priority: counter,
        note: ""
    }
}

CloneSectionPositions(source) {
    cloned := Map()
    if !IsObject(source)
        return cloned

    for sectionName, pos in source {
        if !IsObject(pos)
            continue
        cloned[sectionName] := {
            x: pos.HasOwnProp("x") ? Integer(pos.x) : 0,
            y: pos.HasOwnProp("y") ? Integer(pos.y) : 0,
            w: pos.HasOwnProp("w") ? Integer(pos.w) : 0,
            h: pos.HasOwnProp("h") ? Integer(pos.h) : 0
        }
    }

    return cloned
}

EscapeSectionMeta(value) {
    value := "" value
    value := StrReplace(value, "\", "\\")
    value := StrReplace(value, "|", "\p")
    value := StrReplace(value, "`r", "\r")
    value := StrReplace(value, "`n", "\n")
    return value
}

UnescapeSectionMeta(value) {
    value := "" value
    value := StrReplace(value, "\\", "\x1b")
    value := StrReplace(value, "\n", "`n")
    value := StrReplace(value, "\r", "`r")
    value := StrReplace(value, "\p", "|")
    value := StrReplace(value, "\x1b", "\")
    return value
}

NormalizeRoleOrderList(roleOrder) {
    normalized := []
    seen := Map()

    for _, role in roleOrder {
        clean := NormalizeRoleName(role)
        if (clean = "" || seen.Has(clean))
            continue
        normalized.Push(clean)
        seen[clean] := true
    }

    for _, role in DefaultRoleOrder() {
        if !seen.Has(role)
            normalized.Push(role)
    }

    return normalized
}

PersistActivePaletteState(app) {
    if !app || !app.HasOwnProp("activePalette") || !IsObject(app.activePalette)
        return

    if app.HasOwnProp("historyVisible") && app.historyVisible && !IsPaletteDocked(app.activePalette)
        SaveSectionPanelPositions(app)

    SaveHistory(app)
    if app.HasOwnProp("palettes") && app.palettes.Has(app.activePalette.name)
        app.palettes[app.activePalette.name] := app.activePalette
}

SwitchPalette(app, name) {
    if !app.palettes.Has(name)
        return

    if app.activePalette && app.activePalette.name != ""
        PersistActivePaletteState(app)

    app.activePalette := app.palettes[name]
    LoadHistory(app)
    InitHistoryGui(app)
    app.ui.cols := app.activePalette.maxCols

    app.ui.generation++
    RebuildUI(app)

    Emit(app, "history_changed")
}

CreateItem(hex, rgb, name := "", role := "Base") {
    if (name = "")
        name := GetColorName(hex)

    return {
        id: GenerateItemId(),
        hex: hex,
        rgb: rgb,
        name: name,
        role: role,
        pinned: false,
        pinOrder: 0,
        section: "Default",
        isSaved: false,
        copiedUntil: 0
    }
}

LoadHistory(app) {
    p := app.activePalette
    app.ui.generation++

    if !FileExist(p.file) {
        SaveHistory(app)
    }

    p.colors := []
    p.map := Map()
    p.idMap := Map()
    p.sections := []
    p.sectionPositions := Map()
    if !p.HasOwnProp("historyMax") || p.historyMax < 1
        p.historyMax := 30

    if !FileExist(p.file)
        return

    fileContent := FileRead(p.file)
    
    lineNum := 0
    for line in StrSplit(fileContent, "`n", "`r") {
        lineNum++
        line := Trim(line)
        if (line = "")
            continue
        
        if (SubStr(line, 1, 10) = "#POSITION|") {
            if TryParseSectionPositionLine(line, &sectionId, &x, &y, &w, &h) {
                p.sectionPositions[sectionId] := {
                    x: x,
                    y: y,
                    w: w,
                    h: h
                }
            }
            continue
        }
        
        if (SubStr(line, 1, 9) = "#SECTION|") {
            secData := Trim(SubStr(line, 10))
            parts := StrSplit(secData, "|")
            if (parts.Length >= 2) {
                secId := Trim(parts[1])
                secName := UnescapeSectionMeta(Trim(parts[2]))
                locked := 0
                collapsed := 0
                tag := ""
                note := ""
                if (parts.Length >= 3) {
                    for i, partValue in parts {
                        if (i <= 2)
                            continue
                        if InStr(partValue, "locked=") {
                            partsKV := StrSplit(partValue, "=", , 2)
                            locked := (partsKV.Length >= 2 && Trim(partsKV[2]) = "1") ? 1 : 0
                        }
                        if InStr(partValue, "collapsed=") {
                            partsKV := StrSplit(partValue, "=", , 2)
                            collapsed := (partsKV.Length >= 2 && Trim(partsKV[2]) = "1") ? 1 : 0
                        }
                        if InStr(partValue, "tag=")
                            tag := SubStr(partValue, 5)
                        if InStr(partValue, "note=")
                            note := UnescapeSectionMeta(SubStr(partValue, 6))
                    }
                }
                if (secName != "" && !HasSectionName(p, secName)) {
                    p.sections.Push({ id: secId, name: secName, isDefault: false, locked: locked, collapsed: collapsed, tag: tag, note: note })
                }
            }
            continue
        }

        part := StrSplit(line, "|")

        if (part.Length < 4 || SubStr(line, 1, 1) = "#")
            continue

        item := CreateItem(part[1], part[2], part[3], part[4])
        item.role := NormalizeRoleName(item.role)
        item.name := Trim(item.name)
        if (item.name = "")
            item.name := GetColorName(item.hex)
        item.pinned := (part.Length >= 5 && part[5] = "1")
        item.pinOrder := (part.Length >= 6) ? Integer(part[6]) : 0
        item.section := (part.Length >= 7 && part[7] != "") ? part[7] : "Default"
        item.id := (part.Length >= 8 && part[8] != "") ? part[8] : GenerateItemId()
        item.isSaved := true
        item.copiedUntil := 0

        AddSectionName(p, item.section)
        p.colors.Push(item)
        p.idMap[item.id] := item
    }

    EnsureDefaultSection(p)
    for idx, section in p.sections {
        if IsObject(section) {
            if !section.HasOwnProp("locked")
                section.locked := false
            if !section.HasOwnProp("collapsed")
                section.collapsed := false
            if !section.HasOwnProp("tag")
                section.tag := ""
            if !section.HasOwnProp("note")
                section.note := ""
        }
    }
    GetSelectedSectionName(p)
    if p.HasOwnProp("roleOrder")
        p.roleOrder := NormalizeRoleOrderList(p.roleOrder)
    if !p.HasOwnProp("sectionPositions")
        p.sectionPositions := Map()
    try {
        logLine := FormatTime(, "yyyy-MM-dd HH:mm:ss")
            . " | load palette=" p.name
            . " | sectionPositions=" p.sectionPositions.Count
            . "`r`n"
        FileAppend(logLine, "C:\tmp\section-position-debug.log", "UTF-8")
    }
}

TryParseSectionPositionLine(line, &sectionId, &x, &y, &w, &h) {
    sectionId := ""
    x := 0
    y := 0
    w := 0
    h := 0

    if (SubStr(line, 1, 10) != "#POSITION|")
        return false

    posData := Trim(SubStr(line, 11))
    parts := StrSplit(posData, "|")
    if (parts.Length < 5)
        return false

    lastIndex := parts.Length
    hText := Trim(parts[lastIndex])
    wText := Trim(parts[lastIndex - 1])
    yText := Trim(parts[lastIndex - 2])
    xText := Trim(parts[lastIndex - 3])

    if !(RegExMatch(xText, "^-?\d+$") && RegExMatch(yText, "^-?\d+$")
        && RegExMatch(wText, "^-?\d+$") && RegExMatch(hText, "^-?\d+$"))
        return false

    sectionId := Trim(parts[1])
    Loop lastIndex - 5 {
        sectionId .= "|" parts[A_Index + 1]
    }

    if (sectionId = "")
        return false

    x := Integer(xText)
    y := Integer(yText)
    w := Integer(wText)
    h := Integer(hText)
    return true
}

SaveHistory(app) {
    p := app.activePalette
    SavePalette(p, app.version)
}

SavePalette(p, version) {
    DirCreate(A_ScriptDir "\color")

    f := FileOpen(p.file, "w")
    guiMode := p.HasOwnProp("guiMode") ? p.guiMode : "undocked"
    note := p.HasOwnProp("note") ? EscapeSectionMeta(p.note) : ""
    priority := p.HasOwnProp("priority") ? p.priority : 1
    f.WriteLine("#META|version=" version "|historyMax=" p.historyMax "|maxCols=" p.maxCols "|guiMode=" guiMode "|priority=" priority "|note=" note)

    if p.HasOwnProp("roleOrder") {
        p.roleOrder := NormalizeRoleOrderList(p.roleOrder)
        f.WriteLine("#ROLEORDER|" JoinRoleOrder(p.roleOrder))
    }

    EnsureDefaultSection(p)
    for section in p.sections {
        if IsObject(section) {
            locked := section.HasOwnProp("locked") && section.locked ? 1 : 0
            collapsed := section.HasOwnProp("collapsed") && section.collapsed ? 1 : 0
            tag := section.HasOwnProp("tag") ? StrUpper(RegExReplace(section.tag, "(?i)[^0-9A-F]")) : ""
            note := section.HasOwnProp("note") ? section.note : ""
            f.WriteLine("#SECTION|" section.id "|" EscapeSectionMeta(section.name) "|locked=" locked "|collapsed=" collapsed "|tag=" tag "|note=" EscapeSectionMeta(note))
        } else {
            f.WriteLine("#SECTION|" EscapeSectionMeta(section))
        }
    }

    if p.HasOwnProp("sectionPositions") && IsObject(p.sectionPositions) {
        for sectionId, pos in p.sectionPositions {
            if !IsObject(pos)
                continue
            x := pos.HasOwnProp("x") ? Integer(pos.x) : 0
            y := pos.HasOwnProp("y") ? Integer(pos.y) : 0
            w := pos.HasOwnProp("w") ? Integer(pos.w) : 0
            h := pos.HasOwnProp("h") ? Integer(pos.h) : 0
            f.WriteLine("#POSITION|" sectionId "|" x "|" y "|" w "|" h)
        }
    }

    for item in p.colors {
        item.role := NormalizeRoleName(item.role)
        item.name := Trim(item.name)
        if (item.name = "")
            item.name := GetColorName(item.hex)
        if !item.HasOwnProp("section") || Trim(item.section) = ""
            item.section := "Default"
        f.WriteLine(item.hex "|" item.rgb "|" item.name "|" item.role "|" item.pinned "|" item.pinOrder "|" item.section "|" item.id)
    }
    f.Close()
}

JoinRoleOrder(roleOrder) {
    text := ""
    for _, role in roleOrder {
        role := Trim(role)
        if (role = "")
            continue

        text .= (text = "" ? "" : ",") role
    }
    return text
}

DefaultRoleOrder() {
    return [
        "Black",
        "Outline",
        "Mask",
        "Highlight",
        "Base",
        "Hi Shadow",
        "Shadow",
        "2 Shadow"
    ]
}

GenerateItemId() {
    static seq := 0
    seq += 1
    return A_TickCount "-" seq "-" Random(1000, 9999)
}

GenerateSectionId() {
    static seq := 0
    seq += 1
    return "s" A_TickCount "-" seq "-" Random(1000, 9999)
}
