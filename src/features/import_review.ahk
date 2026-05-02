ShowImportReview(app, importedData, reviewPath, imagePath := "", isTemp := false, importMode := "insert") {
    if app.HasOwnProp("importReviewGui") && IsObject(app.importReviewGui) {
        try {
            if app.importReviewGui.Hwnd
                app.importReviewGui.Destroy()
        }
    }

    g := Gui("+AlwaysOnTop +ToolWindow +Border", "Import Review")
    g.BackColor := "323338"
    g.SetFont("s9", "Consolas")
    g.MarginX := 12
    g.MarginY := 10

    g.importData := ParseImportedData(importedData)
    g.reviewPath := reviewPath
    g.sourceImagePath := imagePath
    g.cleanupTempImage := isTemp
    g.selectedSectionIdx := 0
    g.selectedColorIdx := 0
    g.refColorMap := Map()
    g.paletteNames := []

    if (g.importData.sourceName = "" && imagePath != "")
        g.importData.sourceName := RegExReplace(imagePath, "^.*\\")

    g.AddText("x10 y10 cFFFFFF", "Import Review & Training")

    leftX := 10, leftW := 180
    centerX := 205, centerW := 370
    rightX := 590, rightW := 300
    topY := 34

    g.AddText("x" leftX " y" topY " cAAAAAA", "Sections")
    g.sectionList := g.AddListBox("x" leftX " y" (topY + 18) " w" leftW " h220")
    g.sectionList.OnEvent("Change", (*) => ImportReviewSelectSection(app, g))

    g.btnRenameSection := g.AddButton("x" leftX " y" (topY + 246) " w85 h26", "Rename")
    g.btnMergeSection := g.AddButton("x" (leftX + 95) " y" (topY + 246) " w85 h26", "Merge")
    g.btnDeleteSection := g.AddButton("x" leftX " y" (topY + 278) " w180 h26", "Delete Section")
    g.btnRenameSection.OnEvent("Click", (*) => ImportReviewRenameSection(app, g))
    g.btnMergeSection.OnEvent("Click", (*) => ImportReviewMergeSection(app, g))
    g.btnDeleteSection.OnEvent("Click", (*) => ImportReviewDeleteSection(app, g))

    g.AddText("x" centerX " y" topY " cAAAAAA", "Detected Blocks")
    g.colorList := g.AddListView("x" centerX " y" (topY + 18) " w" centerW " h180 Grid", ["HEX", "Name", "Role", "Bounds"])
    g.colorList.ModifyCol(1, 72)
    g.colorList.ModifyCol(2, 108)
    g.colorList.ModifyCol(3, 76)
    g.colorList.ModifyCol(4, 96)
    g.colorList.OnEvent("ItemFocus", (ctrl, item) => ImportReviewColorFocus(app, g, item))

    previewY := topY + 208
    g.AddText("x" centerX " y" previewY " cAAAAAA", "Selected Block")
    g.preview := g.AddProgress("x" centerX " y" (previewY + 20) " w50 h40 Background808080")
    g.selectedHex := g.AddText("x" (centerX + 60) " y" (previewY + 18) " w160 h16 cFFFFFF", "#808080")
    g.selectedRGB := g.AddText("x" (centerX + 60) " y" (previewY + 36) " w160 h16 cAAAAAA", "0,0,0")

    formY := previewY + 70
    g.AddText("x" centerX " y" formY " cAAAAAA", "Name")
    g.nameEdit := g.AddEdit("x" centerX " y" (formY + 16) " w170 h22")
    g.AddText("x" (centerX + 180) " y" formY " cAAAAAA", "Role")
    g.roleEdit := g.AddDropDownList("x" (centerX + 180) " y" (formY + 16) " w170", DefaultImportReviewRoles())

    g.AddText("x" centerX " y" (formY + 48) " cAAAAAA", "Section")
    g.sectionEdit := g.AddEdit("x" centerX " y" (formY + 64) " w170 h22")
    g.AddText("x" (centerX + 180) " y" (formY + 48) " cAAAAAA", "HEX")
    g.hexEdit := g.AddEdit("x" (centerX + 180) " y" (formY + 64) " w170 h22")

    g.AddText("x" centerX " y" (formY + 96) " cAAAAAA", "RGB")
    g.rgbEdit := g.AddEdit("x" centerX " y" (formY + 112) " w170 h22")
    g.AddText("x" (centerX + 180) " y" (formY + 96) " cAAAAAA", "X, Y, W, H")
    g.xEdit := g.AddEdit("x" (centerX + 180) " y" (formY + 112) " w40 h22")
    g.yEdit := g.AddEdit("x" (centerX + 225) " y" (formY + 112) " w40 h22")
    g.wEdit := g.AddEdit("x" (centerX + 270) " y" (formY + 112) " w40 h22")
    g.hEdit := g.AddEdit("x" (centerX + 315) " y" (formY + 112) " w40 h22")

    g.btnApplyColor := g.AddButton("x" centerX " y" (formY + 146) " w170 h28", "Apply Block Changes")
    g.btnDeleteColor := g.AddButton("x" (centerX + 180) " y" (formY + 146) " w170 h28", "Delete Block")
    g.btnApplyColor.OnEvent("Click", (*) => ImportReviewApplyColorEdits(app, g))
    g.btnDeleteColor.OnEvent("Click", (*) => ImportReviewDeleteColor(app, g))

    g.AddText("x" rightX " y" topY " cAAAAAA", "Source Image")
    if (imagePath != "" && FileExist(imagePath)) {
        try g.imagePreview := g.AddPicture("x" rightX " y" (topY + 18) " w" rightW " h220", imagePath)
        catch
            g.imagePreview := 0
    }
    if !IsObject(g.imagePreview)
        g.imagePreviewLabel := g.AddText("x" rightX " y" (topY + 18) " w" rightW " h220 c777777 +Border", imagePath != "" ? imagePath : "No image preview")

    settingsY := topY + 248
    g.AddText("x" rightX " y" settingsY " cAAAAAA", "Import Settings")
    g.importMode := g.AddDropDownList("x" rightX " y" (settingsY + 18) " w200 Choose2", ["Replace Palette", "Insert Into Palette", "Create New Palette"])
    for _, paletteName in app.paletteOrder
        g.paletteNames.Push(paletteName)

    g.targetPaletteLabel := g.AddText("x" rightX " y" (settingsY + 50) " cAAAAAA", "Target Palette")
    g.targetPalette := g.AddDropDownList("x" rightX " y" (settingsY + 68) " w200", g.paletteNames)
    g.newPaletteNameLabel := g.AddText("x" rightX " y" (settingsY + 50) " cAAAAAA", "New Palette")
    g.newPaletteName := g.AddEdit("x" rightX " y" (settingsY + 68) " w200 h22", "New Palette")
    g.trainingCheck := g.AddCheckBox("x" rightX " y" (settingsY + 102) " w250 Checked cAAAAAA", "Learn from manual corrections")
    g.trainingInfo := g.AddText("x" rightX " y" (settingsY + 126) " w" rightW " c777777", "Corrections are saved and used to improve future role and section detection.")
    g.imageMeta := g.AddText("x" rightX " y" (settingsY + 166) " w" rightW " cAAAAAA", "Image: " g.importData.imageWidth "x" g.importData.imageHeight "  Source: " g.importData.sourceName)
    g.btnSavePreset := g.AddButton("x" rightX " y" (settingsY + 194) " w145 h28", "Save Training Preset")
    g.btnOpenTrainer := g.AddButton("x" (rightX + 155) " y" (settingsY + 194) " w145 h28", "Open Trainer Canvas")
    g.btnSavePreset.OnEvent("Click", (*) => ImportReviewSaveTrainingPreset(app, g))
    g.btnOpenTrainer.OnEvent("Click", (*) => OpenImportTrainingCanvas(app, g))
    g.importMode.OnEvent("Change", (*) => ImportModeChanged(g))

    bottomY := 560
    g.btnApply := g.AddButton("x10 y" bottomY " w200 h30", "Apply Import")
    g.btnCancel := g.AddButton("x220 y" bottomY " w200 h30", "Cancel")
    g.btnApply.OnEvent("Click", (*) => ImportReviewApply(app, g))
    g.btnCancel.OnEvent("Click", (*) => ImportReviewCancel(app, g))

    modeIdx := importMode = "replace" ? 1 : (importMode = "insert" ? 2 : 3)
    g.importMode.Value := modeIdx
    if (g.paletteNames.Length > 0) {
        activeIdx := 1
        if app.activePalette && app.activePalette.HasOwnProp("name") {
            for idx, paletteName in g.paletteNames {
                if (paletteName = app.activePalette.name) {
                    activeIdx := idx
                    break
                }
            }
        }
        g.targetPalette.Choose(activeIdx)
    }
    ImportModeChanged(g)

    PopulateImportReviewSections(g)
    if g.importData.sectionOrder.Length > 0 {
        g.sectionList.Choose(1)
        ImportReviewSelectSection(app, g)
    }

    g.Show("w905 h605 Center")
    app.importReviewGui := g
}

