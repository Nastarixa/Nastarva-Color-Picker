AddColor(p, item) {
    if p.map.Has(item.hex)
        return

    item.flashUntil := 0

    p.colors.InsertAt(1, item)
    p.map[item.hex] := item

    TrimSectionToMax(p, GetItemSectionNameForState(item))
}

Mutate(app, fn) {
    fn(app.activePalette)
    Normalize(app.activePalette)
}

TrimSectionToMax(p, sectionName) {
    limit := p.HasOwnProp("historyMax") ? p.historyMax : 20
    if (limit < 1)
        limit := 1

    sectionName := (sectionName = "") ? "Default" : sectionName
    sectionItems := []

    for item in p.colors {
        if GetItemSectionNameForState(item) = sectionName
            sectionItems.Push(item)
    }

    while (sectionItems.Length > limit) {
        removed := sectionItems.Pop()

        Loop p.colors.Length {
            idx := p.colors.Length - A_Index + 1
            if (GetItemToken(p.colors[idx]) = GetItemToken(removed)) {
                p.colors.RemoveAt(idx)
                break
            }
        }
    }
}

TrimAllSectionsToMax(p) {
    EnsureDefaultSection(p)
    for _, sectionName in p.sections
        TrimSectionToMax(p, sectionName)
}

Commit(app) {
    SaveHistory(app)
    DebouncedRefresh(app)
}

RefreshHistoryStructure(app) {
    SaveHistory(app)

    if app.historyVisible {
        app.ui.generation++
        RebuildUI(app)
        Emit(app, "history_changed")
    }
}

Normalize(p) {
    pinned := []
    normal := []

    nextPinOrder := 1

    for item in p.colors {
        if !item.HasOwnProp("id") || item.id = ""
            item.id := GenerateItemId()
        if !item.HasOwnProp("pinOrder")
            item.pinOrder := 0
        if !item.HasOwnProp("section") || item.section = ""
            item.section := "Default"

        if item.pinned {
            if (item.pinOrder < 1)
                item.pinOrder := nextPinOrder
            nextPinOrder := Max(nextPinOrder, item.pinOrder + 1)
            pinned.Push(item)
        } else {
            item.pinOrder := 0
            normal.Push(item)
        }
    }

    SortPinnedByOrder(pinned)

    p.colors := pinned
    for _, item in normal
        p.colors.Push(item)

    p.map := Map()
    p.idMap := Map()
    for item in p.colors {
        if !p.map.Has(item.hex)
            p.map[item.hex] := item
        p.idMap[item.id] := item
    }

    EnsureDefaultSection(p)
    GetSelectedSectionName(p)
    TrimAllSectionsToMax(p)

    p.map := Map()
    p.idMap := Map()
    for item in p.colors {
        if !p.map.Has(item.hex)
            p.map[item.hex] := item
        p.idMap[item.id] := item
    }
}

GetSelectedSectionName(p) {
    EnsureDefaultSection(p)

    sectionName := p.HasOwnProp("selectedSection")
        ? Trim(p.selectedSection)
        : ""

    if (sectionName = "" || !HasSectionName(p, sectionName))
        sectionName := "Default"

    p.selectedSection := sectionName
    return sectionName
}

SetSelectedSection(app, sectionName, silent := false) {
    sectionName := Trim(sectionName)
    changed := false

    Mutate(app, (p) => changed := SetSelectedSectionMutation(p, sectionName))

    if app.historyVisible
        Emit(app, "history_changed")

    if !silent
        ShowToast(app, "Target section: " GetSelectedSectionName(app.activePalette))

    return changed
}

SetSelectedSectionMutation(p, sectionName) {
    EnsureDefaultSection(p)

    sectionName := Trim(sectionName)
    if (sectionName = "" || !HasSectionName(p, sectionName))
        sectionName := "Default"

    changed := !p.HasOwnProp("selectedSection") || p.selectedSection != sectionName
    p.selectedSection := sectionName
    return changed
}

GetFirstNonDefaultSectionName(p) {
    EnsureDefaultSection(p)

    for _, sectionName in p.sections {
        if (sectionName != "Default")
            return sectionName
    }

    return "Default"
}

EnsureDefaultSection(p) {
    if !p.HasOwnProp("sections")
        p.sections := []

    if !HasSectionName(p, "Default")
        p.sections.InsertAt(1, "Default")
}

HasSectionName(p, sectionName) {
    if !p.HasOwnProp("sections")
        return false

    for section in p.sections {
        if (section = sectionName)
            return true
    }
    return false
}

