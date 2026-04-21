AddColor(p, item) {
    if p.map.Has(item.hex)
        return

    item.flashUntil := 0

    p.colors.InsertAt(1, item)
    p.map[item.hex] := item

    if (p.colors.Length > p.historyMax) {
        removed := p.colors.Pop()
        if p.map.Has(removed.hex)
            p.map.Delete(removed.hex)
    }
}

Mutate(app, fn) {
    fn(app.activePalette)
    Normalize(app.activePalette)
}

Commit(app) {
    SaveHistory(app)
    DebouncedRefresh(app)
}

Normalize(p) {
    pinned := []
    normal := []

    nextPinOrder := 1

    for item in p.colors {
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
    for item in p.colors
        p.map[item.hex] := item

    EnsureDefaultSection(p)
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
    if !app.ui.controls.Has(item.hex)
        CreateCell(app, item)

    return app.ui.controls.Has(item.hex)
        ? app.ui.controls[item.hex]
        : 0
}

GetItemByHex(app, hex) {
    return app.activePalette.map.Has(hex)
        ? app.activePalette.map[hex]
        : 0
}

HasColor(colors, hex) {
    for item in colors
        if (item.hex = hex)
            return true
    return false
}

ApplyHighlight(app, hex) {
    if (hex = "")
        return

    p := app.activePalette

    if (p.highlightHex = hex)
        return

    p.selectedHex := hex
    p.highlightHex := hex
}

ApplyRole(app, role, hex) {
    Mutate(app, (p) => ApplyRoleMutation(p, role, hex))
    Commit(app)
}

ApplyRoleMutation(p, role, hex) {
    for item in p.colors {
        if (item.hex = hex) {
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

    return true
}

DuplicateSection(app, sourceName) {
    newName := GetSectionCopyName(app.activePalette, sourceName)
    added := false

    Mutate(app, (p) => added := AddSectionName(p, newName))

    if !added {
        ShowToast(app, "Could not duplicate section")
        return false
    }

    SaveHistory(app)
    if app.historyVisible {
        Emit(app, "history_changed")
        DebouncedRefresh(app)
    }

    ShowToast(app, "Created section: " newName)
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
    return true
}

MoveColorToSection(app, hex, sectionName) {
    moved := false

    Mutate(app, (p) => moved := MoveColorToSectionMutation(p, hex, sectionName))

    if !moved {
        ShowToast(app, "Could not move color")
        return false
    }

    SaveHistory(app)
    if app.historyVisible {
        Emit(app, "history_changed")
        DebouncedRefresh(app)
    }

    ShowToast(app, "Moved #" hex " -> " sectionName)
    return true
}

MoveColorToSectionMutation(p, hex, sectionName) {
    sectionName := Trim(sectionName)
    if (sectionName = "")
        return false

    AddSectionName(p, sectionName)

    for item in p.colors {
        if (item.hex = hex) {
            item.section := sectionName
            return true
        }
    }

    return false
}

TogglePin(app, hex) {
    Mutate(app, (p) => TogglePinMutation(p, hex))
    Commit(app)
}

TogglePinMutation(p, hex) {
    maxOrder := GetMaxPinOrder(p)

    for item in p.colors {
        if (item.hex = hex) {
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

MovePinnedColor(app, hex, dir) {
    moved := false

    Mutate(app, (p) => moved := MovePinnedColorMutation(p, hex, dir))

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

MovePinnedColorMutation(p, hex, dir) {
    Normalize(p)

    pinned := []
    targetIndex := 0

    for item in p.colors {
        if item.pinned {
            pinned.Push(item)
            if (item.hex = hex)
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

ReorderPinnedColorToTarget(app, sourceHex, targetHex) {
    moved := false

    Mutate(app, (p) => moved := ReorderPinnedColorToTargetMutation(p, sourceHex, targetHex))

    if !moved {
        ShowToast(app, "Pin the dragged color first")
        return
    }

    SaveHistory(app)
    if app.historyVisible {
        Emit(app, "history_changed")
        DebouncedRefresh(app)
    }
}

ReorderPinnedColorToTargetMutation(p, sourceHex, targetHex) {
    Normalize(p)

    pinned := []
    sourceIndex := 0
    targetIndex := 0
    source := 0
    target := 0

    for item in p.colors {
        if (item.hex = sourceHex)
            source := item
        if (item.hex = targetHex)
            target := item

        if item.pinned {
            pinned.Push(item)
            if (item.hex = sourceHex)
                sourceIndex := pinned.Length
            if (item.hex = targetHex)
                targetIndex := pinned.Length
        }
    }

    if !source || !target || !source.pinned || (sourceHex = targetHex)
        return false

    source.section := target.HasOwnProp("section") && target.section != ""
        ? target.section
        : "Default"

    if !target.pinned
        targetIndex := GetPinnedInsertIndexForSection(pinned, source, target.section)

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
        if (item.hex = source.hex)
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

DeleteColor(app, hex) {
    removed := 0

    Mutate(app, (p) => removed := RemoveColorByHex(p, hex))

    if !removed
        return

    SaveHistory(app)
    if app.historyVisible {
        Emit(app, "history_changed")
        DebouncedRefresh(app)
    }

    ShowToast(app, "Deleted #" hex)
}

MoveColorToPalette(app, hex, targetName) {
    source := app.activePalette

    if (targetName = "") || (targetName = source.name)
        return false

    if !app.palettes.Has(targetName)
        return false

    target := app.palettes[targetName]

    if !source.map.Has(hex) {
        ShowToast(app, "Color not found: #" hex)
        return false
    }

    if target.map.Has(hex) {
        ShowToast(app, targetName " already has #" hex)
        return false
    }

    item := source.map[hex]
    clone := CreateItem(item.hex, item.rgb, item.name, item.role)
    clone.pinned := item.pinned
    clone.pinOrder := item.pinOrder
    clone.section := item.section
    clone.isSaved := item.isSaved
    clone.copiedUntil := item.copiedUntil

    Mutate(app, (p) => RemoveColorByHex(p, hex))
    AddColor(target, clone)
    Normalize(target)

    SavePalette(source, app.version)
    SavePalette(target, app.version)

    if app.historyVisible {
        Emit(app, "history_changed")
        DebouncedRefresh(app)
    }

    ShowToast(app, "Moved #" hex " -> " targetName)
    return true
}
