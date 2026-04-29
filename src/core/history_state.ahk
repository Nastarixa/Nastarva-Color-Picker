AddColor(p, item) {
    sectionName := GetItemSectionNameForState(item)

    for existing in p.colors {
        if existing.hex = item.hex && GetItemSectionNameForState(existing) = sectionName {
            return
        }
    }

    item.flashUntil := 0
    p.colors.InsertAt(1, item)
    p.map[item.hex] := item
    TrimSectionToMax(p, sectionName)
}

MovePinnedColorLeft(app, token) {
    MovePinnedColor(app, token, -1)
}
MovePinnedColorRight(app, token) {
    MovePinnedColor(app, token, 1)
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
            if (GetItemToken(p.colors[idx]) == GetItemToken(removed)) {
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
    if IsObject(sectionName)
        sectionName := sectionName.name
    sectionName := Trim(sectionName)
    changed := false

    Mutate(app, (p) => changed := SetSelectedSectionMutation(p, sectionName))

    if app.historyVisible {
        RefreshAllSectionChrome(app)
        Emit(app, "history_changed")
    }

    if !silent
        ShowToast(app, "Target section: " GetSelectedSectionName(app.activePalette))

    return changed
}

SetSelectedSectionMutation(p, sectionName) {
    EnsureDefaultSection(p)

    if IsObject(sectionName)
        sectionName := sectionName.name
    sectionName := Trim(sectionName)
    if (sectionName = "" || !HasSectionName(p, sectionName))
        sectionName := "Default"

    changed := !p.HasOwnProp("selectedSection") || p.selectedSection != sectionName
    p.selectedSection := sectionName
    return changed
}

GetFirstNonDefaultSectionName(p) {
    EnsureDefaultSection(p)

    for _, section in p.sections {
        name := IsObject(section) ? section.name : section
        if (name != "Default")
            return name
    }

    return "Default"
}

EnsureDefaultSection(p) {
    if !p.HasOwnProp("sections")
        p.sections := []

    if !HasSectionName(p, "Default")
        p.sections.InsertAt(1, { id: GenerateSectionId(), name: "Default", isDefault: true, locked: false, collapsed: false, tag: "", note: "" })
}

GetSectionId(p, sectionName) {
    if !p.HasOwnProp("sections")
        return ""

    for section in p.sections {
        if IsObject(section) && section.name = sectionName
            return section.id
        if !IsObject(section) && section = sectionName
            return ""
    }
    return ""
}

HasSectionName(p, sectionName) {
    if !p.HasOwnProp("sections")
        return false

    for section in p.sections {
        if IsObject(section) && section.name = sectionName
            return true
        if !IsObject(section) && section = sectionName
            return true
    }
    return false
}

GetSectionById(p, id) {
    if !p.HasOwnProp("sections")
        return 0

    for section in p.sections {
        if IsObject(section) && section.id = id
            return section
    }
    return 0
}

AddSectionName(p, sectionName) {
    sectionName := Trim(sectionName)
    if (sectionName = "")
        return false

    if !p.HasOwnProp("sections")
        p.sections := []

    if HasSectionName(p, sectionName)
        return false

    p.sections.Push({ id: GenerateSectionId(), name: sectionName, isDefault: false, locked: false, collapsed: false, tag: "", note: "" })
    return true
}

GetSectionObjectByName(p, sectionName) {
    if !p.HasOwnProp("sections")
        return 0
    for _, section in p.sections {
        if IsObject(section) && section.name = sectionName
            return section
    }
    return 0
}

IsSectionLocked(p, sectionName) {
    section := GetSectionObjectByName(p, sectionName)
    return IsObject(section) && section.HasOwnProp("locked") && section.locked
}

IsSectionCollapsed(p, sectionName) {
    section := GetSectionObjectByName(p, sectionName)
    return IsObject(section) && section.HasOwnProp("collapsed") && section.collapsed
}

GetSectionTagColor(p, sectionName) {
    section := GetSectionObjectByName(p, sectionName)
    if !IsObject(section) || !section.HasOwnProp("tag")
        return ""
    tag := StrUpper(RegExReplace(section.tag, "(?i)[^0-9A-F]"))
    return StrLen(tag) = 6 ? tag : ""
}

GetSectionNote(p, sectionName) {
    section := GetSectionObjectByName(p, sectionName)
    return (IsObject(section) && section.HasOwnProp("note")) ? section.note : ""
}

GetPaletteNote(p) {
    return p.HasOwnProp("note") ? p.note : ""
}

SetPaletteNote(app, note) {
    changed := false
    Mutate(app, (p) => changed := SetPaletteNoteMutation(p, note))
    if !changed
        return false
    SaveHistory(app)
    ShowToast(app, "Updated palette note")
    return true
}

SetPaletteNoteMutation(p, note) {
    p.note := Trim(note)
    return true
}

ToggleSectionLock(app, sectionName) {
    changed := false
    state := false
    Mutate(app, (p) => changed := ToggleSectionLockMutation(p, sectionName, &state))
    if !changed
        return false
    SaveHistory(app)
    if app.historyVisible {
        RefreshSectionChromeByName(app, sectionName)
        Emit(app, "history_changed")
    }
    ShowToast(app, sectionName " " (state ? "locked" : "unlocked"))
    return true
}

ToggleSectionLockMutation(p, sectionName, &state := false) {
    section := GetSectionObjectByName(p, sectionName)
    if !IsObject(section)
        return false
    section.locked := !section.locked
    state := section.locked
    return true
}

ToggleSectionCollapsed(app, sectionName) {
    changed := false
    state := false
    Mutate(app, (p) => changed := ToggleSectionCollapsedMutation(p, sectionName, &state))
    if !changed
        return false
    SaveHistory(app)
    if app.historyVisible {
        app.ui.generation++
        RebuildUI(app)
        Emit(app, "history_changed")
    }
    ShowToast(app, sectionName " " (state ? "collapsed" : "expanded"))
    return true
}

ToggleSectionCollapsedMutation(p, sectionName, &state := false) {
    section := GetSectionObjectByName(p, sectionName)
    if !IsObject(section)
        return false
    section.collapsed := !section.collapsed
    state := section.collapsed
    return true
}

SetSectionTagColor(app, sectionName, tag) {
    changed := false
    Mutate(app, (p) => changed := SetSectionTagColorMutation(p, sectionName, tag))
    if !changed
        return false
    SaveHistory(app)
    app.ui.generation++
    RebuildUI(app)
    ShowToast(app, tag = "" ? "Cleared section tag" : "Updated section tag")
    return true
}

SetSectionTagColorMutation(p, sectionName, tag) {
    if !HasSectionName(p, sectionName) {
        AddSectionName(p, sectionName)
    }
    section := GetSectionObjectByName(p, sectionName)
    if !IsObject(section)
        return false
    tag := StrUpper(RegExReplace(Trim(tag), "(?i)[^0-9A-F]"))
    if (tag != "" && StrLen(tag) != 6)
        return false
    section.tag := tag
    return true
}

SetSectionNote(app, sectionName, note) {
    changed := false
    Mutate(app, (p) => changed := SetSectionNoteMutation(p, sectionName, note))
    if !changed
        return false
    SaveHistory(app)
    QueueHistoryRebuild(app)
    ShowToast(app, "Updated section note")
    return true
}

SetSectionNoteMutation(p, sectionName, note) {
    if !HasSectionName(p, sectionName) {
        AddSectionName(p, sectionName)
    }
    section := GetSectionObjectByName(p, sectionName)
    if !IsObject(section)
        return false
    section.note := Trim(note)
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

GetItemById(app, id) {
    p := app.activePalette
    if p.HasOwnProp("idMap") && p.idMap.Has(id)
        return p.idMap[id]
    return 0
}

GetItemToken(item) {
    return item.HasOwnProp("id") && item.id != ""
        ? item.id
        : item.hex
}

ItemMatchesToken(item, token) {
    return GetItemToken(item) == token || item.hex == token
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
    if (token == "")
        return

    p := app.activePalette
    item := GetItemByToken(app, token)
    if !item
        return

    actualToken := GetItemToken(item)

    if (p.highlightToken == actualToken)
        return

    oldToken := p.highlightToken
    if (oldToken != "" && app.ui.controls.Has(oldToken)) {
        oldCtrl := app.ui.controls[oldToken]
        oldItem := GetItemByToken(app, oldToken)
        if oldItem && SafeGetControlHwnd(oldCtrl.bg) {
            try oldCtrl.bg.Opt("Background" oldItem.hex)
            try oldCtrl.txt.Opt("cFFFFFF")
        }
    }

    p.selectedHex := item.hex
    p.highlightHex := item.hex
    p.highlightToken := actualToken

    if app.ui.controls.Has(actualToken) {
        ctrl := app.ui.controls[actualToken]
        if SafeGetControlHwnd(ctrl.bg) {
            if (item.hex != "" && StrLen(item.hex) = 6)
                try ctrl.bg.Opt("Background" item.hex)
            try ctrl.txt.Opt("cFFD700")
        }
    }
}

ClearHighlight(app, token) {
    if token == ""
        return

    p := app.activePalette
    oldItem := GetItemByToken(app, token)
    if !oldItem
        return

    p.highlightToken := ""
    p.highlightHex := ""

    actualToken := GetItemToken(oldItem)
    if app.ui.controls.Has(actualToken) {
        ctrl := app.ui.controls[actualToken]
        if SafeGetControlHwnd(ctrl.bg) {
            itemHex := oldItem.hex
            try ctrl.bg.Opt("Background" itemHex)
            try ctrl.txt.Opt("cFFFFFF")
        }
    }
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
    QueueHistoryRebuild(app)

    ShowToast(app, "Created section: " sectionName)
    SetSelectedSection(app, sectionName, true)
    return true
}

RenameSection(app, oldName, newName) {
    if IsSectionLocked(app.activePalette, oldName) {
        ShowToast(app, "Unlock the section first")
        return false
    }
    renamed := false

    Mutate(app, (p) => renamed := RenameSectionMutation(p, oldName, newName))

    if !renamed {
        ShowToast(app, "Could not rename section")
        return false
    }

    SaveHistory(app)
    QueueHistoryRebuild(app)

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

    for section in p.sections {
        if IsObject(section) && section.name = oldName {
            section.name := newName
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
    QueueHistoryRebuild(app)

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
    if IsSectionLocked(app.activePalette, sectionName) {
        ShowToast(app, "Unlock the section first")
        return false
    }
    deleted := false

    Mutate(app, (p) => deleted := DeleteSectionMutation(p, sectionName))

    if !deleted {
        ShowToast(app, "Could not delete section")
        return false
    }

    SaveHistory(app)
    QueueHistoryRebuild(app)

    ShowToast(app, "Deleted section: " sectionName)
    return true
}

DeleteSectionMutation(p, sectionName) {
    sectionName := Trim(sectionName)

    if (sectionName = "" || sectionName = "Default")
        return false

    if !HasSectionName(p, sectionName)
        return false

    toRemove := []
    for section in p.sections {
        if IsObject(section) && section.name = sectionName {
            toRemove.Push(section)
        }
    }
    for section in toRemove {
        Loop p.sections.Length {
            if (p.sections[A_Index] = section) {
                p.sections.RemoveAt(A_Index)
                break
            }
        }
    }

    indicesToRemove := []
    for i, item in p.colors {
        if GetItemSectionNameForState(item) = sectionName {
            indicesToRemove.Push(i)
        }
    }
    
    Loop indicesToRemove.Length {
        idx := indicesToRemove.RemoveAt(indicesToRemove.Length)
        item := p.colors[idx]
        if p.map.Has(item.hex)
            p.map.Delete(item.hex)
        p.colors.RemoveAt(idx)
    }

    EnsureDefaultSection(p)
    if GetSelectedSectionName(p) = sectionName
        p.selectedSection := "Default"
    return true
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
    QueueHistoryRebuild(app)
}

BatchMovePinnedColor(app, targetIds, dir) {
    if !IsObject(targetIds) || targetIds.Length = 0 {
        ShowToast(app, "No colors selected")
        return false
    }

    moved := false
    Mutate(app, (p) => moved := BatchMovePinnedMutation(p, targetIds, dir))

    if !moved {
        ShowToast(app, "Pin the colors first")
        return false
    }

    SaveHistory(app)
    if app.historyVisible {
        QueueHistoryRebuild(app)
    }

    ShowToast(app, "Moved " targetIds.Length " pinned color" (targetIds.Length > 1 ? "s" : ""))
    return true
}

BatchMovePinnedMutation(p, targetIds, dir) {
    Normalize(p)

    pinned := []
    targetTokens := []

    for item in p.colors {
        if item.pinned {
            pinned.Push(item)
            for _, token in targetIds {
                if ItemMatchesToken(item, token) {
                    targetTokens.Push(item)
                    break
                }
            }
        }
    }

    if targetTokens.Length = 0
        return false

    moves := []
    for targetItem in targetTokens {
        targetIndex := 0
        for i, item in pinned {
            if (item = targetItem) {
                targetIndex := i
                break
            }
        }

        if !targetIndex
            continue

        newIndex := targetIndex + dir
        if (newIndex < 1 || newIndex > pinned.Length)
            continue

        moves.Push({from: targetIndex, to: newIndex})
    }

    for move in moves {
        tempOrder := pinned[move.from].pinOrder
        pinned[move.from].pinOrder := pinned[move.to].pinOrder
        pinned[move.to].pinOrder := tempOrder
    }

    Normalize(p)
    return true
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
    sourceItem := GetItemByToken(app, sourceToken)
    targetItem := GetItemByToken(app, targetToken)

    if sourceItem {
        sourceSection := GetItemSectionNameForState(sourceItem)
        targetSection := targetItem ? GetItemSectionNameForState(targetItem) : sourceSection
        if IsSectionLocked(app.activePalette, sourceSection) || IsSectionLocked(app.activePalette, targetSection) {
            ShowToast(app, "Unlock the section first")
            return
        }
    }

    moved := false

    Mutate(app, (p) => moved := ReorderPinnedColorToTargetMutation(p, sourceToken, targetToken))

    if !moved {
        ShowToast(app, "Could not move pinned color")
        return
    }

    SaveHistory(app)
    if app.historyVisible {
        RefreshSectionCells(app, sourceSection)
        if (targetSection != sourceSection)
            RefreshSectionCells(app, targetSection)
        Emit(app, "history_changed")
    }
}

MoveColorToSection(app, sourceToken, sectionName, sourceSection := "") {
    item := GetItemByToken(app, sourceToken)
    if item {
        if (sourceSection = "")
            sourceSection := GetItemSectionNameForState(item)
        if IsSectionLocked(app.activePalette, sourceSection) || IsSectionLocked(app.activePalette, sectionName) {
            ShowToast(app, "Unlock the section first")
            return
        }
    }
    moved := false

    Mutate(app, (p) => moved := MoveColorToSectionMutation(p, sourceToken, sectionName))

    if !moved {
        ShowToast(app, "Could not move color")
        return
    }

    SaveHistory(app)
    if app.historyVisible {
        QueueHistoryRebuild(app)
    }

    ShowToast(app, "Moved to " sectionName)
}

BatchMoveColorToSection(app, targetIds, sectionName) {
    if !IsObject(targetIds) || targetIds.Length = 0 {
        ShowToast(app, "No colors selected")
        return false
    }

    if IsSectionLocked(app.activePalette, sectionName) {
        ShowToast(app, "Unlock the section first")
        return false
    }

    movedCount := 0
    sourceSections := []

    for _, token in targetIds {
        item := GetItemByToken(app, token)
        if !item
            continue

        sourceSection := GetItemSectionNameForState(item)
        if IsSectionLocked(app.activePalette, sourceSection)
            continue

        currentToken := token
        moved := false
        Mutate(app, (p) => (moved := MoveColorToSectionMutation(p, currentToken, sectionName)))

        if moved {
            movedCount++
            if !sourceSections.Has(sourceSection)
                sourceSections.Push(sourceSection)
        }
    }

if movedCount = 0 {
        ShowToast(app, "Could not move colors")
        return false
    }

    SaveHistory(app)
    if app.historyVisible {
        QueueHistoryRebuild(app)
    }

    ShowToast(app, "Moved " movedCount " color" (movedCount > 1 ? "s" : "") " to " sectionName)
    return true
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

MoveColorToSectionMutation(p, sourceToken, sectionName) {
    sectionName := Trim(sectionName)
    if (sectionName = "")
        return false

    Normalize(p)
    AddSectionName(p, sectionName)

    source := 0

    for item in p.colors {
        if ItemMatchesToken(item, sourceToken) {
            source := item
            break
        }
    }

    if !source
        return false

    currentSection := GetItemSectionNameForState(source)
    if IsSectionLocked(p, currentSection) || IsSectionLocked(p, sectionName)
        return false
    if (currentSection = sectionName)
        return true
    if SectionHasHex(p, sectionName, source.hex, sourceToken)
        return false

    source.section := sectionName

    if source.pinned {
        pinned := []
        sourceIndex := 0

        for item in p.colors {
            if item.pinned && GetItemSectionNameForState(item) = sectionName {
                pinned.Push(item)
                if ItemMatchesToken(item, sourceToken)
                    sourceIndex := pinned.Length
            }
        }

        if !sourceIndex
            sourceIndex := pinned.Length + 1

        for index, item in pinned
            item.pinOrder := index
    }

    Normalize(p)
    return true
}

MergeSection(app, sourceName, targetName) {
    if (sourceName = "" || targetName = "" || sourceName = targetName)
        return false
    if IsSectionLocked(app.activePalette, sourceName) || IsSectionLocked(app.activePalette, targetName) {
        ShowToast(app, "Unlock the section first")
        return false
    }

    merged := false
    Mutate(app, (p) => merged := MergeSectionMutation(p, sourceName, targetName))
    if !merged {
        ShowToast(app, "Could not merge section")
        return false
    }
    SaveHistory(app)
    if app.historyVisible
        Emit(app, "history_changed")
    ShowToast(app, "Merged " sourceName " -> " targetName)
    return true
}

MergeSectionMutation(p, sourceName, targetName) {
    if !HasSectionName(p, sourceName) || !HasSectionName(p, targetName)
        return false

    for _, item in p.colors {
        if GetItemSectionNameForState(item) = sourceName {
            if !SectionHasHex(p, targetName, item.hex, GetItemToken(item))
                item.section := targetName
        }
    }

    return DeleteSectionMutation(p, sourceName)
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
        if (GetItemToken(item) == GetItemToken(source))
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
        QueueHistoryRebuild(app)
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

    app.ui.generation++
    RebuildUI(app)

    ShowToast(app, "Moved #" item.hex " -> " targetName)
    return true
}

BatchMoveColorToPalette(app, targetIds, targetName) {
    if !IsObject(targetIds) || targetIds.Length = 0 {
        ShowToast(app, "No colors selected")
        return false
    }

    source := app.activePalette

    if (targetName = "") || (targetName = source.name)
        return false

    if !app.palettes.Has(targetName)
        return false

    target := app.palettes[targetName]

    movedCount := 0

    for _, token in targetIds {
        item := GetItemByToken(app, token)
        if !item
            continue

        if target.map.Has(item.hex)
            continue

        clone := CloneItem(item)
        currentToken := token
        Mutate(app, (p) => RemoveColorByToken(p, currentToken))
        AddColor(target, clone)
        movedCount++
    }

    if movedCount = 0 {
        ShowToast(app, "No colors moved")
        return false
    }

    Normalize(target)
    SavePalette(source, app.version)
    SavePalette(target, app.version)

    app.ui.generation++
    RebuildUI(app)

    ShowToast(app, "Moved " movedCount " color" (movedCount > 1 ? "s" : "") " -> " targetName)
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

    g := Gui("+AlwaysOnTop -Caption +ToolWindow Border")
    g.BackColor := "323338"
    g.SetFont("s9", "Consolas")

    text :=
    (
    "🎨 Nastarxa Palette Manager v" app.version "`n`n"
    "Ctrl + Alt + P   → Toggle Color Picker`n"
    "Ctrl + Alt + O   → Toggle Color Palette`n"
    "Ctrl + Alt + U   → Screenshot Palette Import`n"
    "Ctrl + Alt + I   → Open Palette Manager`n"
    "Ctrl + Alt + F   → Favorites Window`n"
    "Ctrl + Alt + V   → Paste HEX from Clipboard`n"
    "Ctrl + Alt + 1-9 → Switch Palette`n`n"
    "-------------------------`n`n"
    "After Toggle Picker:`n"
    "Middle Mouse     → Save Hex Color`n"
    "Ctrl + Middle    → Save RGB Color`n`n"
    "-------------------------`n`n"
    "In Color Palette:`n"
    "Click           → Copy (by mode)`n"
    "Ctrl + Click    → Copy (opposite)`n"
    "Shift + Click   → Multi Select Toggle`n"
    "Ctrl + Shift    → Batch Select Range`n"
    "Right Click     → Menu`n"
    "Drag            → Reorder Colors`n"
    "Clipboard HEX   → Auto-add color`n`n"
    "Keyboard Navigation:`n"
    "← / →          → Navigate cells`n"
    "↑ / ↓           → Change role`n"
    "Home / End      → Navigate`n"
    "Enter          → Copy (current mode)`n`n"
    "Display Mode (in Manager):`n"
    "HEX Mode: Click=HEX, Ctrl=RGB`n"
    "RGB Mode: Click=RGB, Ctrl=HEX"
    )

    g.bg := g.AddText("x0 y0 w500 h360 Background323338")
    g.txt := g.AddText("x10 y10 cFFFFFF w480", text)

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

