ShowImportReview(app, importedData, sourcePath, isTemp := false, importMode := "insert") {

    if app.HasOwnProp("importReviewGui") && SafeGetGuiHwnd(app.importReviewGui) {
        app.importReviewGui.Show()
        return
    }

    g := Gui("+AlwaysOnTop +ToolWindow +Border", "🔍 Import Review")
    g.BackColor := "323338"
    g.SetFont("s9", "Consolas")
    g.MarginX := 12
    g.MarginY := 10

    ; =====================================================
    ; HEADER
    ; =====================================================
    g.AddText("x10 y10 cFFFFFF", "Import Review & Editor")

    ; layout anchors
    baseY := 35
    gap := 10

    leftX := 10
    leftW := 180

    centerX := leftX + leftW + gap
    centerW := 340

    rightX := centerX + centerW + gap
    rightW := 220

    ; =====================================================
    ; LEFT: SECTIONS PANEL
    ; =====================================================
    g.AddText("x" leftX " y" baseY " cAAAAAA", "Sections")

    g.sectionList := g.AddListBox("x" leftX " y" (baseY+18) " w" leftW " h220")
    g.sectionList.OnEvent("Change", (*) => ImportReviewSelectSection(app, g))

    ; =====================================================
    ; CENTER: COLORS + PREVIEW
    ; =====================================================
    g.AddText("x" centerX " y" baseY " cAAAAAA", "Colors")

    g.colorList := g.AddListView("x" centerX " y" (baseY+18) " w" centerW " h140 -Hdr -Multi",
        ["HEX", "Name", "Role"])
    totalW := centerW
    hexW := 70
    remaining := totalW - hexW - 20
    each := Floor(remaining / 2)
    g.colorList.ModifyCol(1, hexW)
    Loop 2
        g.colorList.ModifyCol(A_Index + 1, each)

    g.colorList.OnEvent("ItemFocus", (ctrl, item) =>
        ImportReviewColorFocus(app, g, item)
    )




    previewY := baseY + 165

    g.tess := g.AddText("x" centerX " y" previewY " w80 h16 cFFFFFF", "Preview:")
    g.preview := g.AddProgress("x" centerX " y" previewY+20 " w40 h40 Background808080")
    g.selectedHex := g.AddText("x" centerX+50 " y" previewY+20 " w100 h16 cFFFFFF", "#808080")
    g.selectedRGB := g.AddText("x" centerX+50 " y" previewY+38 " w100 h16 cAAAAAA", "0,0,0")

    roleX := centerX + 150
    g.AddText("x" roleX " y" (previewY + 15) " cAAAAAA", "Role:")

    g.roleEdit := g.AddDropDownList(
        "x" roleX " y" (previewY+32) " w150 Choose1",
        ["Base", "Highlight", "Shadow", "Hi Shadow", "2 Shadow", "Mask", "Outline", "Black", "Other"]
    )


    g.roleEdit.OnEvent("Change", (*) =>
        ImportReviewUpdateRole(app, g)
    )

    ; =====================================================
    ; RIGHT: IMPORT SETTINGS
    ; =====================================================
    g.AddText("x" rightX " y" baseY " cAAAAAA", "Import Settings")

    g.importMode := g.AddDropDownList(
        "x" rightX " y" (baseY+18) " w200 Choose3",
        ["Replace Palette","Insert Into Palette","Create New Palette"]
    )

    g.importMode.OnEvent("Change", (*) => ImportModeChanged(g))

    g.newPaletteNameLabel := g.AddText("x" rightX " y" (baseY+50) " cAAAAAA", "New Name")
    g.newPaletteName := g.AddEdit("x" rightX " y" (baseY+68) " w200 h20", "New Palette")

    g.targetPaletteLabel := g.AddText("x" rightX " y" (baseY+50) " cAAAAAA", "Target Palette")
    g.targetPalette := g.AddDropDownList("x" rightX " y" (baseY+68) " w200 h20", app.paletteOrder)

    g.targetPaletteLabel.Opt("+Hidden")
    g.targetPalette.Opt("+Hidden")

    ; =====================================================
    ; ACTION BUTTONS (BOTTOM BAR)
    ; =====================================================
    bottomY := baseY + 250

    g.btnApply := g.AddButton("x10 y" bottomY " w200 h30", "✅ Apply Import")
    g.btnCancel := g.AddButton("x220 y" bottomY " w200 h30", "❌ Cancel")

    g.btnApply.OnEvent("Click", (*) =>
        ImportReviewApply(app, g, sourcePath, isTemp)
    )

    g.btnCancel.OnEvent("Click", (*) =>
        ImportReviewCancel(app, g, sourcePath, isTemp)
    )

    ; =====================================================
    ; DATA INIT
    ; =====================================================
    g.importData := ParseImportedData(importedData)
    g.selectedSectionIdx := 0
    g.selectedColorIdx := 0
    g.refColorMap := Map()

    modeIdx := importMode = "replace" ? 1 : (importMode = "insert" ? 2 : 3)
    g.importMode.Value := modeIdx

    PopulateImportReviewSections(g)

    if g.importData.sectionOrder.Length > 0 {
        g.sectionList.Choose(1)
        ImportReviewSelectSection(app, g)
    }

    ; =====================================================
    ; SHOW
    ; =====================================================
    g.Show("AutoSize Center")
    app.importReviewGui := g
}

