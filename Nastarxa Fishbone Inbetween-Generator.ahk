#Requires AutoHotkey v2.0
#SingleInstance Force
TraySetIcon "Fishbone.ico"

global _ALLOWED := [50, 66, 33, 25, 75, 40, 60]
global _canvasMap := Map()
global _EXAMPLES_FILE := A_ScriptDir "\Fishbone Examples.ini"

^F1::OpenTimelineGui()

TrayTip("Nastarxa Fishbone", "Press Ctrl+F1 to open the timeline")

class GDI {
    static token := 0, pFamily := 0

    static Start() {
        if this.token
            return this.token
        DllCall("LoadLibrary", "Str", "gdiplus")
        si := Buffer(16 + A_PtrSize, 0)
        NumPut("UInt", 1, si, 0)
        NumPut("UInt", 0, si, 4)
        DllCall("gdiplus\GdiplusStartup", "Ptr*", &token := 0, "Ptr", si, "Ptr", 0)
        if !token
            return 0
        this.token := token
        return token
    }

    static Stop() {
        if this.token {
            if this.pFamily {
                DllCall("gdiplus\GdipDeleteFontFamily", "Ptr", this.pFamily)
                this.pFamily := 0
            }
            DllCall("gdiplus\GdiplusShutdown", "Ptr", this.token)
            this.token := 0
        }
    }

    static GetFontFamily() {
        if !this.pFamily {
            DllCall("gdiplus\GdipCreateFontFamilyFromName", "Str", "Consolas", "Ptr", 0, "Ptr*", &fam := 0)
            this.pFamily := fam
        }
        return this.pFamily
    }

    static CreateBitmap(w, h) {
        DllCall("gdiplus\GdipCreateBitmapFromScan0", "Int", w, "Int", h, "Int", 0, "Int", 0x26200A, "Ptr", 0, "Ptr*", &pBitmap := 0)
        return pBitmap
    }

    static GetGraphics(pBitmap) {
        DllCall("gdiplus\GdipGetImageGraphicsContext", "Ptr", pBitmap, "Ptr*", &pGraphics := 0)
        return pGraphics
    }

    static GetHBITMAP(pBitmap) {
        if !pBitmap
            return 0
        DllCall("gdiplus\GdipCreateHBITMAPFromBitmap", "Ptr", pBitmap, "Ptr*", &hBitmap := 0, "UInt", 0xFF000000)
        return hBitmap
    }

    static DeleteGraphics(pGraphics) {
        DllCall("gdiplus\GdipDeleteGraphics", "Ptr", pGraphics)
    }

    static DisposeImage(pImage) {
        DllCall("gdiplus\GdipDisposeImage", "Ptr", pImage)
    }

    static Clear(pGraphics, color := 0xFF2B2D31) {
        DllCall("gdiplus\GdipGraphicsClear", "Ptr", pGraphics, "UInt", color)
    }

    static SetSmoothing(pGraphics, mode := 4) {
        DllCall("gdiplus\GdipSetSmoothingMode", "Ptr", pGraphics, "Int", mode)
    }

    static CreatePen(color, width := 1) {
        DllCall("gdiplus\GdipCreatePen1", "UInt", color, "Float", width, "Int", 2, "Ptr*", &pPen := 0)
        return pPen
    }

    static DeletePen(pPen) {
        DllCall("gdiplus\GdipDeletePen", "Ptr", pPen)
    }

    static CreateBrush(color) {
        DllCall("gdiplus\GdipCreateSolidFill", "UInt", color, "Ptr*", &pBrush := 0)
        return pBrush
    }

    static DeleteBrush(pBrush) {
        DllCall("gdiplus\GdipDeleteBrush", "Ptr", pBrush)
    }

    static LerpColor(c1, c2, t) {
        r1 := (c1 >> 16) & 0xFF, g1 := (c1 >> 8) & 0xFF, b1 := c1 & 0xFF
        r2 := (c2 >> 16) & 0xFF, g2 := (c2 >> 8) & 0xFF, b2 := c2 & 0xFF
        return 0xFF000000 | (Round(r1 + (r2 - r1) * t) << 16) | (Round(g1 + (g2 - g1) * t) << 8) | Round(b1 + (b2 - b1) * t)
    }

    static DrawLine(pGraphics, pPen, x1, y1, x2, y2) {
        DllCall("gdiplus\GdipDrawLineI", "Ptr", pGraphics, "Ptr", pPen, "Int", x1, "Int", y1, "Int", x2, "Int", y2)
    }

    static DrawBezier(pGraphics, pPen, x1, y1, cx1, cy1, cx2, cy2, x2, y2) {
        DllCall("gdiplus\GdipDrawBezierI", "Ptr", pGraphics, "Ptr", pPen, "Int", x1, "Int", y1, "Int", cx1, "Int", cy1, "Int", cx2, "Int", cy2, "Int", x2, "Int", y2)
    }