DefaultImportReviewRoles() {
    return ["Base", "Highlight", "Shadow", "Hi Shadow", "2 Shadow", "Mask", "Outline", "Black", "Other"]
}

ParseImportedData(importedData) {
    data := {
        sections: Map(),
        sectionOrder: [],
        sectionTags: Map(),
        imageWidth: 0,
        imageHeight: 0,
        sourceName: ""
    }
    lines := StrSplit(importedData, "`n", "`r")
    currentSection := "Default"

    for rawLine in lines {
        line := Trim(rawLine)
        if (line = "" || SubStr(line, 1, 1) = ";")
            continue

        if (InStr(line, "#IMAGE|") = 1) {
            parts := StrSplit(line, "|")
            if parts.Length >= 4 {
                data.imageWidth := SafeInteger(parts[2])
                data.imageHeight := SafeInteger(parts[3])
                data.sourceName := Trim(parts[4])
            }
            continue
        }

        if (InStr(line, "#SECTION|") = 1) {
            sectionData := Trim(SubStr(line, 10))
            sectionParts := StrSplit(sectionData, "|")
            sectionTag := ""
            if sectionParts.Length >= 2 {
                sectionTag := Trim(sectionParts[1])
                currentSection := Trim(sectionParts[2])
            } else {
                currentSection := sectionData
            }
            if (currentSection = "")
                currentSection := "Default"
            EnsureParsedImportSection(data, currentSection)
            if (sectionTag != "")
                data.sectionTags[currentSection] := sectionTag
            continue
        }

        parts := StrSplit(line, "|")
        if parts.Length < 4
            continue

        hex := Trim(parts[1])
        if (InStr(hex, "#") = 1)
            hex := SubStr(hex, 2)
        if !RegExMatch(hex, "^[0-9A-Fa-f]{6}$")
            continue

        rgb := Trim(parts[2])
        name := Trim(parts[3])
        role := Trim(parts[4])
        pinned := parts.Length >= 5 ? SafeInteger(parts[5]) != 0 : true
        pinOrder := parts.Length >= 6 ? Max(1, SafeInteger(parts[6])) : 1
        section := parts.Length >= 7 ? Trim(parts[7]) : currentSection
        if (section = "")
            section := currentSection
        x := parts.Length >= 8 ? SafeInteger(parts[8]) : 0
        y := parts.Length >= 9 ? SafeInteger(parts[9]) : 0
        w := parts.Length >= 10 ? SafeInteger(parts[10]) : 0
        h := parts.Length >= 11 ? SafeInteger(parts[11]) : 0

        EnsureParsedImportSection(data, section)
        color := {
            hex: StrUpper(hex),
            rgb: rgb,
            name: name != "" ? name : section " " role,
            role: role != "" ? role : "Base",
            section: section,
            pinned: pinned,
            pinOrder: pinOrder,
            x: x,
            y: y,
            w: w,
            h: h
        }
        data.sections[section].Push(color)
    }

    return data
}

EnsureParsedImportSection(data, sectionName) {
    if !data.sections.Has(sectionName) {
        data.sections[sectionName] := []
        data.sectionOrder.Push(sectionName)
    }
}

PopulateImportReviewSections(g) {
    g.sectionList.Delete()
    for sectionName in g.importData.sectionOrder {
        count := g.importData.sections[sectionName].Length
        g.sectionList.Add([sectionName " (" count ")"])
    }
}

PopulateImportReviewColors(g) {
    g.colorList.Delete()
    g.refColorMap := Map()
    if (g.selectedSectionIdx < 1 || g.selectedSectionIdx > g.importData.sectionOrder.Length)
        return

    sectionName := g.importData.sectionOrder[g.selectedSectionIdx]
    colors := g.importData.sections[sectionName]

    idx := 0
    for color in colors {
        idx++
        bounds := color.x "," color.y "," color.w "," color.h
        g.colorList.Add("", "#" color.hex, color.name, color.role, bounds)
        g.refColorMap[idx] := color
    }
}

ImportReviewSelectSection(app, g) {
    g.selectedSectionIdx := g.sectionList.Value
    g.selectedColorIdx := 0
    PopulateImportReviewColors(g)
    if g.refColorMap.Has(1) {
        g.colorList.Modify(1, "Select Focus")
        ImportReviewColorFocus(app, g, 1)
    } else {
        ImportReviewClearEditors(g)
    }
}

ImportReviewColorFocus(app, g, item) {
    if !item || !g.refColorMap.Has(item)
        return
    g.selectedColorIdx := item
    color := g.refColorMap[item]
    ImportReviewLoadSelectedColor(g, color)
}

ImportReviewLoadSelectedColor(g, color) {
    g.preview.Opt("Background" color.hex)
    g.selectedHex.Value := "#" color.hex
    g.selectedRGB.Value := color.rgb != "" ? color.rgb : ImportReviewGetRGBFromHex(color.hex)
    g.nameEdit.Value := color.name
    g.sectionEdit.Value := color.section
    g.hexEdit.Value := color.hex
    g.rgbEdit.Value := color.rgb != "" ? color.rgb : ImportReviewGetRGBFromHex(color.hex)
    g.xEdit.Value := color.x
    g.yEdit.Value := color.y
    g.wEdit.Value := color.w
    g.hEdit.Value := color.h
    g.roleEdit.Choose(GetRoleIndex(color.role))
}