AddSectionName(p, sectionName) {
    sectionName := Trim(sectionName)
    if (sectionName = "")
        return false

    if !p.HasOwnProp("sections")
        p.sections := []

    if HasSectionName(p, sectionName)
        return false

    p.sections.Push(sectionName)
    return true
}

SortPinnedByOrder(items) {
    Loop items.Length {
        swapped := false
        Loop items.Length - 1 {
            if (items[A_Index].pinOrder > items[A_Index + 1].pinOrder) {
                temp := items[A_Index]
                items[A_Index] := items[A_Index + 1]
                items[A_Index + 1] := temp
                swapped := true
            }
        }
        if !swapped
            break
    }
}

NormalizeColorInput(val) {
    type := DetectColorType(val)

    if (type = "hex")
        return { hex: val, rgb: GetRGBFromHex(val), type: "hex" }

    if (type = "rgb") {
        parts := StrSplit(val, ",")
        hex := Format("{:02X}{:02X}{:02X}", parts[1], parts[2], parts[3])
        return { hex: hex, rgb: val, type: "rgb" }
    }

    return 0
}

GetOrCreateCtrl(app, item) {
    token := GetItemToken(item)
    if !app.ui.controls.Has(token)
        CreateCell(app, item)

    return app.ui.controls.Has(token)
        ? app.ui.controls[token]
        : 0
}

GetItemByToken(app, token) {
    p := app.activePalette

    if p.HasOwnProp("idMap") && p.idMap.Has(token)
        return p.idMap[token]

    return p.map.Has(token)
        ? p.map[token]
        : 0
}

GetItemByHex(app, hex) {
    return GetItemByToken(app, hex)
}

GetItemToken(item) {
    return item.HasOwnProp("id") && item.id != ""
        ? item.id
        : item.hex
}

ItemMatchesToken(item, token) {
    return GetItemToken(item) = token || item.hex = token
}

HasColor(colors, hex) {
    for item in colors
        if (item.hex = hex)
            return true
    return false
}

SectionHasHex(p, sectionName, hex, exceptToken := "") {
    sectionName := (sectionName = "") ? "Default" : sectionName

    for item in p.colors {
        if (item.hex != hex)
            continue
        if GetItemSectionNameForState(item) != sectionName
            continue
        if (exceptToken != "" && ItemMatchesToken(item, exceptToken))
            continue
        return true
    }

    return false
}

ApplyHighlight(app, token) {
    if (token = "")
        return

    p := app.activePalette
    item := GetItemByToken(app, token)
    if !item
        return

    actualToken := GetItemToken(item)

    if (p.highlightToken = actualToken)
        return

    p.selectedHex := item.hex
    p.highlightHex := item.hex
    p.highlightToken := actualToken
}

ApplyRole(app, role, token) {
    role := NormalizeRoleName(role)
    Mutate(app, (p) => ApplyRoleMutation(p, role, token))
    Commit(app)
}

ApplyRoleMutation(p, role, token) {
    for item in p.colors {
        if ItemMatchesToken(item, token) {
            item.role := role
            break
        }
    }
}

CreateSection(app, sectionName) {
    added := false

    Mutate(app, (p) => added := AddSectionName(p, sectionName))

    if !added {
        ShowToast(app, "Section already exists")
        return false
    }

    SaveHistory(app)
    if app.historyVisible {
        Emit(app, "history_changed")
        DebouncedRefresh(app)
    }

    ShowToast(app, "Created section: " sectionName)
    SetSelectedSection(app, sectionName, true)
    return true
}

RenameSection(app, oldName, newName) {
    renamed := false

    Mutate(app, (p) => renamed := RenameSectionMutation(p, oldName, newName))

    if !renamed {
        ShowToast(app, "Could not rename section")
        return false
    }

    SaveHistory(app)
    if app.historyVisible {
        Emit(app, "history_changed")
        DebouncedRefresh(app)
    }

    ShowToast(app, "Renamed section: " newName)
    return true
}

RenameSectionMutation(p, oldName, newName) {
    oldName := Trim(oldName)
    newName := Trim(newName)

    if (oldName = "" || newName = "" || oldName = newName)
        return false

    if (oldName = "Default")
        return false

    if !HasSectionName(p, oldName) || HasSectionName(p, newName)
        return false

    for index, section in p.sections {
        if (section = oldName) {
            p.sections[index] := newName
            break
        }
    }

    for item in p.colors {
        if GetItemSectionNameForState(item) = oldName
            item.section := newName
    }

    if GetSelectedSectionName(p) = oldName
        p.selectedSection := newName

    return true
}

