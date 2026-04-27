ToHSV(r, g, b) {
    valR := r / 255
    valG := g / 255
    valB := b / 255

    maxVal := Max(valR, Max(valG, valB))
    minVal := Min(valR, Min(valG, valB))
    diff := maxVal - minVal

    v := maxVal

    if maxVal = 0
        s := 0
    else
        s := diff / maxVal

    if diff = 0
        h := 0
    else if maxVal = valR
        h := 60 * Mod((valG - valB) / diff, 6)
    else if maxVal = valG
        h := 60 * (((valB - valR) / diff) + 2)
    else
        h := 60 * (((valR - valG) / diff) + 4)

    if h < 0
        h += 360

    return {h: h, s: s, v: v}
}

FromHSV(h, s, v) {
    c := v * s
    x := c * (1 - Abs(Mod(h / 60, 2) - 1))
    m := v - c

    if h < 60
        r := c, g := x, b := 0
    else if h < 120
        r := x, g := c, b := 0
    else if h < 180
        r := 0, g := c, b := x
    else if h < 240
        r := 0, g := x, b := c
    else if h < 300
        r := x, g := 0, b := c
    else
        r := c, g := 0, b := x

    r := Round((r + m) * 255)
    g := Round((g + m) * 255)
    b := Round((b + m) * 255)

    return {r: r, g: g, b: b}
}

CalculateHarmony(hex, harmonyType) {
    r := Integer("0x" SubStr(hex, 1, 2))
    g := Integer("0x" SubStr(hex, 3, 2))
    b := Integer("0x" SubStr(hex, 5, 2))

    rgb := ToHSV(r, g, b)
    h := rgb.h
    s := rgb.s
    v := rgb.v

    baseRGB := {r: r, g: g, b: b}
    colors := []

    switch harmonyType {
        case "Complementary":
            colors := [baseRGB, FromHSV(Mod(h + 180, 360), s, v)]
        case "Analogous":
            colors := [baseRGB, FromHSV(Mod(h - 30, 360), s, v), FromHSV(Mod(h + 30, 360), s, v)]
        case "Triadic":
            colors := [baseRGB, FromHSV(Mod(h + 120, 360), s, v), FromHSV(Mod(h + 240, 360), s, v)]
        case "Split-Complementary":
            colors := [baseRGB, FromHSV(Mod(h + 150, 360), s, v), FromHSV(Mod(h + 210, 360), s, v)]
        case "Tetradic":
            colors := [baseRGB, FromHSV(Mod(h + 90, 360), s, v), FromHSV(Mod(h + 180, 360), s, v), FromHSV(Mod(h + 270, 360), s, v)]
    }

    result := []
    for rgb in colors {
        hex := Format("{:02X}{:02X}{:02X}", rgb.r, rgb.g, rgb.b)
        result.Push(hex)
    }

    return result
}

GenerateGradient(startHex, endHex, steps) {
    steps := Integer(Round(steps))
    if steps < 2
        steps := 2
    sr := Integer("0x" SubStr(startHex, 1, 2))
    sg := Integer("0x" SubStr(startHex, 3, 2))
    sb := Integer("0x" SubStr(startHex, 5, 2))

    er := Integer("0x" SubStr(endHex, 1, 2))
    eg := Integer("0x" SubStr(endHex, 3, 2))
    eb := Integer("0x" SubStr(endHex, 5, 2))

    gradient := []

    loop steps {
        t := (A_Index - 1) / (steps - 1)

        r := Round(sr + (er - sr) * t)
        g := Round(sg + (eg - sg) * t)
        b := Round(sb + (eb - sb) * t)

        gradient.Push(Format("{:02X}{:02X}{:02X}", r, g, b))
    }

    return gradient
}

SimulateColorBlindness(hex, cbType) {
    hex := StrReplace(hex, "#")
    if StrLen(hex) != 6
        return hex
    r := Integer("0x" SubStr(hex, 1, 2))
    g := Integer("0x" SubStr(hex, 3, 2))
    b := Integer("0x" SubStr(hex, 5, 2))

    switch cbType {
        case "Protanopia (Red-blind)":
            r2 := 0.567 * r + 0.433 * g
            g2 := 0.558 * r + 0.442 * g
            b2 := 0.242 * g + 0.758 * b
        case "Deuteranopia (Green-blind)":
            r2 := 0.625 * r + 0.375 * g
            g2 := 0.7 * r + 0.3 * g
            b2 := 0.3 * g + 0.7 * b
        case "Tritanopia (Blue-blind)":
            r2 := 0.95 * r + 0.05 * g
            g2 := 0.433 * g + 0.567 * b
            b2 := 0.475 * g + 0.525 * b
        case "Achromatopsia (Monochrome)":
            gray := 0.299 * r + 0.587 * g + 0.114 * b
            r2 := g2 := b2 := gray
        default:
            r2 := r, g2 := g, b2 := b
    }

    r2 := Max(0, Min(255, Round(r2)))
    g2 := Max(0, Min(255, Round(g2)))
    b2 := Max(0, Min(255, Round(b2)))

    return Format("{:02X}{:02X}{:02X}", r2, g2, b2)
}

GetContrastRatio(fgHex, bgHex) {
    fgHex := StrReplace(fgHex, "#")
    bgHex := StrReplace(bgHex, "#")
    fgR := Integer("0x" SubStr(fgHex, 1, 2))
    fgG := Integer("0x" SubStr(fgHex, 3, 2))
    fgB := Integer("0x" SubStr(fgHex, 5, 2))

    bgR := Integer("0x" SubStr(bgHex, 1, 2))
    bgG := Integer("0x" SubStr(bgHex, 3, 2))
    bgB := Integer("0x" SubStr(bgHex, 5, 2))

    fgL := RelativeLuminance(fgR, fgG, fgB)
    bgL := RelativeLuminance(bgR, bgG, bgB)

    L1 := Max(fgL, bgL)
    L2 := Min(fgL, bgL)

    return Round((L1 + 0.05) / (L2 + 0.05), 2)
}

RelativeLuminance(r, g, b) {
    r := r / 255
    g := g / 255
    b := b / 255
    r := r <= 0.03928 ? r / 12.92 : ((r + 0.055) / 1.055) ** 2.4
    g := g <= 0.03928 ? g / 12.92 : ((g + 0.055) / 1.055) ** 2.4
    b := b <= 0.03928 ? b / 12.92 : ((b + 0.055) / 1.055) ** 2.4
    return 0.2126 * r + 0.7152 * g + 0.0722 * b
}