    static FillEllipse(pGraphics, pBrush, x, y, r) {
        DllCall("gdiplus\GdipFillEllipseI", "Ptr", pGraphics, "Ptr", pBrush, "Int", x - r, "Int", y - r, "Int", r * 2 + 1, "Int", r * 2 + 1)
    }

    static DrawString(pGraphics, text, x, y, w, h, pBrush, fontSize := 10) {
        if text = "" || !pBrush
            return
        pFamily := this.GetFontFamily()
        if !pFamily
            return
        DllCall("gdiplus\GdipCreateFont", "Ptr", pFamily, "Float", fontSize, "Int", 0, "Int", 0, "Ptr*", &pFont := 0)
        DllCall("gdiplus\GdipCreateStringFormat", "Int", 0, "Int", 0, "Ptr*", &pFormat := 0)
        DllCall("gdiplus\GdipSetStringFormatAlign", "Ptr", pFormat, "Int", 1)
        DllCall("gdiplus\GdipSetStringFormatLineAlign", "Ptr", pFormat, "Int", 1)
        rectF := Buffer(16)
        NumPut("Float", x, "Float", y, "Float", w, "Float", h, rectF)
        DllCall("gdiplus\GdipDrawString", "Ptr", pGraphics, "Str", text, "Int", -1, "Ptr", pFont, "Ptr", rectF, "Ptr", pFormat, "Ptr", pBrush)
        DllCall("gdiplus\GdipDeleteStringFormat", "Ptr", pFormat)
        DllCall("gdiplus\GdipDeleteFont", "Ptr", pFont)
    }
}

GetAllowedList(preferred := "") {
    list := []
    if preferred != "" {
        preferred := Integer(preferred)
        if IsAllowed(preferred)
            list.Push(preferred)
    }
    for val in _ALLOWED {
        exists := false
        for current in list {
            if current = val {
                exists := true
                break
            }
        }
        if !exists
            list.Push(val)
    }
    return list
}

IsAllowed(val) {
    for candidate in _ALLOWED {
        if candidate = val
            return true
    }
    return false
}

TryCreatePlacement(leftPos, rightPos, preferredPct, stage, depth, usedMap) {
    for pct in GetAllowedList(preferredPct) {
        pos := Round(leftPos + (rightPos - leftPos) * pct / 100)
        if pos <= leftPos || pos >= rightPos
            continue
        key := "" pos
        if usedMap.Has(key)
            continue
        return {pos: pos, pct: pct, left: leftPos, right: rightPos, depth: depth, stage: stage}
    }
    return 0
}

AddSegment(queue, leftPos, rightPos, depth) {
    if rightPos - leftPos <= 1
        return
    queue.Push({left: leftPos, right: rightPos, depth: depth})
}

SortSegmentsByWidth(queue) {
    sorted := []
    for seg in queue {
        width := seg.right - seg.left
        insertAt := sorted.Length + 1
        Loop sorted.Length {
            other := sorted[A_Index]
            otherWidth := other.right - other.left
            if width > otherWidth || (width = otherWidth && seg.left < other.left) {
                insertAt := A_Index
                break
            }
        }
        sorted.InsertAt(insertAt, seg)
    }
    return sorted
}

NormalizeRefToken(token) {
    token := Trim(StrUpper(token))
    if token = "START" || token = "A" || token = "KF1"
        return "A"
    if token = "END" || token = "B" || token = "KF2"
        return "B"
    if RegExMatch(token, "^(\d+)$", &m)
        return "I" Integer(m[1])
    if RegExMatch(token, "^I(\d+)$", &m)
        return "I" Integer(m[1])
    if RegExMatch(token, "^INBETWEEN\s*(\d+)$", &m)
        return "I" Integer(m[1])
    return ""
}

ParsePriorityRules(text) {
    rules := []
    parts := StrSplit(text, "`n", "`r")

    expanded := []
    for part in parts {
        for sub in StrSplit(part, ",") {
            trimmed := Trim(sub)
            if trimmed != ""
                expanded.Push(trimmed)
        }
    }
    for line in expanded {
        if RegExMatch(line, "i)^\s*(\d+)\s*_\s*([A-Z0-9 ]+)\s*>\s*([A-Z0-9 ]+)\s*=\s*(\d+|AUTO)\s*$", &m) {
            targetIdx := Integer(m[1])
            leftRef := NormalizeRefToken(m[2])
            rightRef := NormalizeRefToken(m[3])
            pctRaw := StrUpper(Trim(m[4]))
            pct := pctRaw = "AUTO" ? "AUTO" : Integer(pctRaw)
            if targetIdx >= 1 && leftRef != "" && rightRef != "" && leftRef != rightRef && (pct = "AUTO" || IsAllowed(pct))
                rules.Push({mode: "priority", targetIdx: targetIdx, leftRef: leftRef, rightRef: rightRef, pct: pct, raw: line})
            continue
        }
        if RegExMatch(line, "i)^\s*(\d+)\s*_\s*F(?:\s*=\s*AUTO)?\s*$", &m) {
            targetIdx := Integer(m[1])
            if targetIdx >= 1
                rules.Push({mode: "follow", targetIdx: targetIdx, raw: line})
        }
    }
    return rules
}

