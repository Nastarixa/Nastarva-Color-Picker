OpenExportDialog(app) {
    formats := ["txt", "json", "ini", "csv", "png", "ase"]

    g := Gui("+AlwaysOnTop +ToolWindow +Border", "Export Palette")
    g.BackColor := "323338"
    g.SetFont("s9", "Consolas")
    g.MarginX := 16
    g.MarginY := 12

    g.AddText("cFFFFFF", "Export Format:")
    g.fmtDrop := g.AddDropDownList("w200 y+4", formats)
    g.fmtDrop.Value := 1
    g.fmtDrop.OnEvent("Change", (*) => TogglePngOptions(g))

    g.AddText("cFFFFFF y+10", "Filename:")
    g.fname := g.AddEdit("w200 y+4", app.activePalette.name)

    g.pngStyleLabel := g.AddText("cAAAAAA y+10 Hidden", "PNG Style:")
    g.pngStyle := g.AddDropDownList("w200 y+4 Hidden", ["Grid with Section Headers", "Character Sheet Style"])
    g.pngStyle.Value := 1

    g.pngInfoCheck := g.AddCheckbox("y+8 w200 Hidden cAAAAAA", "Show HEX, RGB, Role info")

    g.AddButton("w90 h28 y+15", "Export").OnEvent("Click", (*) => DoExportPalette(app, g))
    g.AddButton("w90 h28 x+10", "Cancel").OnEvent("Click", (*) => g.Destroy())

    g.Show("AutoSize Center")
}

TogglePngOptions(g) {
    isPng := g.fmtDrop.Text = "png"
    g.pngStyleLabel.Visible := isPng
    g.pngStyle.Visible := isPng
    g.pngInfoCheck.Visible := isPng
    g.Show("AutoSize Center")
}

DoExportPalette(app, inputGui) {
    format := inputGui.fmtDrop.Text
    name := inputGui.fname.Value
    pngStyle := format = "png" ? inputGui.pngStyle.Value : 0
    pngInfo := format = "png" ? (inputGui.pngInfoCheck.Value = 1) : 0
    inputGui.Destroy()
    ExportActivePalette(app, format, name, pngStyle, pngInfo)
}

OpenGradientDialog(app) {
    p := app.activePalette
    colors := []
    for item in p.colors {
        colors.Push(item.hex "|" item.name)
    }
    if colors.Length < 2 {
        ShowToast(app, "Need at least 2 colors")
        return
    }

    g := Gui("+AlwaysOnTop +ToolWindow +Border", "Color Gradient Generator")
    g.BackColor := "323338"
    g.SetFont("s9", "Consolas")
    g.MarginX := 14
    g.MarginY := 12

    rowY := 10
    gap := 8
    gradient := []

    ; =========================
    ; CONTROLS SECTION
    ; =========================
    g.AddText("x10 y" rowY " cAAAAAA", "Gradient Flow")
    rowY += 18

    ; start
    g.startDrop := g.AddDropDownList("x10 y" rowY " w120", colors)
    g.startPreview := g.AddProgress("x135 y" rowY " w25 h24")

    ; arrow indicator (visual flow)
    g.AddText("x165 y" rowY " cAAAAAA", "→")

    ; steps
    x := 177
    g.stepDown := g.AddButton("x" x " y" rowY " w10 h24 0x200", "−")
    g.stepsEdit := g.AddEdit("x" x+12 " y" rowY " w26 h24 Number Center", "10")
    g.stepUp := g.AddButton("x" x+40 " y" rowY " w10 h24 0x200", "+")

    ; end
    g.endDrop := g.AddDropDownList("x235 y" rowY " w120", colors)
    g.endPreview := g.AddProgress("x360 y" rowY " w25 h24")

    rowY += 32

    ; =========================
    ; LARGE PREVIEW AREA
    ; =========================
    g.AddText("x10 y" rowY " cAAAAAA", "Preview")
    rowY += 18

    g.previewSlots := []

    slotCount := 20
    xBase := 10
    slotW := 360 / slotCount
    slotH := 24

    Loop slotCount {
        x := xBase + (A_Index - 1) * slotW
        ctrl := g.AddProgress("x" Round(x) " y" rowY " w" Round(slotW) " h" slotH " Background2A2A2A")
        g.previewSlots.Push(ctrl)
    }
    rowY += 30
    ; =========================
    ; ACTION BAR
    ; =========================
    g.btnAdd := g.AddButton("x10 y" rowY " w180 h28", "➕ Add Gradient")
    g.btnClose := g.AddButton("x200 y" rowY " w180 h28", "✖ Close")

    ; =========================
    ; EVENTS
    ; =========================
    g.btnAdd.OnEvent("Click", (*) => AddGradientColors(app, g, colors))
    g.btnClose.OnEvent("Click", (*) => g.Destroy())

    g.startDrop.OnEvent("Change", (*) => UpdateGradientPreview(g, colors))
    g.endDrop.OnEvent("Change", (*) => UpdateGradientPreview(g, colors))
    g.stepsEdit.OnEvent("Change", (*) => UpdateGradientPreview(g, colors))
    g.stepDown.OnEvent("Click", (*) => StepChange(g, -1, colors))
    g.stepUp.OnEvent("Click", (*) => StepChange(g, 1, colors))

    ; =========================
    ; INIT
    ; =========================
    UpdateGradientPreview(g, colors)

    g.Show("AutoSize Center")
}

