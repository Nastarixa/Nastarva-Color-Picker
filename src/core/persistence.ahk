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
            continue
        }
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
    value := StrReplace(value, "\n", "`n")
    value := StrReplace(value, "\r", "`r")
    value := StrReplace(value, "\p", "|")
    value := StrReplace(value, "\\", "\")
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

SwitchPalette(app, name) {
    if !app.palettes.Has(name)
        return

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

    if !FileExist(p.file)
        SaveHistory(app)

    p.colors := []
    p.map := Map()
    p.idMap := Map()
    p.sections := []
    p.sectionPositions := Map()
    if !p.HasOwnProp("historyMax") || p.historyMax < 1
        p.historyMax := 30

    if !FileExist(p.file)
        return

    for line in StrSplit(FileRead(p.file), "`n", "`r") {
        line := Trim(line)
        if (line = "")
            continue

        if (SubStr(line, 1, 5) = "#META") {
            if RegExMatch(line, "version=([\d\.]+)", &m)
                p.version := m[1]
            if RegExMatch(line, "historyMax=(\d+)", &m1)
                p.historyMax := Integer(m1[1])
            if RegExMatch(line, "maxCols=(\d+)", &m2)
                p.maxCols := Integer(m2[1])
            if RegExMatch(line, "guiMode=([A-Za-z]+)", &m3)
                p.guiMode := StrLower(m3[1])
            if RegExMatch(line, "priority=(\d+)", &m5)
                p.priority := Integer(m5[1])
            if RegExMatch(line, "note=([^|]*)", &m4)
                p.note := UnescapeSectionMeta(m4[1])
            continue
        }

        if (SubStr(line, 1, 10) = "#ROLEORDER") {
            roleOrderText := Trim(SubStr(line, 12))
            if (roleOrderText != "")
                p.roleOrder := NormalizeRoleOrderList(StrSplit(roleOrderText, ","))
            continue
        }

        if (SubStr(line, 1, 8) = "#SECTION") {
            sectionData := Trim(SubStr(line, 10))
            parts := StrSplit(sectionData, "|")
            if parts.Length >= 2 {
                sectionId := Trim(parts[1])
                sectionName := UnescapeSectionMeta(Trim(parts[2]))
                if (sectionName != "") {
                    section := {
                        id: sectionId,
                        name: sectionName,
                        isDefault: false,
                        locked: false,
                        collapsed: false,
                        tag: "",
                        note: ""
                    }
                    if (parts.Length >= 3 && InStr(parts[3], "locked="))
                        section.locked := (SubStr(parts[3], 8) = "1")
                    if (parts.Length >= 4 && InStr(parts[4], "collapsed="))
                        section.collapsed := (SubStr(parts[4], 11) = "1")
                    if (parts.Length >= 5 && InStr(parts[5], "tag="))
                        section.tag := StrUpper(RegExReplace(SubStr(parts[5], 5), "[^0-9A-F]"))
                    if (parts.Length >= 6 && InStr(parts[6], "note="))
                        section.note := UnescapeSectionMeta(SubStr(parts[6], 6))
                    p.sections.Push(section)
                }
            } else if parts.Length = 1 {
                sectionName := UnescapeSectionMeta(Trim(parts[1]))
                if (sectionName != "")
                    AddSectionName(p, sectionName)
            }
            continue
        }

        if (SubStr(line, 1, 10) = "#POSITION|") {
            posData := Trim(SubStr(line, 11))
            parts := StrSplit(posData, "|")
            if (parts.Length = 5) {
                sectionId := Trim(parts[1])
                x := Trim(parts[2]), y := Trim(parts[3]), w := Trim(parts[4]), h := Trim(parts[5])
                if (sectionId != ""
                    && RegExMatch(x, "^-?\d+$")
                    && RegExMatch(y, "^-?\d+$")
                    && RegExMatch(w, "^-?\d+$")
                    && RegExMatch(h, "^-?\d+$")
                    && Integer(y) > 50
                    && !p.sectionPositions.Has(sectionId)) {
                    p.sectionPositions[sectionId] := {
                        x: Integer(x),
                        y: Integer(y),
                        w: Integer(w),
                        h: Integer(h)
                    }
                }
            }
            continue
        }

        part := StrSplit(line, "|")

        if (part.Length < 4)
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
    p.roleOrder := NormalizeRoleOrderList(p.HasOwnProp("roleOrder") ? p.roleOrder : DefaultRoleOrder())
    if !p.HasOwnProp("sectionPositions")
        p.sectionPositions := Map()
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

    if !p.HasOwnProp("roleOrder")
        p.roleOrder := DefaultRoleOrder()
    p.roleOrder := NormalizeRoleOrderList(p.roleOrder)
    f.WriteLine("#ROLEORDER|" JoinRoleOrder(p.roleOrder))

    EnsureDefaultSection(p)
    for section in p.sections {
        if IsObject(section) {
            locked := section.HasOwnProp("locked") && section.locked ? 1 : 0
            collapsed := section.HasOwnProp("collapsed") && section.collapsed ? 1 : 0
            tag := section.HasOwnProp("tag") ? StrUpper(RegExReplace(section.tag, "[^0-9A-F]")) : ""
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
    return ["Base", "Highlight", "Shadow", "Hi Shadow", "2 Shadow"]
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