GetRuleCount(rules) {
    maxIdx := 0
    for rule in rules {
        if rule.targetIdx > maxIdx
            maxIdx := rule.targetIdx
    }
    return maxIdx
}

SnapToAllowed(val) {
    nearest := _ALLOWED[1]
    minDist := Abs(val - nearest)
    for candidate in _ALLOWED {
        dist := Abs(val - candidate)
        if dist < minDist {
            minDist := dist
            nearest := candidate
        }
    }
    return nearest
}

LabelToIndex(label, needed) {
    if label = "A"
        return 0
    if label = "B"
        return needed + 1
    if RegExMatch(label, "^I(\d+)$", &m)
        return Integer(m[1])
    return -1
}

ResolveRulePct(rule, needed) {
    if rule.pct != "AUTO"
        return rule.pct
    leftIdx := LabelToIndex(rule.leftRef, needed)
    rightIdx := LabelToIndex(rule.rightRef, needed)
    if leftIdx < 0 || rightIdx < 0 || rightIdx = leftIdx
        return 50
    if rightIdx < leftIdx {
        tmp := leftIdx, leftIdx := rightIdx, rightIdx := tmp
    }
    idealPct := Round(100 * (rule.targetIdx - leftIdx) / (rightIdx - leftIdx))
    return SnapToAllowed(idealPct)
}

EncodeExampleText(text) {
    return StrReplace(text, "`r`n", "`n")
}

DecodeExampleText(text) {
    return StrReplace(text, "`n", "`r`n")
}

GetExampleNames() {
    if !FileExist(_EXAMPLES_FILE)
        return []
    raw := IniRead(_EXAMPLES_FILE)
    names := []
    for line in StrSplit(raw, "`n", "`r") {
        name := Trim(line)
        if name != ""
            names.Push(name)
    }
    return names
}

SaveExample(name, rulesText, notesText := "") {
    name := Trim(name)
    if name = ""
        return false
    IniWrite(EncodeExampleText(rulesText), _EXAMPLES_FILE, name, "Rules")
    IniWrite(notesText, _EXAMPLES_FILE, name, "Notes")
    return true
}

LoadExample(name) {
    if !FileExist(_EXAMPLES_FILE)
        return ""
    return DecodeExampleText(IniRead(_EXAMPLES_FILE, name, "Rules", ""))
}

LoadExampleNotes(name) {
    if !FileExist(_EXAMPLES_FILE)
        return ""
    return IniRead(_EXAMPLES_FILE, name, "Notes", "")
}

DeleteExample(name) {
    if !FileExist(_EXAMPLES_FILE)
        return
    try IniDelete(_EXAMPLES_FILE, name)
}

GetPlacementLabel(idx) {
    return "I" idx
}

FindPlacementByLabel(placementsByIndex, label) {
    if label = "A"
        return {exists: true, pos: 0, label: "A"}
    if label = "B"
        return {exists: true, pos: 100, label: "B"}
    if RegExMatch(label, "^I(\d+)$", &m) {
        idx := Integer(m[1])
        if placementsByIndex.Has(idx) {
            p := placementsByIndex[idx]
            return {exists: true, pos: p.pos, label: p.label}
        }
    }
    return {exists: false}
}

BuildFinalStops(placementsByIndex) {
    stops := [{label: "A", pos: 0, type: "endpoint"}]
    for _, placement in placementsByIndex
        stops.Push({label: placement.pct, pos: placement.pos, type: placement.stage, id: placement.label})
    stops.Push({label: "B", pos: 100, type: "endpoint"})

    sortedStops := []
    for stop in stops {
        insertAt := sortedStops.Length + 1
        Loop sortedStops.Length {
            if stop.pos < sortedStops[A_Index].pos {
                insertAt := A_Index
                break
            }
        }
        sortedStops.InsertAt(insertAt, stop)
    }
    return sortedStops
}

BuildQueueFromStops(stops, depth := 2) {
    queue := []
    for i, stop in stops {
        if i < stops.Length
            AddSegment(queue, stop.pos, stops[i + 1].pos, depth)
    }
    return queue
}

TakeBestSegment(queue) {
    queue := SortSegmentsByWidth(queue)
    if queue.Length = 0
        return {queue: queue, seg: 0}
    seg := queue.RemoveAt(1)
    return {queue: queue, seg: seg}
}

AddPlacementToQueue(queue, placement) {
    AddSegment(queue, placement.left, placement.pos, placement.depth + 1)
    AddSegment(queue, placement.pos, placement.right, placement.depth + 1)
    return queue
}