ImportReviewClearEditors(g) {
    g.preview.Opt("Background808080")
    g.selectedHex.Value := "#808080"
    g.selectedRGB.Value := "0,0,0"
    g.nameEdit.Value := ""
    g.sectionEdit.Value := ""
    g.hexEdit.Value := ""
    g.rgbEdit.Value := ""
    g.xEdit.Value := 0
    g.yEdit.Value := 0
    g.wEdit.Value := 0
    g.hEdit.Value := 0
    g.roleEdit.Choose(1)
}

GetRoleIndex(role) {
    roles := DefaultImportReviewRoles()
    for i, itemRole in roles {
        if (itemRole = role)
            return i
    }
    return 1
}

ImportModeChanged(g) {
    mode := g.importMode.Value
    if (mode = 3) {
        g.targetPaletteLabel.Opt("+Hidden")
        g.targetPalette.Opt("+Hidden")
        g.newPaletteNameLabel.Opt("-Hidden")
        g.newPaletteName.Opt("-Hidden")
    } else {
        g.newPaletteNameLabel.Opt("+Hidden")
        g.newPaletteName.Opt("+Hidden")
        g.targetPaletteLabel.Opt("-Hidden")
        g.targetPalette.Opt("-Hidden")
    }
}

ImportReviewApplyColorEdits(app, g) {
    if (g.selectedSectionIdx < 1 || g.selectedColorIdx < 1 || !g.refColorMap.Has(g.selectedColorIdx))
        return

    oldSection := g.importData.sectionOrder[g.selectedSectionIdx]
    color := g.refColorMap[g.selectedColorIdx]

    newHex := NormalizeImportReviewHex(g.hexEdit.Value)
    newRgb := NormalizeImportReviewRgb(g.rgbEdit.Value)
    if (newHex = "" && newRgb = "") {
        ImportReviewToast(app, "Enter a valid HEX or RGB value")
        return
    }
    if (newHex = "")
        newHex := RGBToHexString(newRgb)
    if (newRgb = "")
        newRgb := ImportReviewGetRGBFromHex(newHex)
    if (newRgb != ImportReviewGetRGBFromHex(newHex))
        newRgb := ImportReviewGetRGBFromHex(newHex)

    newSection := Trim(g.sectionEdit.Value)
    if (newSection = "")
        newSection := oldSection

    color.hex := newHex
    color.rgb := newRgb
    color.name := Trim(g.nameEdit.Value) != "" ? Trim(g.nameEdit.Value) : newSection " " g.roleEdit.Text
    color.role := g.roleEdit.Text
    color.x := Max(0, SafeInteger(g.xEdit.Value))
    color.y := Max(0, SafeInteger(g.yEdit.Value))
    color.w := Max(1, SafeInteger(g.wEdit.Value))
    color.h := Max(1, SafeInteger(g.hEdit.Value))

    if (newSection != oldSection) {
        oldColors := g.importData.sections[oldSection]
        removeIdx := FindImportColorIndex(oldColors, color)
        if (removeIdx > 0)
            oldColors.RemoveAt(removeIdx)

        EnsureParsedImportSection(g.importData, newSection)
        color.section := newSection
        g.importData.sections[newSection].Push(color)

        if (oldColors.Length = 0 && oldSection = "Default")
            EnsureParsedImportSection(g.importData, oldSection)
    } else {
        color.section := oldSection
    }

    PopulateImportReviewSections(g)
    newSectionIdx := FindImportSectionIndex(g.importData, color.section)
    if (newSectionIdx > 0) {
        g.selectedSectionIdx := newSectionIdx
        g.sectionList.Choose(newSectionIdx)
        PopulateImportReviewColors(g)
        focusIdx := FindImportColorIndex(g.importData.sections[color.section], color)
        if (focusIdx > 0) {
            g.selectedColorIdx := focusIdx
            g.colorList.Modify(focusIdx, "Select Focus")
            g.refColorMap[focusIdx] := color
            ImportReviewLoadSelectedColor(g, color)
        }
    }
}

ImportReviewDeleteColor(app, g) {
    if (g.selectedSectionIdx < 1 || g.selectedColorIdx < 1)
        return

    sectionName := g.importData.sectionOrder[g.selectedSectionIdx]
    colors := g.importData.sections[sectionName]
    if (g.selectedColorIdx > colors.Length)
        return

    colors.RemoveAt(g.selectedColorIdx)
    g.selectedColorIdx := 0
    PopulateImportReviewSections(g)
    PopulateImportReviewColors(g)
    ImportReviewClearEditors(g)
}

ImportReviewRenameSection(app, g) {
    if (g.selectedSectionIdx < 1)
        return

    oldName := g.importData.sectionOrder[g.selectedSectionIdx]
    ImportReviewShowInputDialog(app, "Enter new section name:", "Rename Section", (newName) => ImportReviewRenameSectionConfirm(app, g, oldName, newName), oldName)
}

ImportReviewRenameSectionConfirm(app, g, oldName, newName) {
    newName := Trim(newName)
    if (newName = "" || newName = oldName)
        return

    if g.importData.sections.Has(newName) {
        ImportReviewToast(app, "Section already exists")
        return
    }

    colors := g.importData.sections[oldName]
    g.importData.sections[newName] := colors
    g.importData.sections.Delete(oldName)
    g.importData.sectionOrder[g.selectedSectionIdx] := newName

    if g.importData.sectionTags.Has(oldName) {
        g.importData.sectionTags[newName] := g.importData.sectionTags[oldName]
        g.importData.sectionTags.Delete(oldName)
    }

    for color in colors
        color.section := newName

    PopulateImportReviewSections(g)
    g.sectionList.Choose(g.selectedSectionIdx)
    PopulateImportReviewColors(g)
}

ImportReviewMergeSection(app, g) {
    if (g.selectedSectionIdx < 1)
        return

    sourceName := g.importData.sectionOrder[g.selectedSectionIdx]
    if (g.importData.sectionOrder.Length < 2) {
        ImportReviewToast(app, "No other sections to merge with")
        return
    }

    targetIdx := InputSelectSection(app, "Merge '" sourceName "' into:", g.importData.sectionOrder, g.selectedSectionIdx)
    if (targetIdx < 1)
        return

    targetName := g.importData.sectionOrder[targetIdx]
    sourceColors := g.importData.sections[sourceName]
    for color in sourceColors {
        color.section := targetName
        g.importData.sections[targetName].Push(color)
    }

    if g.importData.sectionTags.Has(sourceName) && !g.importData.sectionTags.Has(targetName)
        g.importData.sectionTags[targetName] := g.importData.sectionTags[sourceName]
    if g.importData.sectionTags.Has(sourceName)
        g.importData.sectionTags.Delete(sourceName)

    g.importData.sections.Delete(sourceName)
    g.importData.sectionOrder.RemoveAt(g.selectedSectionIdx)
    g.selectedSectionIdx := targetIdx > g.importData.sectionOrder.Length ? g.importData.sectionOrder.Length : targetIdx
    g.selectedColorIdx := 0

    PopulateImportReviewSections(g)
    if (g.selectedSectionIdx > 0) {
        g.sectionList.Choose(g.selectedSectionIdx)
        PopulateImportReviewColors(g)
    }
    ImportReviewClearEditors(g)
}

