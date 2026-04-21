ExportActivePalette(app, format) {
    p := app.activePalette
    ext := "." format
    filters := Map(
        "txt", "Text Files (*.txt)",
        "json", "JSON Files (*.json)",
        "ini", "INI Files (*.ini)",
        "csv", "CSV Files (*.csv)",
        "png", "PNG Files (*.png)"
    )

    defaultName := p.name ext
    path := FileSelect("S16", A_ScriptDir "\" defaultName, "Export Palette as " StrUpper(format), filters[format])
    if (path = "")
        return

    if (format = "png") {
        ExportPalettePng(app, p, path)
        return
    }

    content := BuildPaletteExportContent(p, app.version, format)
    if (content = "")
        return

    if FileExist(path)
        FileDelete(path)
    FileAppend(content, path, "UTF-8")
    ShowToast(app, "Exported " p.name " as " StrUpper(format))
}

ExportPalettePng(app, p, path) {
    jsonPath := A_Temp "\nastarva_palette_export.json"
    scriptPath := A_Temp "\nastarva_palette_export.ps1"

    if FileExist(jsonPath)
        FileDelete(jsonPath)
    if FileExist(scriptPath)
        FileDelete(scriptPath)

    FileAppend(BuildPaletteJson(p, app.version), jsonPath, "UTF-8")
    FileAppend(GetPalettePngExportScript(), scriptPath, "UTF-8")

    cmd := Format(
        'powershell -NoProfile -ExecutionPolicy Bypass -File "{}" "{}" "{}"',
        scriptPath,
        jsonPath,
        path
    )

    RunWait(cmd, , "Hide")

    if FileExist(path) {
        ShowToast(app, "Exported " p.name " as PNG")
    } else {
        MsgBox "PNG export failed."
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
    for index, item in items
        text .= (index > 1 ? "," : "") '"' JsonEscape(item) '"'
    return text
}

CsvEscape(value) {
    value := StrReplace(value, '"', '""')
    return '"' value '"'
}

GetPalettePngExportScript() {
    return FileRead(A_ScriptDir "\src\features\palette_png_export.ps1")
}