ImportReviewColorFocus(app, g, item) {
    if !item
        return
    g.selectedColorIdx := item
    ImportReviewUpdatePreview(g, item)
    
    if (g.selectedSectionIdx < 1 || item > g.importData.sections[g.importData.sectionOrder[g.selectedSectionIdx]].Length)
        return
    
    sectionName := g.importData.sectionOrder[g.selectedSectionIdx]
    color := g.importData.sections[sectionName][item]
    roleIdx := GetRoleIndex(color.role)
    g.roleEdit.Choose(roleIdx)
}

ImportReviewUpdatePreview(g, sel) {
    if !sel || !g.HasOwnProp("refColorMap") || !g.refColorMap.Has(sel)
        return
    
    hex := g.refColorMap[sel]
    if !hex
        return
    
    g.preview.Opt("Background" hex)
    g.selectedHex.Value := "#" hex
    g.selectedRGB.Value := GetRGBFromHex(hex)
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

ParseImportedData(importedData) {
    data := { sections: Map(), sectionOrder: [], sectionTags: Map() }
    lines := StrSplit(importedData, "`n", "`r")
    
    currentSection := "Default"
    for line in lines {
        line := Trim(line)
        if (line = "" || SubStr(line, 1, 1) = ";")
            continue
        
        if InStr(line, "#SECTION|") = 1 {
            sectionData := Trim(SubStr(line, 11))
            sectionParts := StrSplit(sectionData, "|")
            if sectionParts.Length >= 2 {
                sectionTag := Trim(sectionParts[1])
                currentSection := Trim(sectionParts[2])
            } else {
                currentSection := sectionData
                sectionTag := ""
            }
            if !data.sections.Has(currentSection) {
                data.sections[currentSection] := []
                data.sectionOrder.Push(currentSection)
            }
            if (sectionTag != "")
                data.sectionTags[currentSection] := sectionTag
            continue
        }
        
        parts := StrSplit(line, "|")
        if parts.Length >= 4 {
            hex := Trim(parts[1])
            if InStr(hex, "#") = 1
                hex := SubStr(hex, 2)
            
            if RegExMatch(hex, "^[0-9A-Fa-f]{6}$") {
                rgb := Trim(parts[2])
                name := Trim(parts[3])
                role := Trim(parts[4])
                
                color := { hex: hex, rgb: rgb, name: name, role: role, section: currentSection }
                if !data.sections.Has(currentSection) {
                    data.sections[currentSection] := []
                    data.sectionOrder.Push(currentSection)
                }
                data.sections[currentSection].Push(color)
            }
        }
    }
    
    return data
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
        g.colorList.Add("", "#" color.hex, color.name, color.role)
        g.refColorMap[idx] := color.hex
    }
}

ImportReviewSelectSection(app, g) {
    g.selectedSectionIdx := g.sectionList.Value
    g.selectedColorIdx := 0
    PopulateImportReviewColors(g)
    if g.refColorMap.Has(1) {
        g.colorList.Modify(1, "Select Focus")
        g.selectedColorIdx := 1
        hex := g.refColorMap[1]
        g.preview.Opt("Background" hex)
        g.selectedHex.Value := "#" hex
        g.selectedRGB.Value := GetRGBFromHex(hex)
    } else {
        g.preview.Opt("Background808080")
        g.selectedHex.Value := "#808080"
        g.selectedRGB.Value := "0,0,0"
    }
}