InputSelectSection(app, prompt, sectionOrder, excludeIdx := 0) {
    items := []
    for i, name in sectionOrder {
        if (i != excludeIdx)
            items.Push(i ". " name)
    }
    if items.Length = 0
        return 0
    return WaitChoiceDialog(app, "Select Section", prompt, items, sectionOrder, excludeIdx)
}

WaitChoiceDialog(app, title, prompt, items, sectionOrder, excludeIdx) {
    selectedText := ""
    g := Gui("+AlwaysOnTop -Caption +ToolWindow +Border", title)
    g.BackColor := "323338"
    g.SetFont("s9", "Consolas")
    g.MarginX := 16
    g.MarginY := 12
    g.AddText("cFFFFFF w280", prompt)
    g.list := g.AddListBox("w280 h120 y+6", items)
    g.list.Value := 1
    btnOk := g.AddButton("w130 h28 y+10", "OK")
    btnCancel := g.AddButton("w130 h28 x+10", "Cancel")
    btnOk.OnEvent("Click", (*) => (selectedText := g.list.Text, g.Destroy()))
    btnCancel.OnEvent("Click", (*) => g.Destroy())
    g.OnEvent("Close", (*) => g.Destroy())
    g.Show("AutoSize Center")

    while IsObject(g) && g.Hwnd
        Sleep 50

    if (selectedText = "")
        return 0
    idx := SafeInteger(StrSplit(selectedText, ".")[1])
    if (idx < 1 || idx > sectionOrder.Length || idx = excludeIdx)
        return 0
    return idx
}

ImportReviewDeleteSection(app, g) {
    if (g.selectedSectionIdx < 1)
        return
    sectionName := g.importData.sectionOrder[g.selectedSectionIdx]
    ImportReviewShowConfirmDialog(app, "Delete section '" sectionName "' and all its colors?", "Confirm Delete", (*) => ImportReviewDeleteSectionConfirm(app, g, sectionName))
}

ImportReviewDeleteSectionConfirm(app, g, sectionName) {
    g.importData.sections.Delete(sectionName)
    if g.importData.sectionTags.Has(sectionName)
        g.importData.sectionTags.Delete(sectionName)
    g.importData.sectionOrder.RemoveAt(g.selectedSectionIdx)
    g.selectedSectionIdx := 0
    g.selectedColorIdx := 0
    PopulateImportReviewSections(g)
    g.colorList.Delete()
    ImportReviewClearEditors(g)
}

ImportReviewApply(app, g) {
    totalColors := 0
    for sectionName in g.importData.sectionOrder
        totalColors += g.importData.sections[sectionName].Length

    if (totalColors = 0) {
        ImportReviewToast(app, "No colors to import")
        return
    }

    importMode := g.importMode.Value ? g.importMode.Value : 2

    if (importMode = 3) {
        paletteName := Trim(g.newPaletteName.Value)
        if (paletteName = "") {
            ImportReviewToast(app, "Enter a palette name")
            return
        }
        basePath := A_ScriptDir "\color\"
        if !DirExist(basePath)
            DirCreate(basePath)
        filePath := basePath . paletteName ".txt"
        counter := 1
        while FileExist(filePath) {
            filePath := basePath . paletteName "_" counter ".txt"
            counter++
        }
        p := ImportReviewCreatePalette(paletteName, filePath)
        app.palettes[paletteName] := p
        app.paletteOrder.Push(paletteName)
        app.activePalette := p
    } else {
        targetSelection := g.targetPalette.Value
        if !targetSelection {
            ImportReviewToast(app, "Select a target palette")
            return
        }
        paletteName := g.paletteNames[targetSelection]
        p := app.palettes[paletteName]
        if !p {
            ImportReviewToast(app, "Palette not found")
            return
        }
        if (importMode = 1) {
            p.colors := []
            p.map := Map()
            p.idMap := Map()
            p.sections := []
            p.sectionPositions := Map()
            ImportReviewEnsureDefaultSection(p)
        }
        app.activePalette := p
    }

    for sectionName in g.importData.sectionOrder {
        colors := g.importData.sections[sectionName]
        for color in colors {
            newItem := ImportReviewCreateItem(color.hex, color.rgb, color.name, color.role)
            newItem.section := color.section
            newItem.isSaved := true
            newItem.pinned := color.pinned
            newItem.pinOrder := color.pinOrder
            ImportReviewAddColor(p, newItem)
        }

        if g.importData.sectionTags.Has(sectionName) {
            section := ImportReviewGetSectionObjectByName(p, sectionName)
            if section && section.HasOwnProp("tag")
                section.tag := g.importData.sectionTags[sectionName]
        }
    }

    if (g.trainingCheck.Value)
        SaveImportTrainingSample(app, g.importData, g.sourceImagePath)

    ImportReviewMutate(app, (pal) => 0)
    ImportReviewSaveHistory(app)
    ImportReviewLoadHistory(app)
    if app.historyVisible
        ImportReviewEmit(app, "history_changed")
    app.ui.generation++
    ImportReviewRebuildUI(app)

    ImportReviewCancel(app, g, false)
    modeLabel := importMode = 1 ? "Replaced" : (importMode = 3 ? "Created" : "Inserted")
    ImportReviewToast(app, "Imported " totalColors " colors (" modeLabel ")")
}

ImportReviewCancel(app, g, showMsg := true) {
    reviewPath := g.reviewPath
    imagePath := g.sourceImagePath
    cleanupTempImage := g.cleanupTempImage

    try g.Destroy()
    app.importReviewGui := 0

    if (reviewPath != "" && FileExist(reviewPath))
        try FileDelete(reviewPath)
    if (cleanupTempImage && imagePath != "" && FileExist(imagePath))
        try FileDelete(imagePath)

    if showMsg
        ImportReviewToast(app, "Import cancelled")
}

NormalizeImportReviewHex(value) {
    value := StrUpper(Trim(value))
    if (InStr(value, "#") = 1)
        value := SubStr(value, 2)
    return RegExMatch(value, "^[0-9A-F]{6}$") ? value : ""
}

NormalizeImportReviewRgb(value) {
    value := Trim(value)
    if !RegExMatch(value, "^\s*\d{1,3}\s*,\s*\d{1,3}\s*,\s*\d{1,3}\s*$")
        return ""

    parts := StrSplit(value, ",")
    r := Max(0, Min(255, SafeInteger(parts[1])))
    g := Max(0, Min(255, SafeInteger(parts[2])))
    b := Max(0, Min(255, SafeInteger(parts[3])))
    return r "," g "," b
}

RGBToHexString(rgbText) {
    parts := StrSplit(rgbText, ",")
    if (parts.Length < 3)
        return ""
    return Format("{:02X}{:02X}{:02X}", SafeInteger(parts[1]), SafeInteger(parts[2]), SafeInteger(parts[3]))
}

SafeInteger(value, fallback := 0) {
    value := Trim(value)
    if RegExMatch(value, "^-?\d+$")
        return Integer(value)
    return fallback
}