SeedAutoPriorityAnchors(plan, followRuleMap, needed, usedMap) {
    if needed <= 0 || followRuleMap.Count = 0
        return false

    progress := false
    midLeft := Ceil(needed / 2)
    midRight := Floor(needed / 2) + 1
    anchorTargets := []
    anchorTargets.Push(midLeft)
    if midRight != midLeft
        anchorTargets.Push(midRight)

    for targetIdx in anchorTargets {
        if !followRuleMap.Has(targetIdx) || plan.placementsByIndex.Has(targetIdx)
            continue
        pct := 50
        if anchorTargets.Length = 2
            pct := (targetIdx = midLeft) ? 40 : 60
        anchor := TryCreatePlacement(0, 100, pct, "priority", 1, usedMap)
        if !anchor
            continue
        anchor.label := GetPlacementLabel(targetIdx)
        anchor.leftRef := "A"
        anchor.rightRef := "B"
        anchor.targetIdx := targetIdx
        anchor.ruleText := followRuleMap[targetIdx].raw " [auto-anchor]"
        usedMap["" anchor.pos] := true
        plan.placementsByIndex[targetIdx] := anchor
        plan.placements.Push(anchor)
        progress := true
    }

    return progress
}

ResolveFollowRuns(plan, followRuleMap, needed, usedMap) {
    progress := false
    idx := 1
    while idx <= needed {
        if !followRuleMap.Has(idx) || plan.placementsByIndex.Has(idx) {
            idx += 1
            continue
        }

        runStart := idx
        runEnd := idx
        while runEnd < needed && followRuleMap.Has(runEnd + 1) && !plan.placementsByIndex.Has(runEnd + 1)
            runEnd += 1

        leftIdx := runStart - 1
        rightIdx := runEnd + 1
        leftKnown := (leftIdx = 0) || plan.placementsByIndex.Has(leftIdx)
        rightKnown := (rightIdx = needed + 1) || plan.placementsByIndex.Has(rightIdx)

        if !leftKnown || !rightKnown {
            idx := runEnd + 1
            continue
        }

        leftPos := leftIdx = 0 ? 0 : plan.placementsByIndex[leftIdx].pos
        rightPos := rightIdx = needed + 1 ? 100 : plan.placementsByIndex[rightIdx].pos
        spanCount := rightIdx - leftIdx
        if spanCount <= 1 {
            idx := runEnd + 1
            continue
        }

        Loop runEnd - runStart + 1 {
            targetIdx := runStart + A_Index - 1
            frac := (targetIdx - leftIdx) / spanCount
            pos := leftPos + (rightPos - leftPos) * frac
            pct := SnapToAllowed(Round(100 * (pos - leftPos) / (rightPos - leftPos)))
            placement := {pos: pos, pct: pct, left: leftPos, right: rightPos, depth: 1, stage: "follow"}
            placement.label := GetPlacementLabel(targetIdx)
            placement.leftRef := leftIdx = 0 ? "A" : GetPlacementLabel(targetIdx - 1)
            placement.rightRef := rightIdx = needed + 1 ? "B" : GetPlacementLabel(targetIdx + 1)
            placement.targetIdx := targetIdx
            placement.ruleText := followRuleMap[targetIdx].raw
            usedMap["" pos] := true
            plan.placementsByIndex[targetIdx] := placement
            plan.placements.Push(placement)
            progress := true
        }

        idx := runEnd + 1
    }

    return progress
}

ResolvePriorityPending(plan, pendingRules, usedMap, needed) {
    nextPending := []
    progress := false
    for rule in pendingRules {
        if plan.placementsByIndex.Has(rule.targetIdx)
            continue
        leftNode := FindPlacementByLabel(plan.placementsByIndex, rule.leftRef)
        rightNode := FindPlacementByLabel(plan.placementsByIndex, rule.rightRef)
        if !leftNode.exists || !rightNode.exists {
            nextPending.Push(rule)
            continue
        }
        leftPos := leftNode.pos
        rightPos := rightNode.pos
        if rightPos < leftPos {
            tmp := leftPos, leftPos := rightPos, rightPos := tmp
        }
        pct := ResolveRulePct(rule, needed)
        priority := TryCreatePlacement(leftPos, rightPos, pct, "priority", 1, usedMap)
        if !priority {
            nextPending.Push(rule)
            continue
        }
        priority.label := GetPlacementLabel(rule.targetIdx)
        priority.leftRef := leftNode.label
        priority.rightRef := rightNode.label
        priority.targetIdx := rule.targetIdx
        priority.ruleText := rule.raw
        usedMap["" priority.pos] := true
        plan.placementsByIndex[rule.targetIdx] := priority
        plan.placements.Push(priority)
        progress := true
    }
    return {pending: nextPending, progress: progress}
}

