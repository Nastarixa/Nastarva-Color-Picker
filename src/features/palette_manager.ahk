TogglePaletteManager(app) {
    paletteHwnd := SafeGetGuiHwnd(app.paletteGui)
    if paletteHwnd {
        if WinExist("ahk_id " paletteHwnd) {
            app.paletteGui.Hide()
            return
        }
    }

    OpenPaletteManager(app)
}

SwitchPaletteByIndex(app, idx) {
    if (idx < 1 || idx > app.paletteOrder.Length)
        return

    name := app.paletteOrder[idx]
    SwitchPalette(app, name)

    ShowToast(app, "🎨 Switched to: " name)
}

OpenPaletteManager(app) {
    if SafeGetGuiHwnd(app.paletteGui) {
        app.paletteGui.Show()
        return
    }

    g := Gui("+AlwaysOnTop +Resize", "🎨 Nastarva Palette Manager v" app.version)
    g.BackColor := "323338"
    g.SetFont("s10", "Consolas")

    g.SetFont("s9 norm", "Consolas")

    g.AddText("xm y+10 cAAAAAA", "📂 Palettes")

    g.list := g.AddListBox("w320 h220 xm y+5")
    g.list.OnEvent("Change", (*) => PaletteSwitchUI(app, g))
    g.list.OnEvent("DoubleClick", (*) => OpenPaletteFile(app, g))

    g.AddButton("xm y+7 w157 h28", "⬆ Move Up")
        .OnEvent("Click", (*) => MovePalette(app, g, -1))

    g.AddButton("x+6 w157 h28", "⬇ Move Down")
        .OnEvent("Click", (*) => MovePalette(app, g, 1))

    g.AddText("xm y+10 cAAAAAA", "⚙️ Settings")

    g.AddText("xm y+5 cFFFFFF", "Color Section:")
    g.inputMax := g.AddEdit("w30 Number x+5 yp-2")

    g.AddText("x+10 yp+2 cFFFFFF", "Cols:")
    g.inputCols := g.AddEdit("w30 Number x+5 yp-2")

    g.AddButton("x+15 w105 h21", "🔒 Role Freeze")
    .OnEvent("Click", (*) => TogglePaletteLockLayout(app))

    g.AddText("xm y+8 cFFFFFF", "Role order:")
    g.inputRoleOrder := g.AddEdit("w320 xm y+3")

    g.AddText("xm y+15 cFFFFFF", "GUI:")
    g.inputGuiMode := g.AddDropDownList("w110 x+5 yp-2 Choose1", ["Undocked", "Docked"])

    g.AddButton("x+15  w80 h20", "✅ Apply")
        .OnEvent("Click", (*) => ApplyPaletteSettings(app))

    g.AddText("xm y+15 cAAAAAA", "🛠 Actions")

    g.AddButton("xm w100 h28", "➕ New")
        .OnEvent("Click", (*) => CreatePaletteUI(app, g))

    g.AddButton("x+10 w100 h28", "✂ Snip")
        .OnEvent("Click", (*) => StartPaletteScreenshotImport(app))

    g.AddButton("x+10 w100 h28", "🧩 Import")
        .OnEvent("Click", (*) => ImportPaletteImageUI(app))

    g.AddButton("xm y+5 w100 h28", "🗑 Delete")
        .OnEvent("Click", (*) => DeletePaletteUI(app, g))

    g.AddButton("x+10 w100 h28", "📋 Duplicate")
        .OnEvent("Click", (*) => DuplicatePaletteUI(app, g))

    g.AddButton("x+10 w100 h28", "✏ Rename")
        .OnEvent("Click", (*) => RenamePaletteUI(app, g))

    g.AddText("xm y+15 cAAAAAA", "📤 Export")

    g.AddButton("xm+2 w57 h26", "TXT")
        .OnEvent("Click", (*) => ExportActivePalette(app, "txt"))

    g.AddButton("x+8 w57 h26", "JSON")
        .OnEvent("Click", (*) => ExportActivePalette(app, "json"))

    g.AddButton("x+8 w57 h26", "INI")
        .OnEvent("Click", (*) => ExportActivePalette(app, "ini"))

    g.AddButton("x+8 w57 h26", "CSV")
        .OnEvent("Click", (*) => ExportActivePalette(app, "csv"))

    g.AddButton("x+8 w57 h26", "PNG")
        .OnEvent("Click", (*) => ExportActivePalette(app, "png"))

    g.AddText("xm y+15 c666666", "💡 Click = Switch palette")
    g.AddText("xm c666666", "💡 Double Click = Open file location")
    g.AddText("xm c666666", "💡 Ctrl + Double Click = Edit file")

    RefreshPaletteList(app, g)

    for i, name in app.paletteOrder {
        if (name = app.activePalette.name) {
            g.list.Value := i
            break
        }
    }

    g.inputMax.Value := app.activePalette.historyMax
    g.inputCols.Value := app.activePalette.maxCols
    g.inputGuiMode.Text := GetPaletteGuiModeLabel(app.activePalette)
    g.inputRoleOrder.Value := GetPaletteRoleOrderText(app.activePalette)

    g.Show("Center")
    app.paletteGui := g
}