DuplicateSection(app, sourceName) {
    newName := GetSectionCopyName(app.activePalette, sourceName)
    duplicated := false

    Mutate(app, (p) => duplicated := DuplicateSectionMutation(p, sourceName, newName))

    if !duplicated {
        ShowToast(app, "Could not duplicate section")
        return false
    }

    SaveHistory(app)
    if app.historyVisible {
        Emit(app, "history_changed")
        DebouncedRefresh(app)
    }

    ShowToast(app, "Duplicated section: " newName)
    return true
}

DuplicateSectionMutation(p, sourceName, newName) {
    sourceName := Trim(sourceName)
    newName := Trim(newName)

    if (sourceName = "" || newName = "" || !HasSectionName(p, sourceName) || HasSectionName(p, newName))
        return false

    AddSectionName(p, newName)

    clones := []
    nextOrder := GetMaxPinOrder(p)

    for item in p.colors {
        if GetItemSectionNameForState(item) != sourceName
            continue

        clone := CloneItem(item)
        clone.section := newName
        if clone.pinned {
            nextOrder += 1
            clone.pinOrder := nextOrder
        }
        clones.Push(clone)
    }

    if (clones.Length = 0)
        return true

    for _, clone in clones
        p.colors.Push(clone)

    return true
}

GetSectionCopyName(p, sourceName) {
    baseName := Trim(sourceName)
    if (baseName = "")
        baseName := "Section"

    candidate := baseName " Copy"
    idx := 2

    while HasSectionName(p, candidate) {
        candidate := baseName " Copy " idx
        idx++
    }

    return candidate
}

DeleteSection(app, sectionName) {
    deleted := false

    Mutate(app, (p) => deleted := DeleteSectionMutation(p, sectionName))

    if !deleted {
        ShowToast(app, "Could not delete section")
        return false
    }

    SaveHistory(app)
    if app.historyVisible {
        Emit(app, "history_changed")
        DebouncedRefresh(app)
    }

    ShowToast(app, "Deleted section: " sectionName)
    return true
}

DeleteSectionMutation(p, sectionName) {
    sectionName := Trim(sectionName)

    if (sectionName = "" || sectionName = "Default")
        return false

    if !HasSectionName(p, sectionName)
        return false

    Loop p.sections.Length {
        if (p.sections[A_Index] = sectionName) {
            p.sections.RemoveAt(A_Index)
            break
        }
    }

    Loop p.colors.Length {
        index := p.colors.Length - A_Index + 1
        item := p.colors[index]
        if GetItemSectionNameForState(item) = sectionName {
            if p.map.Has(item.hex)
                p.map.Delete(item.hex)
            p.colors.RemoveAt(index)
        }
    }

    EnsureDefaultSection(p)
    if GetSelectedSectionName(p) = sectionName
        p.selectedSection := "Default"
    return true
}

MoveColorToSection(app, token, sectionName) {
    moved := false

    Mutate(app, (p) => moved := MoveColorToSectionMutation(p, token, sectionName))

    if !moved {
        ShowToast(app, "Could not move color")
        return false
    }

    RefreshHistoryStructure(app)

    item := GetItemByToken(app, token)
    ShowToast(app, "Moved #" (item ? item.hex : token) " -> " sectionName)
    return true
}

MoveColorToSectionMutation(p, token, sectionName) {
    sectionName := Trim(sectionName)
    if (sectionName = "")
        return false

    for item in p.colors {
        if ItemMatchesToken(item, token) {
            currentSection := GetItemSectionNameForState(item)
            if (currentSection = sectionName)
                return true
            if SectionHasHex(p, sectionName, item.hex, token)
                return false
            AddSectionName(p, sectionName)
            item.section := sectionName
            return true
        }
    }

    return false
}

TogglePin(app, token) {
    Mutate(app, (p) => TogglePinMutation(p, token))
    Commit(app)
}

TogglePinMutation(p, token) {
    maxOrder := GetMaxPinOrder(p)

    for item in p.colors {
        if ItemMatchesToken(item, token) {
            item.pinned := !item.pinned
            item.pinOrder := item.pinned ? maxOrder + 1 : 0
            break
        }
    }
}

GetMaxPinOrder(p) {
    maxOrder := 0
    for item in p.colors {
        if item.HasOwnProp("pinOrder")
            maxOrder := Max(maxOrder, item.pinOrder)
    }
    return maxOrder
}

MovePinnedColor(app, token, dir) {
    moved := false

    Mutate(app, (p) => moved := MovePinnedColorMutation(p, token, dir))

    if !moved {
        ShowToast(app, "Pin the color first")
        return
    }

    SaveHistory(app)
    if app.historyVisible {
        Emit(app, "history_changed")
        DebouncedRefresh(app)
    }
}

