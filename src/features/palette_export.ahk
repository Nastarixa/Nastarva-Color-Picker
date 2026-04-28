ExportActivePalette(app, format, name?, pngStyle?, showInfo?) {
    p := app.activePalette
    ext := "." format
    filters := Map(
        "txt", "Text Files (*.txt)",
        "json", "JSON Files (*.json)",
        "ini", "INI Files (*.ini)",
        "csv", "CSV Files (*.csv)",
        "png", "PNG Files (*.png)",
        "ase", "Adobe Swatch Exchange (*.ase)"
    )

    defaultName := (IsSet(name) && name != "") ? name : p.name
    path := FileSelect("S16", A_ScriptDir "\" defaultName ext, "Export Palette as " StrUpper(format), filters[format])
    if (path = "")
        return

    if (format = "png") {
        style := IsSet(pngStyle) ? pngStyle : 1
        info := IsSet(showInfo) ? showInfo : 1
        ExportPalettePng(app, p, path, style, info)
        return
    }

    content := BuildPaletteExportContent(p, app.version, format)
    if (content = "")
        return

    if FileExist(path)
        FileDelete(path)

    if (format = "ase") {
        ExportPaletteAse(app, p, path)
        return
    }

    FileAppend(content, path, "UTF-8")
    ShowToast(app, "Exported " p.name " as " StrUpper(format))
}

ExportActivePaletteCharacterSheet(app) {
    p := app.activePalette
    defaultName := p.name ".png"
    path := FileSelect("S16", A_ScriptDir "\" defaultName, "Export Character Sheet Style", "PNG Files (*.png)")
    if (path = "")
        return

    ExportPalettePngCharacter(app, p, path)
}

ExportPalettePng(app, p, path, style := 1, showInfo := 1) {
    jsonPath := A_Temp "\nastarva_palette_export.json"
    scriptPath := A_Temp "\nastarva_palette_export.ps1"

    if FileExist(jsonPath)
        FileDelete(jsonPath)
    if FileExist(scriptPath)
        FileDelete(scriptPath)

    json := BuildPaletteJson(p, app.version)
    json.Push('  "showInfo": ' showInfo ',')
    FileAppend(JoinLines(json), jsonPath, "UTF-8")

    if (style = 2) {
        FileAppend(GetPalettePngExportCharacterScript(), scriptPath, "UTF-8")
    } else {
        FileAppend(GetPalettePngExportSectionScript(), scriptPath, "UTF-8")
    }

    cmd := Format(
        'powershell -NoProfile -ExecutionPolicy Bypass -File "{}" "{}" "{}"',
        scriptPath,
        jsonPath,
        path
    )

    RunWait(cmd, , "Hide")

    if FileExist(path) {
        styleName := style = 2 ? "Character Sheet" : "Grid with Sections"
        ShowToast(app, "Exported " p.name " as PNG (" styleName ")")
    } else {
        ShowToast(app, "PNG export failed")
    }
}

ExportPalettePngCharacter(app, p, path) {
    jsonPath := A_Temp "\nastarva_palette_export_char.json"
    scriptPath := A_Temp "\nastarva_palette_export_character.ps1"

    if FileExist(jsonPath)
        FileDelete(jsonPath)
    if FileExist(scriptPath)
        FileDelete(scriptPath)

    FileAppend(BuildPaletteJson(p, app.version), jsonPath, "UTF-8")
    FileAppend(GetPalettePngExportCharacterScript(), scriptPath, "UTF-8")

    cmd := Format(
        'powershell -NoProfile -ExecutionPolicy Bypass -File "{}" "{}" "{}"',
        scriptPath,
        jsonPath,
        path
    )

    RunWait(cmd, , "Hide")

    if FileExist(path) {
        ShowToast(app, "Exported " p.name " as Character Sheet PNG")
    } else {
        ShowToast(app, "Character sheet PNG export failed")
    }
}

BuildPaletteExportContent(p, version, format) {
    switch format {
        case "txt":
            return BuildPaletteTxt(p, version)
        case "json":
            return BuildPaletteJson(p, version)
        case "ini":
            return BuildPaletteIni(p, version)
        case "csv":
            return BuildPaletteCsv(p, version)
        case "ase":
            return ""
        default:
            return ""
    }
}

BuildPaletteTxt(p, version) {
    lines := []
    lines.Push("Palette: " p.name)
    lines.Push("Version: " version)
    lines.Push("HistoryMax: " p.historyMax)
    lines.Push("MaxCols: " p.maxCols)
    lines.Push("")

    for item in p.colors
        lines.Push("#" item.hex " | " item.rgb " | " item.name " | " item.role " | pinned=" item.pinned)

    return JoinLines(lines)
}

BuildPaletteJson(p, version) {
    json := []
    json.Push("{")
    json.Push('  "name": "' JsonEscape(p.name) '",')
    json.Push('  "version": "' JsonEscape(version) '",')
    json.Push('  "historyMax": ' p.historyMax ',')
    json.Push('  "maxCols": ' p.maxCols ',')
    json.Push('  "sections": [' JoinJsonStringArray(p.sections) '],')
    json.Push('  "colors": [')

    for index, item in p.colors {
        suffix := (index < p.colors.Length) ? "," : ""
        json.Push("    {")
        json.Push('      "hex": "' JsonEscape(item.hex) '",')
        json.Push('      "rgb": "' JsonEscape(item.rgb) '",')
        json.Push('      "name": "' JsonEscape(item.name) '",')
        json.Push('      "role": "' JsonEscape(item.role) '",')
        json.Push('      "section": "' JsonEscape(item.section) '",')
        json.Push('      "pinned": ' (item.pinned ? "true" : "false"))
        json.Push("    }" suffix)
    }

    json.Push("  ]")
    json.Push("}")
    return JoinLines(json)
}

BuildPaletteIni(p, version) {
    lines := []
    lines.Push("[palette]")
    lines.Push("name=" p.name)
    lines.Push("version=" version)
    lines.Push("historyMax=" p.historyMax)
    lines.Push("maxCols=" p.maxCols)
    lines.Push("")

    for index, item in p.colors {
        section := "color" index
        lines.Push("[" section "]")
        lines.Push("hex=" item.hex)
        lines.Push("rgb=" item.rgb)
        lines.Push("name=" item.name)
        lines.Push("role=" item.role)
        lines.Push("pinned=" item.pinned)
        lines.Push("")
    }

    return JoinLines(lines)
}

BuildPaletteCsv(p, version) {
    lines := []
    lines.Push("palette,version,historyMax,maxCols,hex,rgb,name,role,pinned")

    for item in p.colors {
        lines.Push(
            CsvEscape(p.name) ","
            CsvEscape(version) ","
            p.historyMax ","
            p.maxCols ","
            CsvEscape(item.hex) ","
            CsvEscape(item.rgb) ","
            CsvEscape(item.name) ","
            CsvEscape(item.role) ","
            (item.pinned ? "1" : "0")
        )
    }

    return JoinLines(lines)
}

JoinLines(lines) {
    text := ""
    for index, line in lines
        text .= line (index < lines.Length ? "`r`n" : "")
    return text
}

JsonEscape(value) {
    value := StrReplace(value, "\", "\\")
    value := StrReplace(value, '"', '\"')
    value := StrReplace(value, "`r", "\r")
    value := StrReplace(value, "`n", "\n")
    value := StrReplace(value, "`t", "\t")
    return value
}

JoinJsonStringArray(items) {
    text := ""
    for index, item in items {
        val := IsObject(item) ? item.name : item
        text .= (index > 1 ? "," : "") '"' JsonEscape(val) '"'
    }
    return text
}

ExportPaletteAse(app, p, path) {
    sections := p.HasOwnProp("sections") ? p.sections : []
    groups := Map()
    sectionColors := Map()

    for section in sections {
        sectionName := IsObject(section) ? section.name : section
        sectionColors[sectionName] := []
    }

    for item in p.colors {
        secName := item.HasOwnProp("section") ? item.section : "Default"
        if !sectionColors.Has(secName)
            sectionColors[secName] := []
        sectionColors[secName].Push(item)
    }

    dataSize := 12
    blockCount := 0

    for secName, colors in sectionColors {
        if colors.Length = 0
            continue

        blockCount += 2
        dataSize += 2 + 4 + (StrLen(secName) + 1) * 2

        for item in colors {
            nameLen := StrLen(item.name) + 1
            dataSize += 2 + 4 + (nameLen * 2) + 4 + 8 + 12
        }
    }

    data := Buffer(dataSize)
    offset := 0

    NumPut("Int", 0x41534546, data, offset)
    offset += 4
    NumPut("Int16", 1, data, offset)
    offset += 2
    NumPut("Int16", 0, data, offset)
    offset += 2
    NumPut("Int32", blockCount, data, offset)
    offset += 4

    for secName, colors in sectionColors {
        if colors.Length = 0
            continue

        NumPut("Int16", 2, data, offset)
        offset += 2
        groupName := secName
        groupNameLen := StrLen(groupName) + 1
        groupBlockSize := (groupNameLen * 2) + 2
        NumPut("Int32", groupBlockSize, data, offset)
        offset += 4
        NumPut("Int16", groupNameLen, data, offset)
        offset += 2
        StrPut(groupName, data.Offset(offset), groupNameLen, "UTF-16")
        offset += groupNameLen * 2

        for item in colors {
            rgb := StrSplit(item.rgb, ",")
            r := Integer(rgb[1])
            gv := Integer(rgb[2])
            b := Integer(rgb[3])

            NumPut("Int16", 1, data, offset)
            offset += 2

            nameLen := StrLen(item.name) + 1
            byteLen := (nameLen * 2) + 4 + 8 + 12
            NumPut("Int32", byteLen, data, offset)
            offset += 4

            NumPut("Int16", nameLen, data, offset)
            offset += 2

            StrPut(item.name, data.Offset(offset), nameLen, "UTF-16")
            offset += nameLen * 2

            modeStr := "RGB "
            StrPut(modeStr, data.Offset(offset), 5, "UTF-16")
            offset += 8

            rf := r / 255.0
            gf := gv / 255.0
            bf := b / 255.0

            NumPut("Float", rf, data, offset)
            offset += 4
            NumPut("Float", gf, data, offset)
            offset += 4
            NumPut("Float", bf, data, offset)
            offset += 4
        }

        NumPut("Int16", 3, data, offset)
        offset += 2
        NumPut("Int32", 0, data, offset)
        offset += 4
    }

    f := FileOpen(path, "w")
    f.WriteRaw(data)
    f.Close()

    ShowToast(app, "Exported " p.name " as ASE")
}

CsvEscape(value) {
    value := StrReplace(value, '"', '""')
    return '"' value '"'
}

GetPalettePngExportScript() {
    return FileRead(A_ScriptDir "\src\features\palette_png_export.ps1")
}

GetPalettePngExportCharacterScript() {
    return FileRead(A_ScriptDir "\src\features\palette_png_export_character.ps1")
}

GetPalettePngExportSectionScript() {
    return FileRead(A_ScriptDir "\src\features\palette_png_export_sections.ps1")
}