FindImportSectionIndex(importData, sectionName) {
    for idx, name in importData.sectionOrder {
        if (name = sectionName)
            return idx
    }
    return 0
}

FindImportColorIndex(colors, targetColor) {
    for idx, color in colors {
        if (color = targetColor)
            return idx
    }
    return 0
}

GetImportTrainingPath() {
    basePath := A_ScriptDir "\color\"
    if !DirExist(basePath)
        DirCreate(basePath)
    return basePath "import_training.txt"
}

SaveImportTrainingSample(app, importData, imagePath := "") {
    trainingPath := GetImportTrainingPath()
    samplePrefix := A_NowUTC "_" Random(1000, 9999)
    sourceName := importData.sourceName != "" ? importData.sourceName : (imagePath != "" ? RegExReplace(imagePath, "^.*\\") : "unknown")
    sourceFamily := GetTrainingSourceFamily(sourceName)
    lines := []

    for sectionIdx, sectionName in importData.sectionOrder {
        colors := importData.sections[sectionName]
        if (colors.Length = 0)
            continue

        bounds := ComputeImportSectionBounds(colors)
        sampleId := samplePrefix "_" sectionIdx
        tag := importData.sectionTags.Has(sectionName) ? importData.sectionTags[sectionName] : ""
        lines.Push("#TRAINSECTION|" EscapeTrainingField(sampleId) "|" EscapeTrainingField(sectionName) "|" EscapeTrainingField(tag) "|" importData.imageWidth "|" importData.imageHeight "|" bounds.x "|" bounds.y "|" bounds.w "|" bounds.h "|" EscapeTrainingField(sourceName) "|" EscapeTrainingField(sourceFamily))

        for color in colors {
            lines.Push(
                "#TRAINITEM|"
                EscapeTrainingField(sampleId) "|"
                EscapeTrainingField(color.role) "|"
                EscapeTrainingField(color.hex) "|"
                color.x "|"
                color.y "|"
                color.w "|"
                color.h "|"
                EscapeTrainingField(color.name)
            )
        }
    }

    if (lines.Length = 0)
        return

    content := ImportReviewJoinLines(lines) "`r`n"
    FileAppend(content, trainingPath, "UTF-8")
}

ImportReviewSaveTrainingPreset(app, g) {
    totalColors := 0
    for sectionName in g.importData.sectionOrder
        totalColors += g.importData.sections[sectionName].Length

    if (totalColors = 0) {
        ImportReviewToast(app, "No colors to save as preset")
        return
    }

    sourceName := g.importData.sourceName != "" ? g.importData.sourceName : "training_preset"
    ImportReviewShowInputDialog(app, "Preset/source label:", "Save Training Preset", (newName) => ImportReviewSaveTrainingPresetConfirm(app, g, newName), sourceName)
}

ImportReviewSaveTrainingPresetConfirm(app, g, newName) {
    presetName := Trim(newName)
    if (presetName = "")
        return

    importData := {
        sections: g.importData.sections,
        sectionOrder: g.importData.sectionOrder,
        sectionTags: g.importData.sectionTags,
        imageWidth: g.importData.imageWidth,
        imageHeight: g.importData.imageHeight,
        sourceName: presetName
    }

    SaveImportTrainingSample(app, importData, presetName)
    ImportReviewToast(app, "Saved training preset: " presetName)
}