GetRoleIndex(role) {
    roles := ["Base", "Highlight", "Shadow", "Hi Shadow", "2 Shadow", "Mask", "Outline", "Black", "Other"]
    for i, r in roles {
        if (r = role)
            return i
    }
    return 1
}

UpdateImportReviewPreview(g, sel) {
    if !sel || !g.HasOwnProp("refColorMap") || !g.refColorMap.Has(sel)
        return
    
    hex := g.refColorMap[sel]
    if !hex
        return
    
    g.preview.Opt("Background" hex)
    g.selectedHex.Value := "#" hex
    g.selectedRGB.Value := GetRGBFromHex(hex)
}

ImportReviewUpdateRole(app, g) {
    if (g.selectedColorIdx < 1 || g.selectedSectionIdx < 1)
        return
    
    sectionName := g.importData.sectionOrder[g.selectedSectionIdx]
    color := g.importData.sections[sectionName][g.selectedColorIdx]
    color.role := g.roleEdit.Text
    
    PopulateImportReviewColors(g)
    g.colorList.Modify(g.selectedColorIdx, "Select Focus")
}

ImportReviewDeleteColor(app, g) {
    if (g.selectedColorIdx < 1 || g.selectedSectionIdx < 1)
        return
    
    sectionName := g.importData.sectionOrder[g.selectedSectionIdx]
    colors := g.importData.sections[sectionName]
    
    colors.RemoveAt(g.selectedColorIdx)
    g.selectedColorIdx := 0
    g.preview.Opt("Background808080")
    g.selectedHex.Value := "#808080"
    g.selectedRGB.Value := "0,0,0"
    g.roleEdit.Choose(1)
    
    PopulateImportReviewColors(g)
    PopulateImportReviewSections(g)
    if g.importData.sectionOrder.Length > 0 && g.selectedSectionIdx <= g.importData.sectionOrder.Length {
        g.sectionList.Choose(g.selectedSectionIdx)
    }
}

ImportReviewCopyHex(app, g) {
    if (g.selectedColorIdx < 1 || g.selectedSectionIdx < 1)
        return
    
    sectionName := g.importData.sectionOrder[g.selectedSectionIdx]
    color := g.importData.sections[sectionName][g.selectedColorIdx]
    
    A_Clipboard := color.hex
    ShowToast(app, "✔ Copied #" color.hex)
}

ImportReviewCopyRGB(app, g) {
    if (g.selectedColorIdx < 1 || g.selectedSectionIdx < 1)
        return
    
    sectionName := g.importData.sectionOrder[g.selectedSectionIdx]
    color := g.importData.sections[sectionName][g.selectedColorIdx]
    
    A_Clipboard := color.rgb
    ShowToast(app, "✔ Copied " color.rgb)
}

ImportReviewRenameSection(app, g) {
    if (g.selectedSectionIdx < 1)
        return
    
    oldName := g.importData.sectionOrder[g.selectedSectionIdx]
    
    ShowInputDialog(app, "Enter new section name:", "Rename Section", (newName) => ImportReviewRenameSectionConfirm(app, g, oldName, newName), oldName)
}

ImportReviewRenameSectionConfirm(app, g, oldName, newName) {
    if (newName = "" || newName = oldName)
        return
    
    g.importData.sectionOrder[g.selectedSectionIdx] := newName
    g.importData.sections[newName] := g.importData.sections.Delete(oldName)
    
    for color in g.importData.sections[newName] {
        color.section := newName
    }
    
    PopulateImportReviewSections(g)
    g.sectionList.Choose(g.selectedSectionIdx)
    PopulateImportReviewColors(g)
}