GenerateFishbonePlan(totalInbetweens, followPct, priorityRules) {
    plan := {placements: [], finalStops: [], placementsByIndex: Map()}
    needed := totalInbetweens
    if needed <= 0 {
        plan.finalStops := [{label: "A", pos: 0, type: "endpoint"}, {label: "B", pos: 100, type: "endpoint"}]
        return plan
    }

    usedMap := Map()
    priorityPending := []
    followRuleMap := Map()
    hasExplicitPriority := false
    for rule in priorityRules {
        if rule.targetIdx > needed
            continue
        if rule.mode = "priority" {
            priorityPending.Push(rule)
            hasExplicitPriority := true
        } else if rule.mode = "follow"
            followRuleMap[rule.targetIdx] := rule
    }

    if !hasExplicitPriority && followRuleMap.Count > 0
        SeedAutoPriorityAnchors(plan, followRuleMap, needed, usedMap)

    loopGuard := 0
    while priorityPending.Length > 0 && loopGuard < needed * 4 {
        loopGuard += 1
        resolved := ResolvePriorityPending(plan, priorityPending, usedMap, needed)
        priorityPending := resolved.pending
        followProgress := ResolveFollowRuns(plan, followRuleMap, needed, usedMap)
        if !resolved.progress && !followProgress
            break
    }

    if followRuleMap.Count > 0
        ResolveFollowRuns(plan, followRuleMap, needed, usedMap)

    queue := plan.placementsByIndex.Count ? BuildQueueFromStops(BuildFinalStops(plan.placementsByIndex), 2) : [{left: 0, right: 100, depth: 1}]

    Loop needed {
        idx := A_Index
        if plan.placementsByIndex.Has(idx)
            continue
        if followRuleMap.Has(idx)
            continue
        pick := TakeBestSegment(queue)
        queue := pick.queue
        seg := pick.seg
        if !seg
            break
        next := TryCreatePlacement(seg.left, seg.right, followPct, "follow", seg.depth, usedMap)
        if !next
            continue
        next.label := GetPlacementLabel(idx)
        next.leftRef := ""
        next.rightRef := ""
        next.targetIdx := idx
        next.ruleText := ""
        usedMap["" next.pos] := true
        plan.placementsByIndex[idx] := next
        plan.placements.Push(next)
        queue := AddPlacementToQueue(queue, next)
        if priorityPending.Length > 0 || followRuleMap.Count > 0 {
            resolved := ResolvePriorityPending(plan, priorityPending, usedMap, needed)
            priorityPending := resolved.pending
            ResolveFollowRuns(plan, followRuleMap, needed, usedMap)
            queue := BuildQueueFromStops(BuildFinalStops(plan.placementsByIndex), 2)
        }
    }

    plan.finalStops := BuildFinalStops(plan.placementsByIndex)
    return plan
}

GetCanvasState(g) {
    priorityRules := ParsePriorityRules(g.priorityRules.Value)
    totalInbetweens := GetRuleCount(priorityRules)
    followPct := 50

    g.canvas.GetPos(, , &w, &h)
    if w < 100
        w := 620
    if h < 100
        h := 320

    ml := 60, mr := 60, mt := 36, mb := 36
    gw := w - ml - mr
    gh := h - mt - mb

    return {totalInbetweens: totalInbetweens, followPct: followPct, priorityRules: priorityRules, w: w, h: h, ml: ml, mr: mr, mt: mt, mb: mb, gw: gw, gh: gh}
}

PosToX(s, pos) {
    return Round(s.ml + s.gw * pos / 100)
}

DrawBranch(pGraphics, pPen, baseY, leftX, nodeX, rightX, arcHeight, above := true) {
    dir := above ? -1 : 1
    topY := baseY + dir * arcHeight
    midLeft := Round((leftX + nodeX) / 2)
    midRight := Round((nodeX + rightX) / 2)

    GDI.DrawBezier(pGraphics, pPen, leftX, baseY, leftX, topY, midLeft, topY, nodeX, baseY)
    GDI.DrawBezier(pGraphics, pPen, nodeX, baseY, midRight, topY, rightX, topY, rightX, baseY)
}