StepChange(g, delta, colors) {
    try steps := Integer(Round(g.stepsEdit.Value))
    catch
        steps := 5
    steps := Max(2, Min(20, steps + delta))
    g.stepsEdit.Value := steps
    UpdateGradientPreview(g, colors)
}

UpdateGradientPreview(g, colors) {
    startIdx := g.startDrop.Value
    endIdx := g.endDrop.Value
    if startIdx = 0 || endIdx = 0
        return

    startHex := StrSplit(colors[startIdx], "|")[1]
    endHex := StrSplit(colors[endIdx], "|")[1]

    try g.startPreview.Opt("Background" startHex)
    try g.endPreview.Opt("Background" endHex)

    stepsVal := g.stepsEdit.Value
    try steps := Integer(Round(stepsVal))
    catch
        steps := 5
    steps := Max(2, Min(20, steps))
    g.stepsEdit.Value := steps

    gradient := GenerateGradient(startHex, endHex, steps)

    ; 🔥 UPDATE SLOTS (NOT CREATE NEW ONES)
    Loop g.previewSlots.Length {
        ctrl := g.previewSlots[A_Index]

        if A_Index <= gradient.Length {
            hex := gradient[A_Index]
            ctrl.Opt("Background" hex)
        } else {
            ctrl.Opt("Background2A2A2A")
        }
    }
}

AddGradientColors(app, g, colors) {
    startIdx := g.startDrop.Value
    endIdx := g.endDrop.Value
    if startIdx = 0 || endIdx = 0 || startIdx > colors.Length || endIdx > colors.Length {
        ShowToast(app, "Select start and end colors")
        return
    }
    stepsVal := g.stepsEdit.Value
    try steps := Integer(Round(stepsVal))
    catch
        steps := 5
    if steps < 2
        steps := 2
    if steps > 20
        steps := 20

    startHex := StrSplit(colors[startIdx], "|")[1]
    endHex := StrSplit(colors[endIdx], "|")[1]

    gradient := GenerateGradient(startHex, endHex, steps)

    p := app.activePalette
    for i, hex in gradient {
        if p.map.Has(hex)
            continue
        rgb := HexToRGB(hex)
        name := GetColorName(hex)
        item := CreateItem(hex, rgb.r "," rgb.g "," rgb.b, name, "Base")
        item.section := "Gradient"
        item.pinned := 0
        AddColor(p, item)
        AddSectionName(p, "Gradient")
    }

    g.Destroy()
    ShowToast(app, "Added " gradient.Length " gradient colors")
    RefreshPaletteManager(app, app.paletteGui)
    SwitchPalette(app, p.name)
}