OpenImportTrainingCanvas(app, reviewGui) {
    imagePath := reviewGui.sourceImagePath
    if (imagePath = "" || !FileExist(imagePath)) {
        ImportReviewToast(app, "No source image available for training")
        return
    }

    CloseImportTrainingCanvas()

    data := {
        sections: Map(),
        sectionOrder: [],
        sectionTags: Map(),
        imageWidth: reviewGui.importData.imageWidth,
        imageHeight: reviewGui.importData.imageHeight,
        sourceName: reviewGui.importData.sourceName != "" ? reviewGui.importData.sourceName : RegExReplace(imagePath, "^.*\\")
    }

    imageW := Max(1, data.imageWidth)
    imageH := Max(1, data.imageHeight)
    maxW := 760
    maxH := 560
    scale := Min(maxW / imageW, maxH / imageH)
    if (scale <= 0)
        scale := 1
    displayW := Max(120, Round(imageW * scale))
    displayH := Max(120, Round(imageH * scale))

    g := Gui("+AlwaysOnTop +Resize +ToolWindow +Border", "Training Canvas")
    g.BackColor := "2B2D31"
    g.SetFont("s9", "Consolas")
    g.MarginX := 12
    g.MarginY := 10
    g.parentReview := reviewGui
    g.trainingData := data
    g.sourceImagePath := imagePath
    g.displayW := displayW
    g.displayH := displayH
    g.imageWidth := imageW
    g.imageHeight := imageH
    g.selectedBlockRow := 0

    g.AddText("x10 y10 cFFFFFF", "Use the X and Y rulers to define the block area.")
    g.AddText("x10 y28 c909090", "Click image = set X/Y start  |  Ctrl+Click image = set X/Y end  |  colored ruler markers show the exact aligned positions.")

    imageX := 92
    picY := 118
    rulerTopY := 50
    g.AddText("x" imageX " y" rulerTopY " cAAAAAA", "X Start")
    g.xStartSlider := g.AddSlider("x" imageX " y" (rulerTopY + 16) " w" displayW " h20 Range0-" imageW " TickInterval50", 0)
    g.xStartValue := g.AddText("x" (imageX + displayW - 60) " y" rulerTopY " w60 Right cFFFFFF", "0")
    g.AddText("x" imageX " y" (rulerTopY + 38) " cAAAAAA", "X End")
    g.xEndSlider := g.AddSlider("x" imageX " y" (rulerTopY + 54) " w" displayW " h20 Range0-" imageW " TickInterval50", imageW)
    g.xEndValue := g.AddText("x" (imageX + displayW - 60) " y" (rulerTopY + 38) " w60 Right cFFFFFF", imageW "")
    g.xStartBar := g.AddText("x" imageX " y" (rulerTopY + 78) " w" displayW " h3 Background666666")
    g.xEndBar := g.AddText("x" imageX " y" (rulerTopY + 84) " w" displayW " h3 Background666666")
    g.xStartMarker := g.AddText("x" imageX " y" (rulerTopY + 74) " w2 h11 Background00C8FF")
    g.xEndMarker := g.AddText("x" imageX " y" (rulerTopY + 80) " w2 h11 BackgroundFFD24A")

    g.AddText("x10 y" picY " cAAAAAA", "Y Start")
    g.yStartSlider := g.AddSlider("x10 y" (picY + 18) " w20 h" displayH " Vertical Range0-" imageH " TickInterval50", 0)
    g.yStartValue := g.AddText("x8 y" (picY + displayH + 22) " w30 Center cFFFFFF", "0")
    g.AddText("x36 y" picY " cAAAAAA", "Y End")
    g.yEndSlider := g.AddSlider("x36 y" (picY + 18) " w20 h" displayH " Vertical Range0-" imageH " TickInterval50", imageH)
    g.yEndValue := g.AddText("x34 y" (picY + displayH + 22) " w30 Center cFFFFFF", imageH "")
    g.yStartBar := g.AddText("x61 y" picY " w3 h" displayH " Background666666")
    g.yEndBar := g.AddText("x66 y" picY " w3 h" displayH " Background666666")
    g.yStartMarker := g.AddText("x58 y" picY " w11 h2 Background00C8FF")
    g.yEndMarker := g.AddText("x63 y" picY " w11 h2 BackgroundFFD24A")

    g.imageCtrl := g.AddPicture("x" imageX " y" picY " w" displayW " h" displayH " +Border", imagePath)
    g.imageCtrl.OnEvent("Click", (*) => ImportTrainingCanvasImageClick(g))

    for _, ctrl in [g.xStartSlider, g.xEndSlider, g.yStartSlider, g.yEndSlider]
        ctrl.OnEvent("Change", (*) => ImportTrainingCanvasSliderChanged(g))

    sideX := imageX + displayW + 28
    g.AddText("x" sideX " y" picY " cAAAAAA", "Block Data")
    g.preview := g.AddProgress("x" sideX " y" (picY + 20) " w54 h42 Background808080")
    g.hexText := g.AddText("x" (sideX + 64) " y" (picY + 20) " w180 cFFFFFF", "#808080")
    g.rgbText := g.AddText("x" (sideX + 64) " y" (picY + 40) " w180 cAAAAAA", "0,0,0")

    formY := picY + 74
    g.AddText("x" sideX " y" formY " cAAAAAA", "Section")
    g.sectionNameEdit := g.AddEdit("x" sideX " y" (formY + 16) " w180 h22", "Default")
    g.AddText("x" (sideX + 190) " y" formY " cAAAAAA", "Section Tag")
    g.sectionTagEdit := g.AddEdit("x" (sideX + 190) " y" (formY + 16) " w120 h22")

    g.AddText("x" sideX " y" (formY + 48) " cAAAAAA", "Name")
    g.nameEdit := g.AddEdit("x" sideX " y" (formY + 64) " w180 h22", "Block")
    g.AddText("x" (sideX + 190) " y" (formY + 48) " cAAAAAA", "Role")
    g.roleEdit := g.AddDropDownList("x" (sideX + 190) " y" (formY + 64) " w120", DefaultImportReviewRoles())

    g.AddText("x" sideX " y" (formY + 96) " cAAAAAA", "HEX")
    g.hexEdit := g.AddEdit("x" sideX " y" (formY + 112) " w180 h22")
    g.AddText("x" (sideX + 190) " y" (formY + 96) " cAAAAAA", "RGB")
    g.rgbEdit := g.AddEdit("x" (sideX + 190) " y" (formY + 112) " w120 h22")
    g.hexEdit.OnEvent("Change", (*) => ImportTrainingCanvasHexChanged(g))

    g.AddText("x" sideX " y" (formY + 144) " cAAAAAA", "X, Y, W, H")
    g.xEdit := g.AddEdit("x" sideX " y" (formY + 160) " w55 h22")
    g.yEdit := g.AddEdit("x" (sideX + 60) " y" (formY + 160) " w55 h22")
    g.wEdit := g.AddEdit("x" (sideX + 120) " y" (formY + 160) " w55 h22")
    g.hEdit := g.AddEdit("x" (sideX + 180) " y" (formY + 160) " w55 h22")

    btnY := formY + 196
    g.btnAdd := g.AddButton("x" sideX " y" btnY " w150 h28", "Add Block")
    g.btnDelete := g.AddButton("x" (sideX + 160) " y" btnY " w150 h28", "Delete Block")
    g.btnAdd.OnEvent("Click", (*) => ImportTrainingCanvasAddBlock(app, g))
    g.btnDelete.OnEvent("Click", (*) => ImportTrainingCanvasDeleteBlock(app, g))

    listY := btnY + 40
    g.AddText("x" sideX " y" listY " cAAAAAA", "Training Blocks")
    g.blockList := g.AddListView("x" sideX " y" (listY + 18) " w310 h220 Grid", ["Section", "Role", "HEX", "Bounds"])
    g.blockList.ModifyCol(1, 88)
    g.blockList.ModifyCol(2, 76)
    g.blockList.ModifyCol(3, 76)
    g.blockList.ModifyCol(4, 88)
    g.blockList.OnEvent("ItemFocus", (ctrl, item) => ImportTrainingCanvasFocusBlock(g, item))

    bottomY := Max(picY + displayH + 42, listY + 252)
    g.btnApplyReview := g.AddButton("x10 y" bottomY " w180 h30", "Apply To Review")
    g.btnSavePreset := g.AddButton("x200 y" bottomY " w180 h30", "Save Training Preset")
    g.btnClose := g.AddButton("x390 y" bottomY " w180 h30", "Close")
    g.btnApplyReview.OnEvent("Click", (*) => ImportTrainingCanvasApplyToReview(app, g))
    g.btnSavePreset.OnEvent("Click", (*) => ImportTrainingCanvasSavePreset(app, g))
    g.btnClose.OnEvent("Click", (*) => CloseImportTrainingCanvas(g))
    g.OnEvent("Close", (*) => CloseImportTrainingCanvas(g))
    g.OnEvent("Escape", (*) => CancelImportTrainingCanvasSelection(g))

    g.Show("w" (sideX + 330) " h" (bottomY + 50) " Center")
    state := GetImportTrainerState()
    state.gui := g
    state.app := app
    state.selection := 0

    if (g.roleEdit.Text = "")
        g.roleEdit.Choose(1)
    ImportTrainingCanvasSliderChanged(g)
}

GetImportTrainerState() {
    static state := { gui: 0, app: 0, selection: 0 }
    return state
}

CloseImportTrainingCanvas(g := 0) {
    state := GetImportTrainerState()
    target := g
    if !IsObject(target)
        target := state.gui
    if IsObject(target) {
        try target.Destroy()
    }
    state.gui := 0
    state.app := 0
    state.selection := 0
}

ImportTrainingCanvasHexChanged(g) {
    hex := NormalizeImportReviewHex(g.hexEdit.Value)
    if (hex = "")
        return
    rgb := ImportReviewGetRGBFromHex(hex)
    g.rgbEdit.Value := rgb
    g.hexText.Value := "#" hex
    g.rgbText.Value := rgb
    g.preview.Opt("Background" hex)
    if (Trim(g.nameEdit.Value) = "" || RegExMatch(g.nameEdit.Value, "^Block( [0-9A-F]{6})?$"))
        g.nameEdit.Value := "Block " hex
}

ImportTrainingCanvasSliderChanged(g) {
    x1 := g.xStartSlider.Value
    x2 := g.xEndSlider.Value
    y1 := g.yStartSlider.Value
    y2 := g.yEndSlider.Value

    g.xStartValue.Value := x1
    g.xEndValue.Value := x2
    g.yStartValue.Value := y1
    g.yEndValue.Value := y2
    ImportTrainingCanvasUpdateRulerMarkers(g, x1, x2, y1, y2)

    x := Min(x1, x2)
    y := Min(y1, y2)
    w := Max(1, Abs(x2 - x1))
    h := Max(1, Abs(y2 - y1))

    state := GetImportTrainerState()
    state.selection := { x: x, y: y, w: w, h: h }
    ImportTrainingCanvasPopulateSelectionFields(g)
}