RedrawCanvas(g) {
    s := GetCanvasState(g)
    plan := GenerateFishbonePlan(s.totalInbetweens, s.followPct, s.priorityRules)

    pBitmap := GDI.CreateBitmap(s.w, s.h)
    pGraphics := GDI.GetGraphics(pBitmap)
    if !pBitmap || !pGraphics {
        UpdateOutput(g, plan, s)
        return
    }
    try DllCall("gdiplus\GdipSetSmoothingMode", "Ptr", pGraphics, "Int", 4)
    GDI.Clear(pGraphics, 0xFF2B2D31)

    baseY := Round(s.mt + s.gh / 2)

    pAxisPen := GDI.CreatePen(0xFFE8E8E8, 2)
    pTickPen := GDI.CreatePen(0xFFBFC5D2, 2)
    pPriorityPen := GDI.CreatePen(0xFFFFC857, 2)
    pFollowPen := GDI.CreatePen(0xFF72DDF7, 2)
    pLabelBrush := GDI.CreateBrush(0xFFFFFFFF)
    pMutedBrush := GDI.CreateBrush(0xFF9AA0AA)
    pPriorityBrush := GDI.CreateBrush(0xFFFFC857)
    pFollowBrush := GDI.CreateBrush(0xFF72DDF7)
    pDotBrush := GDI.CreateBrush(0xFFFFFFFF)

    GDI.DrawLine(pGraphics, pAxisPen, s.ml, baseY, s.ml + s.gw, baseY)

    for stop in plan.finalStops {
        x := PosToX(s, stop.pos)
        tickH := (stop.type = "endpoint") ? 22 : 18
        GDI.DrawLine(pGraphics, pTickPen, x, baseY - tickH, x, baseY + tickH)
        GDI.FillEllipse(pGraphics, pDotBrush, x, baseY, 4)

        if stop.type = "endpoint" {
            labelY := baseY - 42
            GDI.DrawString(pGraphics, stop.label, x - 20, labelY, 40, 24, pLabelBrush, 18)
        } else {
            labelBrush := (stop.type = "priority") ? pPriorityBrush : pFollowBrush
            labelY := baseY - 56
            GDI.DrawString(pGraphics, stop.label, x - 20, labelY, 40, 20, labelBrush, 14)
        }
    }

    showBranches := !g.HasProp("showLines") || g.showLines
    if showBranches {
        pCount := 0, fCount := 0
        for placement in plan.placements {
            if placement.stage = "priority"
                pCount += 1
            else
                fCount += 1
        }
        pIdx := 0, fIdx := 0, seqIdx := 0
        for placement in plan.placements {
            seqIdx += 1
            leftX := PosToX(s, placement.left)
            nodeX := PosToX(s, placement.pos)
            rightX := PosToX(s, placement.right)
            if placement.stage = "priority" {
                t := pCount > 1 ? pIdx / (pCount - 1) : 0
                branchPen := GDI.CreatePen(GDI.LerpColor(0xFFFFD700, 0xFFFFB300, t), 2)
                pIdx += 1
            } else {
                t := fCount > 1 ? fIdx / (fCount - 1) : 0
                branchPen := GDI.CreatePen(GDI.LerpColor(0xFF99EEFF, 0xFF7EC8E3, t), 2)
                fIdx += 1
            }
            arcHeight := 10 + placement.depth * 12 + (seqIdx - 1) * 5
            above := placement.stage != "follow"
            DrawBranch(pGraphics, branchPen, baseY, leftX, nodeX, rightX, arcHeight, above)
            GDI.DeletePen(branchPen)
        }
    }

    GDI.DrawString(pGraphics, "A", s.ml - 24, baseY - 4, 20, 20, pLabelBrush, 18)
    GDI.DrawString(pGraphics, "B", s.ml + s.gw + 8, baseY - 4, 20, 20, pLabelBrush, 18)
    GDI.DrawString(pGraphics, "Priority", s.ml, s.h - 28, 80, 16, pPriorityBrush, 10)
    GDI.DrawString(pGraphics, "Follow", s.ml + 86, s.h - 28, 70, 16, pFollowBrush, 10)
    GDI.DrawString(pGraphics, "Allowed: 50, 66, 33, 25, 75, 40, 60", s.ml + 170, s.h - 28, 320, 16, pMutedBrush, 10)

    hBitmap := GDI.GetHBITMAP(pBitmap)
    if hBitmap
        g.canvas.Value := "HBITMAP:" hBitmap

    GDI.DeletePen(pAxisPen)
    GDI.DeletePen(pTickPen)
    GDI.DeletePen(pPriorityPen)
    GDI.DeletePen(pFollowPen)
    GDI.DeleteBrush(pLabelBrush)
    GDI.DeleteBrush(pMutedBrush)
    GDI.DeleteBrush(pPriorityBrush)
    GDI.DeleteBrush(pFollowBrush)
    GDI.DeleteBrush(pDotBrush)
    GDI.DeleteGraphics(pGraphics)
    GDI.DisposeImage(pBitmap)

    UpdateOutput(g, plan, s)
}

UpdateOutput(g, plan, s) {
    text := "Fishbone Order`r`n"
    text .= "Inbetweens: " s.totalInbetweens "`r`n"
    text .= "Auto Follow: " s.followPct "`r`n"
    text .= "Rules: " s.priorityRules.Length "`r`n`r`n"

    text .= "Generation Steps`r`n"
    if plan.placements.Length = 0 {
        text .= "A -> B only`r`n`r`n"
    } else {
        for i, placement in plan.placements {
            role := placement.stage = "priority" ? "priority" : "follow"
            span := (placement.leftRef != "" && placement.rightRef != "") ? placement.leftRef " > " placement.rightRef : placement.left " > " placement.right
            ruleText := placement.ruleText != "" ? " [" placement.ruleText "]" : ""
            text .= Format("{:02d}. {} {} on {} -> {}% (pos {}){}", i, placement.label, role, span, placement.pct, placement.pos, ruleText) "`r`n"
        }
        text .= "`r`n"
    }

    text .= "Final Order`r`n"
    for i, stop in plan.finalStops {
        if stop.type = "endpoint"
            text .= stop.label
        else
            text .= stop.label "%"
        if i < plan.finalStops.Length
            text .= " -> "
    }

    g.output.Value := text
}

CopyOutput(g) {
    A_Clipboard := g.output.Value
    TrayTip("Timeline", "Copied to clipboard")
}