OpenPaletteFile(app, g) {
    sel := g.list.Value
    if !sel
        return

    name := app.paletteOrder[sel]
    p := app.palettes[name]

    if !p
        return

    file := p.file

    if !FileExist(file) {
        MsgBox "File not found:`n" file
        return
    }

    if GetKeyState("Ctrl") {
        Run('notepad.exe "' file '"')
    } else {
        Run('explorer.exe /select,"' file '"')
    }
}

ApplyPaletteSettings(app) {
    g := app.paletteGui
    if !IsObject(g)
        return

    p := app.activePalette

    max := Integer(g.inputMax.Value)
    if (max >= 1) {
        p.historyMax := max
        Normalize(p)
    }

    cols := Integer(g.inputCols.Value)
    if (cols >= 1) {
        p.maxCols := cols
        app.ui.cols := cols
    }

    if g.HasOwnProp("inputGuiMode")
        p.guiMode := ParsePaletteGuiMode(g.inputGuiMode.Text)

    if g.HasOwnProp("inputRoleOrder") {
        roleOrder := ParseRoleOrder(g.inputRoleOrder.Value)
        if (roleOrder.Length > 0)
            p.roleOrder := roleOrder
    }

    SaveHistory(app)

    app.ui.generation++
    InitHistoryGui(app)
    RebuildUI(app)

    Emit(app, "history_changed")
}

ApplyHistoryMaxUI(app, g) {
    if !IsObject(g) || !g.HasOwnProp("inputMax")
        return

    val := Integer(g.inputMax.Value)
    if (val < 1)
        return

    p := app.activePalette
    p.historyMax := val
    Normalize(p)

    SaveHistory(app)

    app.ui.generation++
    InitHistoryGui(app)
    RebuildUI(app)

    Emit(app, "history_changed")
}

ApplyColsUI(app, g) {
    val := Integer(g.inputCols.Value)

    if (val < 1)
        return

    p := app.activePalette

    p.maxCols := val
    app.ui.cols := val

    SaveHistory(app)

    app.ui.generation++
    InitHistoryGui(app)
    RebuildUI(app)

    Emit(app, "history_changed")
}

GetActivePaletteName(app) {
    return app.activePalette.name
}

GetPaletteRoleOrderText(p) {
    if !p.HasOwnProp("roleOrder")
        p.roleOrder := DefaultRoleOrder()

    return JoinRoleOrder(p.roleOrder)
}

GetPaletteGuiModeLabel(p) {
    mode := p.HasOwnProp("guiMode") ? StrLower(p.guiMode) : "undocked"
    return (mode = "docked") ? "Docked" : "Undocked"
}

ParsePaletteGuiMode(text) {
    text := StrLower(Trim(text))
    return (text = "docked") ? "docked" : "undocked"
}

ParseRoleOrder(text) {
    roles := []
    seen := Map()

    for _, role in StrSplit(text, ",") {
        role := NormalizeRoleName(role)
        if (role = "" || seen.Has(role))
            continue

        roles.Push(role)
        seen[role] := true
    }

    return roles
}

RefreshPaletteList(app, g) {
    g.list.Delete()

    active := app.activePalette.name

    for i, name in app.paletteOrder {
        isActive := (active = name)

        label := (isActive ? "🎯 " : "   ")
               . "[" i "] "
               . name

        g.list.Add([label])

        if isActive
            g.list.Value := i
    }
}

PaletteSwitchUI(app, g) {
    sel := g.list.Value
    if !sel
        return

    name := app.paletteOrder[sel]
    SwitchPalette(app, name)

    g.inputMax.Value := app.activePalette.historyMax
    g.inputCols.Value := app.activePalette.maxCols
    if g.HasOwnProp("inputGuiMode")
        g.inputGuiMode.Text := GetPaletteGuiModeLabel(app.activePalette)
    if g.HasOwnProp("inputRoleOrder")
        g.inputRoleOrder.Value := GetPaletteRoleOrderText(app.activePalette)

    RefreshPaletteList(app, g)
}