ImportTrainingCanvasUpdateRulerMarkers(g, x1, x2, y1, y2) {
    g.imageCtrl.GetPos(&imgX, &imgY)
    g.xStartMarker.GetPos(, &xStartY)
    g.xEndMarker.GetPos(, &xEndY)
    g.yStartMarker.GetPos(&yStartX)
    g.yEndMarker.GetPos(&yEndX)
    scaleX := g.displayW / g.imageWidth
    scaleY := g.displayH / g.imageHeight
    dx1 := Round(x1 * scaleX)
    dx2 := Round(x2 * scaleX)
    dy1 := Round(y1 * scaleY)
    dy2 := Round(y2 * scaleY)
    g.xStartMarker.Move(imgX + dx1, xStartY, 2, 11)
    g.xEndMarker.Move(imgX + dx2, xEndY, 2, 11)
    g.yStartMarker.Move(yStartX, imgY + dy1, 11, 2)
    g.yEndMarker.Move(yEndX, imgY + dy2, 11, 2)
}

ImportTrainingCanvasImageClick(g) {
    rect := GetImportTrainingCanvasControlRect(g.imageCtrl)
    MouseGetPos(&mx, &my)
    relX := Max(0, Min(rect.w, mx - rect.x))
    relY := Max(0, Min(rect.h, my - rect.y))
    imgX := Round(relX * (g.imageWidth / g.displayW))
    imgY := Round(relY * (g.imageHeight / g.displayH))

    if GetKeyState("Ctrl", "P") {
        g.xEndSlider.Value := imgX
        g.yEndSlider.Value := imgY
    } else {
        g.xStartSlider.Value := imgX
        g.yStartSlider.Value := imgY
    }

    ImportTrainingCanvasSliderChanged(g)
}

CancelImportTrainingCanvasSelection(g) {
    GetImportTrainerState().selection := 0
}

GetImportTrainingCanvasControlRect(ctrl) {
    rect := Buffer(16, 0)
    DllCall("GetWindowRect", "ptr", ctrl.Hwnd, "ptr", rect.Ptr)
    left := NumGet(rect, 0, "int")
    top := NumGet(rect, 4, "int")
    right := NumGet(rect, 8, "int")
    bottom := NumGet(rect, 12, "int")
    return { x: left, y: top, w: right - left, h: bottom - top }
}

ImportTrainingCanvasPopulateSelectionFields(g) {
    state := GetImportTrainerState()
    if !IsObject(state.selection)
        return

    sel := state.selection
    g.xEdit.Value := sel.x
    g.yEdit.Value := sel.y
    g.wEdit.Value := sel.w
    g.hEdit.Value := sel.h

    rect := GetImportTrainingCanvasControlRect(g.imageCtrl)
    displayCenterX := Round((sel.x + Floor(sel.w / 2)) * (g.displayW / g.imageWidth))
    displayCenterY := Round((sel.y + Floor(sel.h / 2)) * (g.displayH / g.imageHeight))
    centerX := rect.x + displayCenterX
    centerY := rect.y + displayCenterY
    pixel := PixelGetColor(centerX, centerY, "RGB")
    hex := Format("{:06X}", pixel & 0xFFFFFF)
    rgb := ImportReviewGetRGBFromHex(hex)

    g.hexEdit.Value := hex
    g.rgbEdit.Value := rgb
    g.hexText.Value := "#" hex
    g.rgbText.Value := rgb
    g.preview.Opt("Background" hex)

    if (Trim(g.nameEdit.Value) = "" || g.nameEdit.Value = "Block")
        g.nameEdit.Value := "Block " hex
}


ImportTrainingCanvasAddBlock(app, g) {
    sectionName := Trim(g.sectionNameEdit.Value)
    if (sectionName = "")
        sectionName := "Default"

    hex := NormalizeImportReviewHex(g.hexEdit.Value)
    rgb := NormalizeImportReviewRgb(g.rgbEdit.Value)
    if (hex = "" && rgb != "")
        hex := RGBToHexString(rgb)
    if (rgb = "" && hex != "")
        rgb := ImportReviewGetRGBFromHex(hex)
    if (hex = "" || rgb = "") {
        ImportReviewToast(app, "Select a block and enter valid HEX/RGB")
        return
    }

    x := SafeInteger(g.xEdit.Value, -1)
    y := SafeInteger(g.yEdit.Value, -1)
    w := SafeInteger(g.wEdit.Value, 0)
    h := SafeInteger(g.hEdit.Value, 0)
    if (x < 0 || y < 0 || w <= 0 || h <= 0) {
        ImportReviewToast(app, "Draw a rectangle first")
        return
    }

    role := Trim(g.roleEdit.Text)
    if (role = "")
        role := "Base"
    name := Trim(g.nameEdit.Value)
    if (name = "")
        name := sectionName " " role

    if !g.trainingData.sections.Has(sectionName) {
        g.trainingData.sections[sectionName] := []
        g.trainingData.sectionOrder.Push(sectionName)
    }
    sectionTag := NormalizeImportReviewHex(g.sectionTagEdit.Value)
    if (sectionTag != "")
        g.trainingData.sectionTags[sectionName] := sectionTag

    colors := g.trainingData.sections[sectionName]
    colors.Push({
        hex: hex,
        rgb: rgb,
        name: name,
        role: role,
        section: sectionName,
        pinned: true,
        pinOrder: colors.Length + 1,
        x: x,
        y: y,
        w: w,
        h: h
    })

    PopulateImportTrainingCanvasBlocks(g)
    ImportReviewToast(app, "Added training block")
}

PopulateImportTrainingCanvasBlocks(g) {
    g.blockList.Delete()
    row := 0
    for sectionName in g.trainingData.sectionOrder {
        for color in g.trainingData.sections[sectionName] {
            row++
            bounds := color.x "," color.y "," color.w "," color.h
            g.blockList.Add(, sectionName, color.role, "#" color.hex, bounds)
        }
    }
}

ImportTrainingCanvasFocusBlock(g, row) {
    g.selectedBlockRow := row
    block := GetImportTrainingCanvasBlockByRow(g, row)
    if !IsObject(block)
        return

    g.sectionNameEdit.Value := block.section
    g.sectionTagEdit.Value := g.trainingData.sectionTags.Has(block.section) ? g.trainingData.sectionTags[block.section] : ""
    g.nameEdit.Value := block.name
    ChooseImportTrainingCanvasRole(g.roleEdit, block.role)
    g.hexEdit.Value := block.hex
    g.rgbEdit.Value := block.rgb
    g.xEdit.Value := block.x
    g.yEdit.Value := block.y
    g.wEdit.Value := block.w
    g.hEdit.Value := block.h
    g.hexText.Value := "#" block.hex
    g.rgbText.Value := block.rgb
    g.preview.Opt("Background" block.hex)
}

GetImportTrainingCanvasBlockByRow(g, row) {
    idx := 0
    for sectionName in g.trainingData.sectionOrder {
        for color in g.trainingData.sections[sectionName] {
            idx++
            if (idx = row)
                return color
        }
    }
    return 0
}