ShowGuide() {

    guideGui := Gui("+AlwaysOnTop +ToolWindow", "📘 Fishbone Guide")

    guideGui.BackColor := "25282E"
    guideGui.SetFont("s10", "Segoe UI")

    guideGui.MarginX := 16
    guideGui.MarginY := 14

    guideGui.SetFont("s12", "Segoe UI")
    guideGui.AddText(
        "cFFFFFF",
        "Fishbone Timeline Rules"
    )
    guideGui.SetFont("s10", "Segoe UI")

    guideGui.AddText(
        "xm y+6 c909090",
        "Create manual or automatic inbetween priorities."
    )

    guideGui.AddText(
        "xm y+18 cFFD54F",
        "Rule Format"
    )

    formatText :=
    "
    (
    Priority:
        <N>_<A/B/IN>><A/B/IN>=<PCT>

    Follow:
        <N>_f

    N     = inbetween number
    A/B   = start & end endpoint
    I1/I2 = other inbetween indexes
    PCT   = interpolation percentage
    )"

    guideGui.SetFont("s9", "Segoe UI")
    guideGui.AddEdit(
        "xm w540 h170 ReadOnly -VScroll Background1E2127 cFFFFFF",
        formatText
    )

    guideGui.SetFont("s10", "Segoe UI")
    guideGui.AddText(
        "xm y+14 cFFD54F",
        "Priority Examples"
    )

    priorityText :=
    "
    (
    3_A>B=50
    → Inbetween 3 positioned at 50% between A and B

    2_1>3=25
    → Inbetween 2 positioned at 25% between I1 and I3

    3_A>B=Auto
    → Automatically calculated percentage
    )"

    guideGui.SetFont("s9", "Segoe UI")
    guideGui.AddEdit(
        "xm w540 h138 ReadOnly -VScroll Background1E2127 cC8E6C9",
        priorityText
    )

    guideGui.SetFont("s10", "Segoe UI")
    guideGui.AddText(
        "xm y+14 cFFD54F",
        "Follow Examples"
    )

    followText :=
    "
    (
    1_f
    → Automatically placed between neighbors

    2_f=Auto
    → Same behavior as 2_f
    )"

    guideGui.SetFont("s9", "Segoe UI")
    guideGui.AddEdit(
        "xm w540 h90 ReadOnly -VScroll Background1E2127 cBBDEFB",
        followText
    )

    guideGui.SetFont("s10", "Segoe UI")
    guideGui.AddText(
        "xm y+14 cFFD54F",
        "Allowed Percentages"
    )

    guideGui.AddText(
        "xm y+6 cFFFFFF",
        "25   33   40   50   60   66   75"
    )

    guideGui.AddText(
        "xm y+7 c909090",
        "Rules can be separated with commas or new lines."
    )

    btnClose := guideGui.AddButton(
        "xm y+10 w120 h30",
        "Close"
    )

    btnClose.OnEvent(
        "Click",
        (*) => guideGui.Destroy()
    )

    guideGui.Show("w580 h740 Center")
}

OpenExamplesGui(mainGui) {

    eg := Gui("+Owner" mainGui.Hwnd " +Resize", "Examples")
    eg.BackColor := "25282E"

    eg.SetFont("s10", "Segoe UI")
    eg.MarginX := 14
    eg.MarginY := 14

    eg.AddText("x14 y12 cFFFFFF", "Saved Examples")

    eg.list := eg.AddListBox(
        "x14 y36 w220 h240 Background1E2127 cFFFFFF"
    )

    eg.btnLoad := eg.AddButton(
        "x14 y286 w68 h30",
        "📂 Load"
    )

    eg.btnSave := eg.AddButton(
        "x90 yp w68 h30",
        "💾 Save"
    )

    eg.btnDelete := eg.AddButton(
        "x166 yp w68 h30",
        "🗑 Delete"
    )

    rightX := 250

    eg.AddText("x" rightX " y12 cFFFFFF", "Example Name")

    eg.nameEdit := eg.AddEdit(
        "x" rightX " y36 w320 h28 Background1E2127 cFFFFFF",
        ""
    )

    eg.AddText("x" rightX " y74 cFFFFFF", "Rules")

    eg.rulesEdit := eg.AddEdit(
        "x" rightX " y98 w320 h260 Multi WantTab Background1E2127 cFFFFFF",
        mainGui.priorityRules.Value
    )

    eg.AddText("x" rightX " y370 cFFFFFF", "Notes")

    eg.notesEdit := eg.AddEdit(
        "x" rightX " y394 w320 h110 Multi Background1E2127 cFFFFFF",
        ""
    )

    eg.status := eg.AddText(
        "x14 y520 w556 h24 cA0A0A0",
        "Ready"
    )

    eg.list.OnEvent("Change", (*) => (
        eg.nameEdit.Value := eg.list.Text,
        eg.rulesEdit.Value := LoadExample(eg.list.Text),
        eg.notesEdit.Value := LoadExampleNotes(eg.list.Text),
        eg.status.Text := "📄 Loaded: " eg.list.Text
    ))

    eg.btnLoad.OnEvent("Click", (*) => (
        mainGui.priorityRules.Value := eg.rulesEdit.Value,
        RedrawCanvas(mainGui),
        eg.status.Text := "✅ Applied to timeline"
    ))

    eg.btnSave.OnEvent("Click", (*) => (
        SaveExample(
            eg.nameEdit.Value,
            eg.rulesEdit.Value,
            eg.notesEdit.Value
        ),
        eg.status.Text := "💾 Saved: " eg.nameEdit.Value
    ))

    eg.btnDelete.OnEvent("Click", (*) => (
        DeleteExample(eg.nameEdit.Value),
        DllCall("SendMessage", "Ptr", eg.list.Hwnd, "UInt", 0x018B, "Ptr", 0, "Ptr", 0),
        eg.list.Add(GetExampleNames()),
        eg.status.Text := "🗑 Deleted: " eg.nameEdit.Value,
        eg.nameEdit.Value := "",
        eg.rulesEdit.Value := "",
        eg.notesEdit.Value := ""
    ))

    for name in GetExampleNames()
        eg.list.Add([name])

    eg.Show("w590 h560 Center")
}

