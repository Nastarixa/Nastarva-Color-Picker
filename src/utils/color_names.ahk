#Requires AutoHotkey v2.0

GetColorName(hexColor) {
    hexColor := NormalizeHex(hexColor)

    static colorMap := BuildColorMap()

    ; =========================
    ; 1. EXACT MATCH (priority)
    ; =========================
    if colorMap.Has(hexColor) {
        return NormalizeColorName(colorMap[hexColor])
    }

    ; =========================
    ; 2. SMART FALLBACK
    ; =========================
    smart := GetSmartColorName(hexColor)
    if (smart != "")
        return smart

    ; =========================
    ; 3. FINAL FALLBACK
    ; =========================
    return "Custom Color"
}
NormalizeHex(hex) {
    hex := RegExReplace(hex, "[^0-9A-Fa-f]")
    hex := StrUpper(hex)

    if (StrLen(hex) != 6)
        return ""

    return hex
}
NormalizeColorName(name) {
    name := RegExReplace(name, "([a-z])([A-Z])", "$1 $2") ; RichBlack → Rich Black
    name := RegExReplace(name, "\b([a-z])", "$U1")        ; force capitalization style
    name := RegExReplace(name, "\s+", " ")
    return Trim(name)
}
GetSmartColorName(hex) {
    rgb := HexToRGB(hex)
    if !IsObject(rgb)
        return ""

    hsl := RGBtoHSL(rgb.r, rgb.g, rgb.b)

    tone := GetBrightnessName(hsl.l)
    sat  := GetSaturationName(hsl.s)
    hue  := GetHueName(hsl.h, hsl.s)

    return NormalizeColorName(tone " " sat " " hue)
}
RGBtoHSL(r, g, b) {
    r /= 255, g /= 255, b /= 255

    maxVal := Max(r, g, b)
    minVal := Min(r, g, b)
    l := (maxVal + minVal) / 2

    if (maxVal = minVal) {
        h := 0
        s := 0
    } else {
        d := maxVal - minVal
        s := l > 0.5 ? d / (2 - maxVal - minVal) : d / (maxVal + minVal)

        if (maxVal = r)
            h := (g - b) / d + (g < b ? 6 : 0)
        else if (maxVal = g)
            h := (b - r) / d + 2
        else
            h := (r - g) / d + 4

        h /= 6
    }

    return { h: h * 360, s: s * 100, l: l * 100 }
}
GetBrightnessName(l) {
    if (l < 20)
        return "Dark"
    if (l < 40)
        return "Deep"
    if (l < 65)
        return ""          ; neutral
    if (l < 85)
        return "Light"
    return "Bright"
}
GetSaturationName(s) {
    if (s < 15)
        return "Gray"
    if (s < 35)
        return "Muted"
    if (s < 65)
        return "Soft"
    return "Vivid"
}
GetHueName(h, s) {
    ; if very low saturation → grayscale
    if (s < 10)
        return "Gray"

    if (h < 15)
        return "Red"
    if (h < 45)
        return "Orange"
    if (h < 65)
        return "Yellow"
    if (h < 150)
        return "Green"
    if (h < 210)
        return "Cyan"
    if (h < 260)
        return "Blue"
    if (h < 290)
        return "Purple"
    if (h < 330)
        return "Magenta"

    return "Red"
}
BuildColorMap() {
    static maps := Map()
    static initialized := false

    if (initialized)
        return maps

    initialized := true

    ; =========================================================
    ; CORE COLORS
    ; =========================================================
    maps["000000"] := "Black"
    maps["FFFFFF"] := "White"
    maps["808080"] := "Gray"
    maps["C0C0C0"] := "Silver"

    ; =========================================================
    ; BLUES
    ; =========================================================
    maps["000080"] := "Navy"
    maps["00008B"] := "Dark Blue"
    maps["0000CD"] := "Medium Blue"
    maps["0000FF"] := "Blue"
    maps["191970"] := "Midnight Blue"
    maps["1E90FF"] := "Dodger Blue"
    maps["4169E1"] := "Royal Blue"
    maps["4682B4"] := "Steel Blue"
    maps["6495ED"] := "Cornflower Blue"
    maps["87CEEB"] := "Sky Blue"
    maps["87CEFA"] := "Light Sky Blue"

    ; --- Extended ---
    maps["001F3F"] := "Navy Deep"
    maps["003366"] := "Oxford Blue"
    maps["0047AB"] := "Cobalt"
    maps["007FFF"] := "Azure Blue"
    maps["3399FF"] := "Bright Blue"
    maps["66B2FF"] := "Soft Blue"
    maps["CCE6FF"] := "Ice Blue"

    ; =========================================================
    ; GREENS
    ; =========================================================
    maps["006400"] := "Dark Green"
    maps["008000"] := "Green"
    maps["00FF00"] := "Lime"
    maps["228B22"] := "Forest Green"
    maps["2E8B57"] := "Sea Green"
    maps["32CD32"] := "Lime Green"
    maps["3CB371"] := "Medium Sea Green"
    maps["90EE90"] := "Light Green"

    ; --- Extended ---
    maps["013220"] := "Deep Forest"
    maps["016936"] := "Jungle Green"
    maps["2ECC71"] := "Emerald"
    maps["4CAF50"] := "Material Green"
    maps["66FF66"] := "Neon Green"
    maps["CCFFCC"] := "Pale Mint"

    ; =========================================================
    ; REDS
    ; =========================================================
    maps["800000"] := "Maroon"
    maps["8B0000"] := "Dark Red"
    maps["DC143C"] := "Crimson"
    maps["FF0000"] := "Red"
    maps["FF4500"] := "Orange Red"
    maps["FF6347"] := "Tomato"

    ; --- Extended ---
    maps["660000"] := "Deep Red"
    maps["7A0000"] := "Blood Red"
    maps["990000"] := "Strong Red"
    maps["FF4D4D"] := "Soft Red"
    maps["FF8080"] := "Light Red"

    ; =========================================================
    ; YELLOW / ORANGE
    ; =========================================================
    maps["FFA500"] := "Orange"
    maps["FF8C00"] := "Dark Orange"
    maps["FFD700"] := "Gold"
    maps["FFFF00"] := "Yellow"

    ; --- Extended ---
    maps["CC5500"] := "Burnt Orange"
    maps["E67300"] := "Strong Orange"
    maps["FFB266"] := "Peach Orange"
    maps["FFFF66"] := "Soft Yellow"
    maps["FFFFCC"] := "Pale Yellow"

    ; =========================================================
    ; PURPLE / PINK
    ; =========================================================
    maps["800080"] := "Purple"
    maps["8A2BE2"] := "Blue Violet"
    maps["9370DB"] := "Medium Purple"
    maps["DA70D6"] := "Orchid"
    maps["FF00FF"] := "Magenta"
    maps["FF69B4"] := "Hot Pink"

    ; --- Extended ---
    maps["2E003E"] := "Deep Purple"
    maps["6A0DAD"] := "True Purple"
    maps["B266FF"] := "Light Purple"
    maps["FF99CC"] := "Soft Pink"
    maps["FFD6EB"] := "Pale Rose"

    ; =========================================================
    ; BROWNS / EARTH
    ; =========================================================
    maps["8B4513"] := "Saddle Brown"
    maps["A0522D"] := "Sienna"
    maps["A52A2A"] := "Brown"
    maps["D2B48C"] := "Tan"
    maps["DEB887"] := "Burly Wood"

    ; --- Extended ---
    maps["3E2723"] := "Dark Brown"
    maps["4E342E"] := "Coffee"
    maps["6D4C41"] := "Earth Brown"
    maps["A1887F"] := "Dust Brown"
    maps["BCAAA4"] := "Sand Brown"

    ; =========================================================
    ; GRAYS / NEUTRALS
    ; =========================================================
    maps["2F4F4F"] := "Dark Slate Gray"
    maps["696969"] := "Dim Gray"
    maps["708090"] := "Slate Gray"
    maps["778899"] := "Light Slate Gray"
    maps["A9A9A9"] := "Dark Gray"
    maps["D3D3D3"] := "Light Gray"

    ; --- Extended ---
    maps["0A0A0A"] := "Rich Black"
    maps["1A1A1A"] := "Jet Black"
    maps["333333"] := "Dark Charcoal"
    maps["555555"] := "Granite"
    maps["888888"] := "Cool Gray"
    maps["CCCCCC"] := "Soft Gray"
    maps["F2F2F2"] := "Snow Gray"

    ; =========================================================
    ; CYAN / AQUA
    ; =========================================================
    maps["00FFFF"] := "Cyan"
    maps["00CED1"] := "Dark Turquoise"
    maps["40E0D0"] := "Turquoise"
    maps["48D1CC"] := "Medium Turquoise"
    maps["7FFFD4"] := "Aquamarine"
    maps["E0FFFF"] := "Light Cyan"

    ; =========================================================
    ; UI / DESIGN COLORS
    ; =========================================================
    maps["1E1E2F"] := "Dark UI Blue"
    maps["2A2A3D"] := "Panel Background"
    maps["3A3A4F"] := "UI Hover"
    maps["505070"] := "UI Border"

    maps["F1F3F4"] := "Surface Light"
    maps["202124"] := "Surface Dark"
    maps["E8F0FE"] := "Light UI Blue"

    return maps
}