CreatePaletteUI(app, g) {
    result := InputBox("Enter palette name:", "➕ New Palette")

    if (result.Result != "OK" || result.Value = "")
        return

    name := Trim(result.Value)
    if (name = "")
        return

    if app.palettes.Has(name) {
        MsgBox "Palette already exists!"
        return
    }

    file := A_ScriptDir "\color\" name ".txt"

    app.palettes[name] := CreatePalette(name, file)
    app.paletteOrder.Push(name)

    RefreshPaletteList(app, g)
    SavePaletteList(app)
}

DeletePaletteUI(app, g) {
    name := GetActivePaletteName(app)

    if (name = "Default") {
        MsgBox "Cannot delete Default palette"
        return
    }

    file := app.palettes[name].file
    if FileExist(file)
        FileDelete(file)

    app.palettes.Delete(name)

    for i, n in app.paletteOrder {
        if (n = name) {
            app.paletteOrder.RemoveAt(i)
            break
        }
    }

    app.activePalette := app.palettes[app.paletteOrder[1]]
    app.ui.cols := app.activePalette.maxCols

    LoadHistory(app)
    InitHistoryGui(app)
    app.ui.generation++
    RebuildUI(app)
    RefreshPaletteList(app, g)
    g.inputMax.Value := app.activePalette.historyMax
    g.inputCols.Value := app.activePalette.maxCols
    if g.HasOwnProp("inputGuiMode")
        g.inputGuiMode.Text := GetPaletteGuiModeLabel(app.activePalette)
    if g.HasOwnProp("inputRoleOrder")
        g.inputRoleOrder.Value := GetPaletteRoleOrderText(app.activePalette)
    SavePaletteList(app)
    Emit(app, "history_changed")
}

DuplicatePaletteUI(app, g) {
    srcName := GetActivePaletteName(app)

    result := InputBox("Duplicate palette as:", "📋 Duplicate", "", srcName " Copy")
    if (result.Result != "OK" || Trim(result.Value) = "")
        return

    newName := Trim(result.Value)

    if app.palettes.Has(newName) {
        MsgBox "Palette already exists!"
        return
    }

    src := app.palettes[srcName]
    newFile := A_ScriptDir "\color\" newName ".txt"

    p := CreatePalette(newName, newFile)

    for item in src.colors {
        clone := CreateItem(item.hex, item.rgb, item.name, item.role)
        clone.pinned := item.pinned
        clone.pinOrder := item.pinOrder
        clone.section := item.section
        clone.isSaved := true

        p.colors.Push(clone)
        if !p.map.Has(clone.hex)
            p.map[clone.hex] := clone
        p.idMap[clone.id] := clone
    }

    p.historyMax := src.historyMax
    p.maxCols := src.maxCols
    p.guiMode := src.HasOwnProp("guiMode") ? src.guiMode : "undocked"

    app.palettes[newName] := p
    app.paletteOrder.Push(newName)

    SavePalette(p, app.version)
    SavePaletteList(app)

    RefreshPaletteList(app, g)
}

RenamePaletteUI(app, g) {
    oldName := GetActivePaletteName(app)

    result := InputBox("Rename palette:", "✏ Rename", "", oldName)
    if (result.Result != "OK" || Trim(result.Value) = "")
        return

    newName := Trim(result.Value)

    if app.palettes.Has(newName) {
        MsgBox "Palette already exists!"
        return
    }

    oldFile := app.palettes[oldName].file
    newFile := A_ScriptDir "\color\" newName ".txt"

    if FileExist(oldFile)
        FileMove(oldFile, newFile, true)

    p := app.palettes[oldName]
    p.name := newName
    p.file := newFile

    app.palettes.Delete(oldName)
    app.palettes[newName] := p

    for i, name in app.paletteOrder {
        if (name = oldName) {
            app.paletteOrder[i] := newName
            break
        }
    }

    app.activePalette := p

    RefreshPaletteList(app, g)
    SavePaletteList(app)
}

MovePalette(app, g, dir) {
    sel := g.list.Value
    if !sel
        return

    newIndex := sel + dir

    if (newIndex < 1 || newIndex > app.paletteOrder.Length)
        return

    temp := app.paletteOrder[sel]
    app.paletteOrder[sel] := app.paletteOrder[newIndex]
    app.paletteOrder[newIndex] := temp

    RefreshPaletteList(app, g)
    g.list.Value := newIndex
    SavePaletteList(app)
}
TogglePaletteLockLayout(app) {
    p := app.activePalette

    if !p.HasOwnProp("lockLayoutOrder")
        p.lockLayoutOrder := false

    p.lockLayoutOrder := !p.lockLayoutOrder

    ShowToast(app, p.lockLayoutOrder
        ? "🔒 Layout order FROZEN"
        : "🔓 Layout order UNLOCKED")

    RefreshHistoryUI(app)
    Layout(app)
}
ImportPaletteImageUI(app) {
    path := FileSelect(1, , "Import Character Sheet Palette", "Images (*.png; *.jpg; *.jpeg; *.bmp)")
    if (path = "")
        return

    result := MsgBox(
        "Replace current palette '" app.activePalette.name "' with colors detected from this image?`n`nBest result: use a screenshot cropped around the swatch area.",
        "Import Palette Image",
        "YesNo Icon?"
    )
    if (result != "Yes")
        return

    ImportPaletteImage(app, path)
}