ImportTrainingCanvasDeleteBlock(app, g) {
    row := g.blockList.GetNext(0, "F")
    if (row = 0)
        row := g.selectedBlockRow
    if (row = 0) {
        ImportReviewToast(app, "Select a block first")
        return
    }

    idx := 0
    for sectionName in g.trainingData.sectionOrder {
        colors := g.trainingData.sections[sectionName]
        for colorIdx, color in colors {
            idx++
            if (idx = row) {
                colors.RemoveAt(colorIdx)
                if (colors.Length = 0) {
                    g.trainingData.sections.Delete(sectionName)
                    secIdx := FindImportSectionIndex(g.trainingData, sectionName)
                    if (secIdx)
                        g.trainingData.sectionOrder.RemoveAt(secIdx)
                    if g.trainingData.sectionTags.Has(sectionName)
                        g.trainingData.sectionTags.Delete(sectionName)
                }
                PopulateImportTrainingCanvasBlocks(g)
                ImportReviewToast(app, "Removed training block")
                return
            }
        }
    }
}

ChooseImportTrainingCanvasRole(ctrl, role) {
    for idx, value in DefaultImportReviewRoles() {
        if (value = role) {
            ctrl.Choose(idx)
            return
        }
    }
}

ImportTrainingCanvasApplyToReview(app, g) {
    total := 0
    for sectionName in g.trainingData.sectionOrder
        total += g.trainingData.sections[sectionName].Length
    if (total = 0) {
        ImportReviewToast(app, "No training blocks to apply")
        return
    }

    reviewGui := g.parentReview
    for sectionName in g.trainingData.sectionOrder {
        EnsureParsedImportSection(reviewGui.importData, sectionName)
        if g.trainingData.sectionTags.Has(sectionName)
            reviewGui.importData.sectionTags[sectionName] := g.trainingData.sectionTags[sectionName]
        for color in g.trainingData.sections[sectionName] {
            reviewGui.importData.sections[sectionName].Push({
                hex: color.hex,
                rgb: color.rgb,
                name: color.name,
                role: color.role,
                section: sectionName,
                pinned: true,
                pinOrder: reviewGui.importData.sections[sectionName].Length + 1,
                x: color.x,
                y: color.y,
                w: color.w,
                h: color.h
            })
        }
    }

    PopulateImportReviewSections(reviewGui)
    if (reviewGui.importData.sectionOrder.Length > 0) {
        reviewGui.sectionList.Choose(1)
        ImportReviewSelectSection(app, reviewGui)
    }
    ImportReviewToast(app, "Applied training blocks to review")
}

ImportTrainingCanvasSavePreset(app, g) {
    total := 0
    for sectionName in g.trainingData.sectionOrder
        total += g.trainingData.sections[sectionName].Length
    if (total = 0) {
        ImportReviewToast(app, "No training blocks to save")
        return
    }

    defaultName := g.trainingData.sourceName != "" ? g.trainingData.sourceName : "training_canvas"
    ImportReviewShowInputDialog(app, "Preset/source label:", "Save Training Preset", (newName) => ImportTrainingCanvasSavePresetConfirm(app, g, newName), defaultName)
}

ImportTrainingCanvasSavePresetConfirm(app, g, newName) {
    presetName := Trim(newName)
    if (presetName = "")
        return

    data := {
        sections: g.trainingData.sections,
        sectionOrder: g.trainingData.sectionOrder,
        sectionTags: g.trainingData.sectionTags,
        imageWidth: g.trainingData.imageWidth,
        imageHeight: g.trainingData.imageHeight,
        sourceName: presetName
    }
    SaveImportTrainingSample(app, data, presetName)
    ImportReviewToast(app, "Saved training preset: " presetName)
}

ComputeImportSectionBounds(colors) {
    minX := ""
    minY := ""
    maxX := 0
    maxY := 0

    for color in colors {
        x := color.x
        y := color.y
        w := Max(1, color.w)
        h := Max(1, color.h)
        if (minX = "" || x < minX)
            minX := x
        if (minY = "" || y < minY)
            minY := y
        if (x + w > maxX)
            maxX := x + w
        if (y + h > maxY)
            maxY := y + h
    }

    if (minX = "")
        minX := 0
    if (minY = "")
        minY := 0

    return { x: minX, y: minY, w: Max(1, maxX - minX), h: Max(1, maxY - minY) }
}

EscapeTrainingField(value) {
    value := value ""
    value := StrReplace(value, "|", "/")
    value := StrReplace(value, "`r", " ")
    value := StrReplace(value, "`n", " ")
    return Trim(value)
}

ImportReviewToast(app, text) {
    try Func("ShowToast").Call(app, text)
    catch {
        try TrayTip("Nastarxa", text)
    }
}

ImportReviewShowInputDialog(app, prompt, title, callback, defaultValue := "") {
    Func("ShowInputDialog").Call(app, prompt, title, callback, defaultValue)
}

ImportReviewShowConfirmDialog(app, message, title, callback) {
    Func("ShowConfirmDialog").Call(app, message, title, callback)
}

ImportReviewJoinLines(lines) {
    return Func("JoinLines").Call(lines)
}

ImportReviewCreatePalette(name, filePath) {
    return Func("CreatePalette").Call(name, filePath)
}

ImportReviewEnsureDefaultSection(palette) {
    return Func("EnsureDefaultSection").Call(palette)
}

ImportReviewCreateItem(hex, rgb, name, role) {
    return Func("CreateItem").Call(hex, rgb, name, role)
}

ImportReviewAddColor(palette, item) {
    return Func("AddColor").Call(palette, item)
}

ImportReviewGetSectionObjectByName(palette, sectionName) {
    return Func("GetSectionObjectByName").Call(palette, sectionName)
}

ImportReviewMutate(app, callback) {
    return Func("Mutate").Call(app, callback)
}

ImportReviewSaveHistory(app) {
    return Func("SaveHistory").Call(app)
}

ImportReviewLoadHistory(app) {
    return Func("LoadHistory").Call(app)
}

ImportReviewEmit(app, eventName) {
    return Func("Emit").Call(app, eventName)
}

ImportReviewRebuildUI(app) {
    return Func("RebuildUI").Call(app)
}

ImportReviewGetRGBFromHex(hex) {
    hex := StrUpper(Trim(hex))
    if (InStr(hex, "#") = 1)
        hex := SubStr(hex, 2)
    if !RegExMatch(hex, "^[0-9A-F]{6}$")
        return "0,0,0"

    r := Integer("0x" SubStr(hex, 1, 2))
    g := Integer("0x" SubStr(hex, 3, 2))
    b := Integer("0x" SubStr(hex, 5, 2))
    return r "," g "," b
}

GetTrainingSourceFamily(sourceName) {
    name := RegExReplace(sourceName, "^.*\\")
    name := RegExReplace(name, "\.[^.]+$", "")
    name := StrLower(name)
    parts := StrSplit(name, "_")
    if (parts.Length > 0) {
        last := parts[parts.Length]
        if RegExMatch(last, "^[a-z]+")
            return RegExReplace(last, "^([a-z]+).*$", "$1")
    }
    if RegExMatch(name, "([a-z]+)(\d+[a-z]*)?$", &m)
        return m[1]
    return name
}