MovePinnedColorMutation(p, token, dir) {
    Normalize(p)

    pinned := []
    targetIndex := 0

    for item in p.colors {
        if item.pinned {
            pinned.Push(item)
            if ItemMatchesToken(item, token)
                targetIndex := pinned.Length
        }
    }

    if !targetIndex
        return false

    newIndex := targetIndex + dir
    if (newIndex < 1 || newIndex > pinned.Length)
        return false

    tempOrder := pinned[targetIndex].pinOrder
    pinned[targetIndex].pinOrder := pinned[newIndex].pinOrder
    pinned[newIndex].pinOrder := tempOrder
    Normalize(p)
    return true
}

ReorderPinnedColorToTarget(app, sourceToken, targetToken) {
    moved := false

    Mutate(app, (p) => moved := ReorderPinnedColorToTargetMutation(p, sourceToken, targetToken))

    if !moved {
        ShowToast(app, "Could not move pinned color")
        return
    }

    RefreshHistoryStructure(app)
}

MovePinnedColorToSection(app, sourceToken, sectionName) {
    moved := false

    Mutate(app, (p) => moved := MovePinnedColorToSectionMutation(p, sourceToken, sectionName))

    if !moved {
        ShowToast(app, "Could not move pinned color")
        return
    }

    RefreshHistoryStructure(app)
}

ReorderPinnedColorToTargetMutation(p, sourceToken, targetToken) {
    Normalize(p)

    pinned := []
    sourceIndex := 0
    targetIndex := 0
    source := 0
    target := 0

    for item in p.colors {
        if ItemMatchesToken(item, sourceToken)
            source := item
        if ItemMatchesToken(item, targetToken)
            target := item

        if item.pinned {
            pinned.Push(item)
            if ItemMatchesToken(item, sourceToken)
                sourceIndex := pinned.Length
            if ItemMatchesToken(item, targetToken)
                targetIndex := pinned.Length
        }
    }

    if !source || !target || !source.pinned || (sourceToken = targetToken)
        return false

    targetSection := target.HasOwnProp("section") && target.section != ""
        ? target.section
        : "Default"

    if SectionHasHex(p, targetSection, source.hex, sourceToken)
        return false

    source.section := targetSection

    if !target.pinned
        targetIndex := GetPinnedInsertIndexForSection(pinned, source, targetSection)

    if !targetIndex || !sourceIndex || (sourceIndex = targetIndex)
        return true

    movedItem := pinned.RemoveAt(sourceIndex)
    if (sourceIndex < targetIndex)
        targetIndex--

    pinned.InsertAt(targetIndex, movedItem)

    for index, item in pinned
        item.pinOrder := index

    Normalize(p)
    return true
}

MovePinnedColorToSectionMutation(p, sourceToken, sectionName) {
    sectionName := Trim(sectionName)
    if (sectionName = "")
        return false

    Normalize(p)
    AddSectionName(p, sectionName)

    pinned := []
    sourceIndex := 0
    source := 0

    for item in p.colors {
        if item.pinned {
            pinned.Push(item)
            if ItemMatchesToken(item, sourceToken) {
                source := item
                sourceIndex := pinned.Length
            }
        } else if ItemMatchesToken(item, sourceToken) {
            source := item
        }
    }

    if !source || !source.pinned || !sourceIndex
        return false

    currentSection := GetItemSectionNameForState(source)
    if (currentSection = sectionName)
        return true
    if SectionHasHex(p, sectionName, source.hex, sourceToken)
        return false

    source.section := sectionName
    targetIndex := GetPinnedInsertIndexForSection(pinned, source, sectionName)
    if !targetIndex
        targetIndex := pinned.Length + 1

    movedItem := pinned.RemoveAt(sourceIndex)
    if (sourceIndex < targetIndex)
        targetIndex--

    targetIndex := Max(1, Min(targetIndex, pinned.Length + 1))
    pinned.InsertAt(targetIndex, movedItem)

    for index, item in pinned
        item.pinOrder := index

    Normalize(p)
    return true
}

GetItemSectionNameForState(item) {
    if !item
        return "Default"

    return item.HasOwnProp("section") && item.section != ""
        ? item.section
        : "Default"
}

GetPinnedInsertIndexForSection(pinned, source, sectionName) {
    sectionName := (sectionName = "") ? "Default" : sectionName
    insertIndex := pinned.Length + 1

    for index, item in pinned {
        if (GetItemToken(item) = GetItemToken(source))
            continue

        if GetItemSectionNameForState(item) = sectionName
            insertIndex := index + 1
    }

    return insertIndex
}