OpenTimelineGui() {

    static guiObj := 0

    if IsObject(guiObj) {
        try {
            guiObj.Show()
            WinActivate(guiObj.Hwnd)
        }
        return
    }

    if !GDI.token
        GDI.Start()

    g := Gui("+Resize +MinSize500x420", "Nastarxa Fishbone Inbetween-Generator")
    guiObj := g

    g.BackColor := "25282E"
    g.SetFont("s10", "Segoe UI")

    g.MarginX := 14
    g.MarginY := 14

    g.AddText(
        "x14 y12 cFFFFFF",
        "Timeline Rules"
    )

    g.btnGuide := g.AddButton(
        "x14 y38 w70 h28",
        "📘 Guide"
    )

    g.btnExamples := g.AddButton(
        "x90 yp w100 h28",
        "📂 Examples"
    )

    g.showLines := true
    g.btnLines := g.AddButton(
        "x195 yp w65 h28",
        "🔍 Lines"
    )
    g.btnLines.OnEvent("Click", (*) => (
        g.showLines := !g.showLines,
        g.btnLines.Text := g.showLines ? "🔍 Lines" : "🔍 Hide",
        RedrawCanvas(g)
    ))

    g.priorityRules := g.AddEdit(
        "x14 y74 w620 h96 Multi WantTab Background1E2127 cFFFFFF",
        "4_f=Auto`r`n3_f=Auto`r`n1_f=Auto`r`n2_f=Auto"
    )

    g.AddText(
        "x14 y178 w620 c909090",
        "Format: 3_A>B=50, 1_f, 2_f    |    Use commas or new lines    |    Values: 25 33 40 50 60 66 75"
    )

    g.AddText(
        "x14 y208 cFFFFFF",
        "Timeline Preview"
    )

    g.canvas := g.AddPicture(
        "x14 y232 w620 h220 Background1E2127"
    )

    g.AddText(
        "x14 y462 cFFFFFF",
        "Generated Output"
    )

    g.output := g.AddEdit(
        "x14 y486 w620 h120 ReadOnly Multi Background1E2127 cFFFFFF"
    )

    g.btnCopy := g.AddButton(
        "x14 y614 w100 h30",
        "📋 Copy"
    )

    g.status := g.AddText(
        "x126 y620 w510 c909090",
        "Ready"
    )

    g.priorityRules.OnEvent(
        "Change",
        (*) => (
            RedrawCanvas(g),
            g.status.Text := "🎞 Timeline updated"
        )
    )

    g.btnGuide.OnEvent(
        "Click",
        (*) => ShowGuide()
    )

    g.btnExamples.OnEvent(
        "Click",
        (*) => OpenExamplesGui(g)
    )

    g.btnCopy.OnEvent(
        "Click",
        (*) => CopyOutput(g)
    )

    g.OnEvent(
        "Close",
        (*) => (
            CanvasCleanup(g.canvas.Hwnd),
            guiObj := 0
        )
    )

    g.OnEvent("Size", OnGuiSize)

    g._initialSetup := true

    g.Show("w650 h670 Center")

    g._initialSetup := false

    _canvasMap[g.canvas.Hwnd] := g

    RedrawCanvas(g)
}

OnGuiSize(g, minMax, aW, aH) {
    if minMax = -1
        return
    if g.HasProp("_initialSetup") && g._initialSetup
        return
    try {
        newW := aW - 20
        if newW < 400
            newW := 400
        canvasH := aH - 310
        if canvasH < 160
            canvasH := 160
        outputH := aH - canvasH - 200
        if outputH < 100
            outputH := 100
        g.priorityRules.Move(,, newW, 80)
        g.canvas.Move(,, newW, canvasH)
        g.output.Move(,, newW, outputH)
        RedrawCanvas(g)
    }
}

CanvasCleanup(hwnd) {
    global _canvasMap
    if _canvasMap.Has(hwnd)
        _canvasMap.Delete(hwnd)
}