OpenContrastCheckerDialog(app) {
    p := app.activePalette
    colors := []
    for item in p.colors {
        colors.Push(item.hex "|" item.name)
    }
    if colors.Length < 2 {
        ShowToast(app, "Need at least 2 colors")
        return
    }

    cg := Gui("+AlwaysOnTop +ToolWindow +Border", "WCAG Contrast Checker")
    cg.BackColor := "323338"
    cg.SetFont("s9", "Consolas")
    cg.MarginX := 14
    cg.MarginY := 12
    cg.myColors := colors
    cg.myApp := app

    rowY := 10
    gap := 8

    cg.AddText("x10 y" rowY " cAAAAAA", "Foreground")
    cg.AddText("x160 y" rowY " cAAAAAA", "Background")
    rowY += 18

    gFgDrop := cg.AddDropDownList("x10 y" rowY " w120", colors)
    gFgPreview := cg.AddProgress("x135 y" rowY " w25 h24")
    cg.myFgDrop := gFgDrop

    gBgDrop := cg.AddDropDownList("x170 y" rowY " w120", colors)
    gBgPreview := cg.AddProgress("x295 y" rowY " w25 h24")
    cg.myBgDrop := gBgDrop

    rowY += 32

    gPreviewBox := cg.AddProgress("x10 y" rowY " w310 h80 Background2A2A2A")
    gPreviewLabel := cg.AddText("x10 y" rowY " w310 h80 0x200 Center -E0x200", "")

    rowY += 90

    cg.AddText("x10 y" rowY " cAAAAAA", "Results")
    rowY += 18

    gResultText := cg.AddText("x10 y" rowY " w310 cFFFFFF", "Ratio: --")
    rowY += 18

    gAaText := cg.AddText("x10 y" rowY " w310 cAAAAAA", "AA: --")
    rowY += 18

    gAaaText := cg.AddText("x10 y" rowY " w310 cAAAAAA", "AAA: --")
    rowY += 25

    cg.AddButton("x10 y" rowY " w310 h28", "Find Bad Contrast").OnEvent("Click", (*) => ShowBadContrast(cg))
    cg.AddButton("xm y" rowY+35 " w150 h28", "➕ Add to Palette").OnEvent("Click", (*) => AddContrastColors(cg))
    cg.AddButton("x170 y" rowY+35 " w150 h28", "✖ Close").OnEvent("Click", (*) => cg.Destroy())

    gFgDrop.Value := 1
    gBgDrop.Value := 2

    gFgDrop.OnEvent("Change", DoContrastUpdate.Bind(cg, gFgDrop, gBgDrop, gFgPreview, gBgPreview, gResultText, gAaText, gAaaText, gPreviewBox, gPreviewLabel))
    gBgDrop.OnEvent("Change", DoContrastUpdate.Bind(cg, gFgDrop, gBgDrop, gFgPreview, gBgPreview, gResultText, gAaText, gAaaText, gPreviewBox, gPreviewLabel))

    DoContrastUpdate(cg, gFgDrop, gBgDrop, gFgPreview, gBgPreview, gResultText, gAaText, gAaaText, gPreviewBox, gPreviewLabel, "")
    cg.Show("AutoSize Center")
}
DoContrastUpdate(cg, gFgDrop, gBgDrop, gFgPreview, gBgPreview, gResultText, gAaText, gAaaText, gPreviewBox, gPreviewLabel, *) {
    colors := cg.myColors

    fgIdx := gFgDrop.Value
    bgIdx := gBgDrop.Value

    if fgIdx = 0 || bgIdx = 0
        return

    fg := colors[fgIdx]
    bg := colors[bgIdx]

    fgHex := StrSplit(fg, "|")[1]
    fgName := StrSplit(fg, "|")[2]
    bgHex := StrSplit(bg, "|")[1]
    bgName := StrSplit(bg, "|")[2]

    gFgPreview.Opt("Background" fgHex)
    gBgPreview.Opt("Background" bgHex)

    ratio := GetContrastRatio(fgHex, bgHex)
    gResultText.Text := "Ratio: " ratio ":1"

    aa := ratio >= 4.5 ? "PASS" : "FAIL"
    aaa := ratio >= 7 ? "PASS" : "FAIL"

    gAaText.Text := "AA: " aa
    gAaaText.Text := "AAA: " aaa

    gPreviewBox.Opt("Background" bgHex)
    gPreviewBox.Value := 100

    fgLabel := fgName != "" ? fgName : "#" fgHex
    gPreviewLabel.Opt("c" fgHex " Background" bgHex)
    gPreviewLabel.Text := fgLabel
    gPreviewLabel.SetFont("s16 Bold", "Consolas")
}
AddContrastColors(cg) {
    app := cg.myApp
    colors := cg.myColors

    fgIdx := cg.myFgDrop.Value
    bgIdx := cg.myBgDrop.Value

    if fgIdx = 0 || bgIdx = 0 || fgIdx > colors.Length || bgIdx > colors.Length {
        ShowToast(app, "Select foreground and background colors")
        return
    }

    fg := colors[fgIdx]
    bg := colors[bgIdx]

    fgHex := StrSplit(fg, "|")[1]
    bgHex := StrSplit(bg, "|")[1]

    p := app.activePalette

    fgRgb := HexToRGB(fgHex)
    item := CreateItem(fgHex, fgRgb.r "," fgRgb.g "," fgRgb.b, "FG-" StrSplit(fg, "|")[2], "Foreground")
    item.section := "Contrast"
    AddColor(p, item)

    bgRgb := HexToRGB(bgHex)
    item := CreateItem(bgHex, bgRgb.r "," bgRgb.g "," bgRgb.b, "BG-" StrSplit(bg, "|")[2], "Background")
    item.section := "Contrast"
    AddColor(p, item)

    AddSectionName(p, "Contrast")

    Normalize(p)
    SavePalette(p, app.version)

    cg.Destroy()
    ShowToast(app, "Added contrast colors")

    RefreshPaletteManager(app, app.paletteGui)
    SwitchPalette(app, p.name)
}
FindBadContrastPairs(colors) {
    badPairs := []

    for i, fg in colors {
        fgHex := StrSplit(fg, "|")[1]

        for j, bg in colors {
            if (i = j)
                continue

            bgHex := StrSplit(bg, "|")[1]

            ratio := GetContrastRatio(fgHex, bgHex)

            if (ratio < 4.5) {
                badPairs.Push({
                    fg: fg,
                    bg: bg,
                    ratio: ratio
                })
            }
        }
    }
    return badPairs
}

ShowBadContrast(cg) {
    colors := cg.myColors
    app := cg.myApp

    bad := FindBadContrastPairs(colors)

    if bad.Length = 0 {
        ShowToast(app, "No bad contrast found")
        return
    }

    dlg := Gui("+AlwaysOnTop", "Bad Contrast Pairs")
    dlg.SetFont("s9", "Consolas")

    totalW := 400
    ratioW := 60
    padding := 20

    remaining := totalW - ratioW - padding
    each := Floor(remaining / 2)

    lv := dlg.AddListView("w" totalW " h300", ["FG", "BG", "Ratio"])

    lv.ModifyCol(1, each)
    lv.ModifyCol(2, each)
    lv.ModifyCol(3, ratioW)

    for pair in bad {
        fgName := StrSplit(pair.fg, "|")[2]
        bgName := StrSplit(pair.bg, "|")[2]
        lv.Add("", fgName, bgName, Round(pair.ratio, 2))
    }

    dlg.Show()
}