RemoveColorByHex(p, hex) {
    removed := 0

    Loop p.colors.Length {
        if (p.colors[A_Index].hex = hex) {
            removed := p.colors[A_Index]
            p.colors.RemoveAt(A_Index)
            break
        }
    }

    if p.map.Has(hex)
        p.map.Delete(hex)

    if (p.selectedHex = hex)
        p.selectedHex := ""

    if (p.highlightHex = hex)
        p.highlightHex := ""

    return removed
}

DeleteColor(app, token) {
    removed := 0

    Mutate(app, (p) => removed := RemoveColorByToken(p, token))

    if !removed
        return

    SaveHistory(app)
    if app.historyVisible {
        Emit(app, "history_changed")
        DebouncedRefresh(app)
    }

    ShowToast(app, "Deleted #" removed.hex)
}

RemoveColorByToken(p, token) {
    removed := 0

    Loop p.colors.Length {
        if ItemMatchesToken(p.colors[A_Index], token) {
            removed := p.colors[A_Index]
            p.colors.RemoveAt(A_Index)
            break
        }
    }

    if !removed
        return 0

    if p.idMap.Has(removed.id)
        p.idMap.Delete(removed.id)

    if (p.selectedHex = removed.hex || p.highlightHex = removed.hex) {
        if p.selectedHex = removed.hex
            p.selectedHex := ""
        if p.highlightHex = removed.hex
            p.highlightHex := ""
    }
    if (p.highlightToken = token)
        p.highlightToken := 0

    return removed
}

MoveColorToPalette(app, token, targetName) {
    source := app.activePalette

    if (targetName = "") || (targetName = source.name)
        return false

    if !app.palettes.Has(targetName)
        return false

    target := app.palettes[targetName]

    item := GetItemByToken(app, token)
    if !item {
        ShowToast(app, "Color not found")
        return false
    }

    if target.map.Has(item.hex) {
        ShowToast(app, targetName " already has #" item.hex)
        return false
    }

    clone := CloneItem(item)

    Mutate(app, (p) => RemoveColorByToken(p, token))
    AddColor(target, clone)
    Normalize(target)

    SavePalette(source, app.version)
    SavePalette(target, app.version)

    if app.historyVisible {
        Emit(app, "history_changed")
        DebouncedRefresh(app)
    }

    ShowToast(app, "Moved #" item.hex " -> " targetName)
    return true
}

CloneItem(item) {
    clone := CreateItem(item.hex, item.rgb, item.name, item.role)
    clone.pinned := item.pinned
    clone.pinOrder := item.pinOrder
    clone.section := item.section
    clone.isSaved := item.isSaved
    clone.copiedUntil := item.copiedUntil
    return clone
}

ShowHotkeyHelp(app) {
    if IsObject(app.helpGui)
        try app.helpGui.Destroy()

    g := Gui("+AlwaysOnTop -Caption +ToolWindow")
    g.BackColor := "202020"
    g.SetFont("s10", "Consolas")

    text :=
    (
    "🎨 Nastarva Palette Manager v" app.version "`n`n"
    "Ctrl + Alt + P   → Toggle Color Picker`n"
    "Ctrl + Alt + O   → Toggle Color Palette`n"
    "Ctrl + Alt + U   → Screenshot Palette Import`n"
    "Ctrl + Alt + I   → Open Palette Manager`n"
    "Ctrl + Alt + 1-9 → Switch Palette`n`n"
    "-------------------------`n`n"
    "After Toggle Picker:`n"
    "Middle Mouse     → Save Hex Color`n"
    "Ctrl + Middle    → Save RGB Color`n`n"
    "-------------------------`n`n"
    "In Color Palette:`n"
    "Click = Copy HEX`n"
    "Ctrl + Click = Copy RGB`n"
    "Right Click = Menu`n"
    "Drag = Reorder Colors"
    )

    g.bg := g.AddText("x0 y0 w450 h300 Background202020")
    g.txt := g.AddText("x10 y10 cFFFFFF w430", text)

    g.bg.OnEvent("Click", (*) => CloseHelp(app))
    g.OnEvent("Escape", (*) => CloseHelp(app))
    g.OnEvent("Close", (*) => CloseHelp(app))

    g.Show("AutoSize Center")

    app.helpGui := g

    SetTimer(() => CloseHelp(app), -8000)
}

CloseHelp(app) {
    if !IsObject(app)
        return

    if app.HasOwnProp("helpGui") && IsObject(app.helpGui) {
        try app.helpGui.Destroy()
        app.helpGui := 0
    }
}