ImportPaletteImage(app, imagePath) {
    outPath := A_Temp "\nastarva_palette_import.txt"
    scriptPath := A_Temp "\nastarva_palette_import.ps1"

    if FileExist(outPath)
        FileDelete(outPath)
    if FileExist(scriptPath)
        FileDelete(scriptPath)

    FileAppend(GetPaletteImageImportScript(), scriptPath, "UTF-8")

    cmd := Format(
        'powershell -NoProfile -ExecutionPolicy Bypass -File "{}" "{}" "{}"',
        scriptPath,
        imagePath,
        outPath
    )

    RunWait(cmd, , "Hide")

    if !FileExist(outPath) {
        MsgBox "Image import failed."
        return
    }

    imported := FileRead(outPath, "UTF-8")
    if (Trim(imported) = "") {
        MsgBox "No palette blocks were detected from that image."
        return
    }

    if FileExist(app.activePalette.file)
        FileDelete(app.activePalette.file)
    FileAppend(imported, app.activePalette.file, "UTF-8")
    LoadHistory(app)
    InitHistoryGui(app)
    app.ui.generation++
    RebuildUI(app)
    SetSelectedSection(app, GetFirstNonDefaultSectionName(app.activePalette), true)
    SaveHistory(app)
    ShowToast(app, "Imported palette from image")
}

GetPaletteImageImportScript() {
    return FileRead(A_ScriptDir "\src\features\palette_image_import.ps1")
}

StartPaletteScreenshotImport(app) {
    if app.screenshotCapture.active {
        ShowToast(app, "Screenshot capture already running")
        return
    }

    if !IsObject(app.screenshotPollFn)
        app.screenshotPollFn := PollPaletteScreenshotImport.Bind(app)

    app.screenshotCapture.savedClipboard := ClipboardAll()
    app.screenshotCapture.active := true
    app.screenshotCapture.deadline := A_TickCount + 120000
    app.screenshotCapture.tempPath := A_Temp "\nastarva_palette_capture.png"

    A_Clipboard := ""
    ShowToast(app, "Snip the palette area, then release mouse")
    Run("ms-screenclip:")
    SetTimer(app.screenshotPollFn, 250)
}

PollPaletteScreenshotImport(app) {
    if !app.screenshotCapture.active {
        SetTimer(app.screenshotPollFn, 0)
        return
    }

    if (A_TickCount > app.screenshotCapture.deadline) {
        CancelPaletteScreenshotImport(app, "Screenshot import canceled")
        return
    }

    if !ClipboardHasImage()
        return

    SetTimer(app.screenshotPollFn, 0)
    tempPath := app.screenshotCapture.tempPath

    if !SaveClipboardImageToFile(tempPath) {
        CancelPaletteScreenshotImport(app, "Could not read screenshot from clipboard")
        return
    }

    app.screenshotCapture.active := false
    try A_Clipboard := app.screenshotCapture.savedClipboard
    catch
    app.screenshotCapture.savedClipboard := 0

    ImportPaletteImage(app, tempPath)
}

CancelPaletteScreenshotImport(app, message := "") {
    app.screenshotCapture.active := false
    SetTimer(app.screenshotPollFn, 0)

    try A_Clipboard := app.screenshotCapture.savedClipboard
    catch
    app.screenshotCapture.savedClipboard := 0

    if (message != "")
        ShowToast(app, message)
}

ClipboardHasImage() {
    return DllCall("IsClipboardFormatAvailable", "UInt", 2)
        || DllCall("IsClipboardFormatAvailable", "UInt", 8)
        || DllCall("IsClipboardFormatAvailable", "UInt", 17)
}

SaveClipboardImageToFile(path) {
    scriptPath := A_Temp "\nastarva_clipboard_image_save.ps1"

    if FileExist(scriptPath)
        FileDelete(scriptPath)
    if FileExist(path)
        FileDelete(path)

    FileAppend(GetClipboardImageSaveScript(), scriptPath, "UTF-8")

    cmd := Format(
        'powershell -NoProfile -ExecutionPolicy Bypass -File "{}" "{}"',
        scriptPath,
        path
    )

    RunWait(cmd, , "Hide")
    return FileExist(path)
}

GetClipboardImageSaveScript() {
    return FileRead(A_ScriptDir "\src\features\clipboard_image_save.ps1")
}