ImportReviewMergeSection(app, g) {
    if (g.selectedSectionIdx < 1)
        return
    
    sourceName := g.importData.sectionOrder[g.selectedSectionIdx]
    
    if (g.importData.sectionOrder.Length < 2) {
        ShowToast(app, "No other sections to merge with")
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
    
    g.importData.sections.Delete(sourceName)
    g.importData.sectionOrder.RemoveAt(g.selectedSectionIdx)
    
    g.selectedSectionIdx := 0
    g.selectedColorIdx := 0
    g.preview.Opt("Background808080")
    g.selectedHex.Value := "#808080"
    g.selectedRGB.Value := "0,0,0"
    g.roleEdit.Choose(1)
    
    PopulateImportReviewSections(g)
    g.colorList.Delete()
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
    selectedIdx := 0
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
    
    while SafeGetGuiHwnd(g) {
        Sleep 50
    }
    
    if selectedText = ""
        return 0
    
    idx := Integer(StrSplit(selectedText, ".")[1])
    if (idx < 1 || idx > sectionOrder.Length || idx = excludeIdx)
        return 0
    
    return idx
}

ImportReviewDeleteSection(app, g) {
    if (g.selectedSectionIdx < 1)
        return
    
    sectionName := g.importData.sectionOrder[g.selectedSectionIdx]
    
    ShowConfirmDialog(app, "Delete section '" sectionName "' and all its colors?", "Confirm Delete", (*) => ImportReviewDeleteSectionConfirm(app, g, sectionName))
}

ImportReviewDeleteSectionConfirm(app, g, sectionName) {
    g.importData.sections.Delete(sectionName)
    g.importData.sectionOrder.RemoveAt(g.selectedSectionIdx)
    
    g.selectedSectionIdx := 0
    g.selectedColorIdx := 0
    g.preview.Opt("Background808080")
    g.selectedHex.Value := "#808080"
    g.selectedRGB.Value := "0,0,0"
    g.roleEdit.Choose(1)
    
    PopulateImportReviewSections(g)
    g.colorList.Delete()
    PopulateImportReviewColors(g)
}

ImportReviewApply(app, g, sourcePath, isTemp) {
    totalColors := 0
    for sectionName in g.importData.sectionOrder {
        totalColors += g.importData.sections[sectionName].Length
    }
    
    if (totalColors = 0) {
        ShowToast(app, "No colors to import")
        return
    }
    
    importMode := g.importMode.Value
    if !importMode
        importMode := 2
    
    if (importMode = 3) {
        paletteName := Trim(g.newPaletteName.Value)
        if (paletteName = "") {
            ShowToast(app, "Enter a palette name")
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
        
        p := CreatePalette(paletteName, filePath)
        app.palettes[paletteName] := p
        app.paletteOrder.Push(paletteName)
        app.activePalette := p
    } else {
        targetSelection := g.targetPalette.Value
        if !targetSelection {
            ShowToast(app, "Select a target palette")
            return
        }
        
        paletteName := g.paletteNames[targetSelection]
        p := app.palettes[paletteName]
        if !p {
            ShowToast(app, "Palette not found")
            return
        }
        
        if (importMode = 1) {
            p.colors := []
            p.map := Map()
            p.idMap := Map()
            p.sections := []
            p.sectionPositions := Map()
            EnsureDefaultSection(p)
        }
        
        app.activePalette := p
    }
    
    for sectionName in g.importData.sectionOrder {
        colors := g.importData.sections[sectionName]
        for color in colors {
            newItem := CreateItem(color.hex, color.rgb, color.name, color.role)
            newItem.section := sectionName
            newItem.isSaved := true
            AddColor(p, newItem)
        }
        
        if g.importData.sectionTags.Has(sectionName) {
            section := GetSectionObjectByName(p, sectionName)
            if section && section.HasOwnProp("tag")
                section.tag := g.importData.sectionTags[sectionName]
        }
    }
    
    Mutate(app, (pal) => 0)
    SaveHistory(app)
    LoadHistory(app)
    
    if app.historyVisible {
        Emit(app, "history_changed")
    }
    
    app.ui.generation++
    RebuildUI(app)
    
    ImportReviewCancel(app, g, sourcePath, isTemp, false)
    
    modeLabel := importMode = 1 ? "Replaced" : (importMode = 3 ? "Created" : "Inserted")
    ShowToast(app, "✔ " modeLabel " " totalColors " colors in " paletteName)
}

ImportReviewCancel(app, g, sourcePath, isTemp, showMsg := true) {
    if (isTemp && FileExist(sourcePath)) {
        try FileDelete(sourcePath)
    }
    
    g.Destroy()
    
    if (showMsg)
        ShowToast(app, "Import cancelled")
}
