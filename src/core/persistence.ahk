InitPalettes(app) {
    base := A_ScriptDir "\color\"
    file := base "palettes.txt"

    if FileExist(file) {
        for name in StrSplit(FileRead(file), "`n", "`r") {
            name := Trim(name)
            if (name = "")
                continue

            app.palettes[name] := CreatePalette(name, base name ".txt")
            app.paletteOrder.Push(name)
        }
    } else {
        defaults := ["Default", "UI", "Shadow"]

        for name in defaults {
            app.palettes[name] := CreatePalette(name, base name ".txt")
            app.paletteOrder.Push(name)
        }

        SavePaletteList(app)
    }
}

SavePaletteList(app) {
    file := A_ScriptDir "\color\palettes.txt"
    DirCreate(A_ScriptDir "\color")

    f := FileOpen(file, "w")
    for name in app.paletteOrder
        f.WriteLine(name)
    f.Close()
}

CreatePalette(name, file) {
    return {
        name: name,
        file: file,
        colors: [],
        map: Map(),
        selectedHex: "",
        highlightHex: "",
        highlightToken: 0,
        sections: ["Default"],
        roleOrder: DefaultRoleOrder(),
        historyMax: 20,
        maxCols: 10
    }
}

SwitchPalette(app, name) {
    if !app.palettes.Has(name)
        return

    app.activePalette := app.palettes[name]
    LoadHistory(app)
    app.ui.cols := app.activePalette.maxCols

    InitHistoryGui(app)

    app.ui.generation++
    RebuildUI(app)

    Emit(app, "history_changed")
}

CreateItem(hex, rgb, name := "", role := "Base") {
    if (name = "")
        name := GetColorName(hex)

    return {
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
    p.sections := []
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
            continue
        }

        if (SubStr(line, 1, 10) = "#ROLEORDER") {
            roleOrderText := Trim(SubStr(line, 12))
            if (roleOrderText != "")
                p.roleOrder := StrSplit(roleOrderText, ",")
            continue
        }

        if (SubStr(line, 1, 8) = "#SECTION") {
            sectionName := Trim(SubStr(line, 10))
            if (sectionName != "")
                AddSectionName(p, sectionName)
            continue
        }

        part := StrSplit(line, "|")

        if (part.Length < 4)
            continue

        item := CreateItem(part[1], part[2], part[3], part[4])
        item.pinned := (part.Length >= 5 && part[5] = "1")
        item.pinOrder := (part.Length >= 6) ? Integer(part[6]) : 0
        item.section := (part.Length >= 7 && part[7] != "") ? part[7] : "Default"
        item.isSaved := true
        item.copiedUntil := 0

        AddSectionName(p, item.section)
        p.colors.Push(item)
        p.map[item.hex] := item
    }

    EnsureDefaultSection(p)

    Emit(App, "history_changed")
    RebuildUI(app)
}

SaveHistory(app) {
    p := app.activePalette
    SavePalette(p, app.version)
}

SavePalette(p, version) {
    DirCreate(A_ScriptDir "\color")

    f := FileOpen(p.file, "w")
    f.WriteLine("#META|version=" version "|historyMax=" p.historyMax "|maxCols=" p.maxCols)

    if !p.HasOwnProp("roleOrder")
        p.roleOrder := DefaultRoleOrder()
    f.WriteLine("#ROLEORDER|" JoinRoleOrder(p.roleOrder))

    EnsureDefaultSection(p)
    for section in p.sections
        f.WriteLine("#SECTION|" section)

    for item in p.colors
        f.WriteLine(item.hex "|" item.rgb "|" item.name "|" item.role "|" item.pinned "|" item.pinOrder "|" item.section)
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
