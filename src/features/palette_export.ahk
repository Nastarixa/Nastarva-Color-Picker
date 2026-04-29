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
    path := FileSelect("S", A_ScriptDir "\" defaultName ext, "Export Palette as " StrUpper(format), filters[format])
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

ExportActivePaletteCharacterSheet(app, showInfo := 1) {
    p := app.activePalette
    defaultName := p.name ".png"
    path := FileSelect("S", A_ScriptDir "\" defaultName, "Export Character Sheet Style", "PNG Files (*.png)")
    if (path = "")
        return

    ExportPalettePngCharacter(app, p, path, showInfo)
}

ExportPalettePng(app, p, path, style := 1, showInfo := 1) {
    jsonPath := A_Temp . "\nastarxa_palette_export.json"
    scriptPath := A_Temp . "\nastarxa_palette_export.ps1"

    ; Validate palette has colors
    if (!p.HasOwnProp("colors") || !p.colors.Length) {
        ShowToast(app, "No colors to export")
        return
    }

    if (style = 2)
        scriptContent := FileRead(A_ScriptDir . "\src\features\palette_png_export_character.ps1")
    else
        scriptContent := FileRead(A_ScriptDir . "\src\features\palette_png_export_sections.ps1")

    if (scriptContent = "") {
        ShowToast(app, "Export script missing")
        return
    }

    ; Clean up old files
    if FileExist(scriptPath)
        FileDelete(scriptPath)
    if FileExist(jsonPath)
        FileDelete(jsonPath)

    json := BuildPaletteJson(p, app.version)
    
    if (json = "") {
        ShowToast(app, "Failed: empty JSON")
        return
    }
    
    ; Inject showInfo before the closing brace so JSON stays valid
    showInfoKey := Chr(34) . "showInfo" . Chr(34)
    originalJson := json
    json := StrReplace(json, "`r`n}", ",`r`n  " . showInfoKey . ": " . showInfo . "`r`n}")
    if (json = originalJson)
        json := StrReplace(json, "`n}", ",`n  " . showInfoKey . ": " . showInfo . "`n}")

    if !InStr(json, "showInfo") || (json = originalJson) {
        ShowToast(app, "JSON format issue")
        return
    }

    FileAppend(json, jsonPath, "UTF-8")
    FileAppend(scriptContent, scriptPath, "UTF-8")

    ; Verify files created
    Sleep 100
    if !FileExist(jsonPath) {
        ShowToast(app, "JSON file error")
        return
    }
    if !FileExist(scriptPath) {
        ShowToast(app, "Script file error")
        return
    }

    q := Chr(34)
    psArgs := "-NoProfile -ExecutionPolicy Bypass -File "
        . q scriptPath q " "
        . q jsonPath q " "
        . q path q
    RunWait("powershell.exe " psArgs, , "Hide")

    Sleep 500

    Sleep 300

    if FileExist(path) {
        ShowToast(app, "Exported " p.name)
    } else {
        ShowToast(app, "Export failed")
    }
}

ExportPalettePngCharacter(app, p, path, showInfo := 1) {
    jsonPath := A_Temp . "\nastarxa_palette_export_char.json"
    scriptPath := A_Temp . "\nastarxa_palette_export_character.ps1"

    scriptContent := GetPalettePngExportCharacterScript()
    if (scriptContent = "") {
        ShowToast(app, "Export script missing")
        return
    }

    if FileExist(jsonPath)
        FileDelete(jsonPath)
    if FileExist(scriptPath)
        FileDelete(scriptPath)

    json := BuildPaletteJson(p, app.version)
    if (json = "" || !InStr(json, "colors")) {
        ShowToast(app, "Export failed: no colors")
        return
    }

    json := SubStr(json, 1, -1) . ",`n  `"showInfo`": " . showInfo . "`n}"

    FileAppend(json, jsonPath, "UTF-8")
    FileAppend(scriptContent, scriptPath, "UTF-8")

    if !FileExist(jsonPath) || !FileExist(scriptPath) {
        ShowToast(app, "File creation failed")
        return
    }

    q := Chr(34)
    psArgs := "-NoProfile -ExecutionPolicy Bypass -File "
        . q scriptPath q " "
        . q jsonPath q " "
        . q path q

    RunWait("powershell.exe " psArgs, , "Hide")

    Sleep 500

    if FileExist(path)
        ShowToast(app, "Exported " p.name)
    else
        ShowToast(app, "Export failed")
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
    q := Chr(34)
    json := "{"
    . "`n  " . q . "name" . q . ": " . q . JsonEscape(p.name) . q . ","
    . "`n  " . q . "version" . q . ": " . q . JsonEscape(version) . q . ","
    . "`n  " . q . "historyMax" . q . ": " . p.historyMax . ","
    . "`n  " . q . "maxCols" . q . ": " . p.maxCols . ","
    . "`n  " . q . "sections" . q . ": [" . JoinJsonStringArray(p.sections) . "],"
    . "`n  " . q . "colors" . q . ": ["

    for index, item in p.colors {
        suffix := (index < p.colors.Length) ? "," : ""
        json .= "`n    {"
        . q . "hex" . q . ": " . q . item.hex . q . ", "
        . q . "rgb" . q . ": " . q . item.rgb . q . ", "
        . q . "name" . q . ": " . q . JsonEscape(item.name) . q . ", "
        . q . "role" . q . ": " . q . JsonEscape(item.role) . q . ", "
        . q . "section" . q . ": " . q . JsonEscape(GetItemSectionNameForState(item)) . q . ", "
        . q . "pinned" . q . ": " . (item.pinned ? "true" : "false") . "}" . suffix
    }

    json .= "`n  ]`n}"

    return json
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

TestExport() {
    testScriptPath := A_ScriptDir . "\src\features\test_export.ps1"
    testJsonPath := A_Temp . "\test_export.json"
    testOutPath := A_Desktop . "\test.png"
    
    testJson := '{"colors":[{"hex":"FF0000","name":"Red"}]}'
    FileAppend(testJson, testJsonPath, "UTF-8")
    
    shell := ComObject("WScript.Shell")
    cmd := "powershell -NoProfile -ExecutionPolicy Bypass -File " . Chr(34) . testScriptPath . Chr(34) . " " . Chr(34) . testJsonPath . Chr(34) . " " . Chr(34) . testOutPath . Chr(34)
    result := shell.Exec(cmd)
    
    While !result.Status {
        Sleep(100)
    }
    
    MsgBox("Done. Check Desktop for test.png")
}
