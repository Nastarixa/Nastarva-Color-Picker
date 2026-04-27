CreateActionsPanel(gui, app, centerX, centerW) {
    CreatePanel(x, y, w, h, title) {
        gui.AddText("x" x " y+1 w" w " h" (h-5), "")
        gui.AddText("x" x+6 " y" y-10 " cFFD76A", title)
    }

    yBase := 250
    CreatePanel(centerX, yBase, centerW, 165, "Actions")
    gui.SetFont("s7", "Consolas")

    y := yBase + 12
    x := centerX + 5
    gui.AddButton("x" x " y" y " w80 h22", "New").OnEvent("Click", (*) => NewPaletteBtnClicked(app))
    x += 85
    gui.AddButton("x" x " y" y " w80 h22", "Snip").OnEvent("Click", (*) => StartPaletteScreenshotImport(app))
    x += 85
    gui.AddButton("x" x " y" y " w80 h22", "Import").OnEvent("Click", (*) => ShowImportMenuBtn(app))

    y += 28
    x := centerX + 5
    gui.AddButton("x" x " y" y " w80 h22", "Templates").OnEvent("Click", (*) => OpenPaletteTemplateDialog(app))
    x += 85
    gui.AddButton("x" x " y" y " w80 h22", "Export").OnEvent("Click", (*) => OpenExportDialog(app))

    y += 28
    x := centerX + 5
    gui.AddProgress("x" x " y+5 h1 w" centerW-10 " Background8A8A8A")

    y += 10
    x := centerX + 5
    gui.AddButton("x" x " y" y " w80 h22", "Duplicate").OnEvent("Click", (*) => DuplicatePaletteBtn(app))
    x += 85
    gui.AddButton("x" x " y" y " w80 h22", "Merge").OnEvent("Click", (*) => OpenPaletteMergeDialog(app))
    x += 85
    gui.AddButton("x" x " y" y " w80 h22", "Rename").OnEvent("Click", (*) => RenamePaletteBtn(app))

    y += 28
    x := centerX + 5
    gui.AddButton("x" x " y" y " w80 h22", "Compare").OnEvent("Click", (*) => OpenPaletteCompareDialog(app))
    x += 85
    gui.AddButton("x" x " y" y " w80 h22", "Delete").OnEvent("Click", (*) => DeletePaletteBtn(app))

    y += 28
    x := centerX + 5
    gui.AddProgress("x" x " y+5 h1 w" centerW-10 " Background8A8A8A")

    y += 10
    x := centerX + 5
    gui.AddButton("x" x " y" y " w80 h22", "Harmony").OnEvent("Click", (*) => OpenColorHarmonyDialog(app))
    x += 85
    gui.AddButton("x" x " y" y " w80 h22", "ColorBlind").OnEvent("Click", (*) => OpenColorBlindDialog(app))
    x += 85
    gui.AddButton("x" x " y" y " w80 h22", "Contrast").OnEvent("Click", (*) => OpenContrastCheckerDialog(app))

    y += 28
    x := centerX + 5
    gui.AddButton("x" x " y" y " w80 h22", "Gradient").OnEvent("Click", (*) => OpenGradientDialog(app))
}

ShowImportMenuBtn(app) {
    gui := app.paletteGui
    ShowImportMenu(app, gui)
}

NewPaletteBtnClicked(app) {
    ShowInputDialog(app, "New palette name:", "Create Palette", (name) => NewPaletteConfirm(app, name))
}

NewPaletteConfirm(app, name) {
    if name = "" || !name
        return
    if app.palettes.Has(name) {
        ShowToast(app, "Palette already exists")
        return
    }
    file := A_ScriptDir "\color\" name ".txt"
    app.palettes[name] := CreatePalette(name, file)
    app.paletteOrder.Push(name)
    SavePaletteList(app)
    SwitchPalette(app, name)
    gui := app.paletteGui
    if IsObject(gui)
        RefreshPaletteManager(app, gui)
}

DeletePaletteBtn(app) {
    name := app.activePalette.name
    if name = "Default" {
        ShowToast(app, "Cannot delete Default palette")
        return
    }
    doDelete() {
        palettePath := app.palettes[name].file
        if FileExist(palettePath)
            FileDelete(palettePath)
        app.palettes.Delete(name)
        for i, n in app.paletteOrder {
            if (n = name) {
                app.paletteOrder.RemoveAt(i)
                break
            }
        }
        SavePaletteList(app)
        nextName := app.paletteOrder[1]
        if nextName {
            SwitchPalette(app, nextName)
            g := app.paletteGui
            if IsObject(g)
                RefreshPaletteManager(app, g)
        }
        ShowToast(app, "Deleted: " name)
    }
    ShowConfirmDialog(app, "Delete '" name "'?`nThis cannot be undone.", "Delete Palette", doDelete)
}

DuplicatePaletteBtn(app) {
    srcName := app.activePalette.name
    p := app.palettes[srcName]
    newName := srcName " (Copy)"
    loop {
        testName := newName
        if app.palettes.Has(testName) {
            newName := srcName " (Copy " A_Index ")"
        }
    } until !app.palettes.Has(testName)
    newFile := A_ScriptDir "\color\" newName ".txt"
    dup := CreatePalette(newName, newFile)
    for item in p.colors {
        clone := CreateItem(item.hex, item.rgb, item.name, item.role)
        clone.pinned := item.pinned
        clone.pinOrder := item.pinOrder
        clone.section := item.section
        clone.isSaved := true
        dup.colors.Push(clone)
        if !dup.map.Has(clone.hex)
            dup.map[clone.hex] := clone
        dup.idMap[clone.id] := clone
    }
    dup.historyMax := p.historyMax
    dup.maxCols := p.maxCols
    dup.guiMode := p.HasOwnProp("guiMode") ? p.guiMode : "undocked"
    app.palettes[newName] := dup
    app.paletteOrder.Push(newName)
    SavePaletteList(app)
    gui := app.paletteGui
    if IsObject(gui)
        RefreshPaletteManager(app, gui)
    ShowToast(app, "Duplicated: " newName)
}

RenamePaletteBtn(app) {
    oldName := app.activePalette.name
    ShowInputDialog(app, "New name:", "Rename Palette", (newName) => DoRenamePalette(app, newName, oldName), oldName)
}

DoRenamePalette(app, newName, oldName) {
    if newName = "" || !newName || newName = oldName
        return
    if app.palettes.Has(newName) {
        ShowToast(app, "Name already exists")
        return
    }
    p := app.palettes[oldName]
    p.name := newName
    p.file := A_ScriptDir "\color\" newName ".txt"
    app.palettes.Delete(oldName)
    app.palettes[newName] := p
    for i, n in app.paletteOrder {
        if (n = oldName) {
            app.paletteOrder[i] := newName
            break
        }
    }
    SavePaletteList(app)
    SwitchPalette(app, newName)
    gui := app.paletteGui
    if IsObject(gui)
        RefreshPaletteManager(app, gui)
    ShowToast(app, "Renamed to: " newName)
}
