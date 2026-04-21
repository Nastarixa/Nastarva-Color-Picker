#Requires AutoHotkey v2.0

GetColorName(hexColor) {
    hexColor := NormalizeHex(hexColor)

    static colorMap := BuildColorMap()

    if colorMap.Has(hexColor)
        return colorMap[hexColor]

    nearest := FindNearestColor(hexColor, colorMap)
    if nearest != ""
        return nearest

    return GetFallbackColorName(hexColor)
}
NormalizeHex(hex) {
    hex := RegExReplace(hex, "[^0-9A-Fa-f]")
    hex := StrUpper(hex)

    if (StrLen(hex) != 6)
        return ""

    return hex
}

FindNearestColor(hex, map) {
    rgb := HexToRGB(hex)
    if !IsObject(rgb)
        return ""

    bestName := ""
    bestDist := 999999

    for key, name in map {
        c := HexToRGB(key)
        if !IsObject(c)
            continue

        dist :=
            (rgb.r - c.r) ** 2 +
            (rgb.g - c.g) ** 2 +
            (rgb.b - c.b) ** 2

        if (dist < bestDist) {
            bestDist := dist
            bestName := name
        }
    }

    return (bestDist < 8000) ? bestName : ""
}

GetFallbackColorName(hex) {
    rgb := HexToRGB(hex)
    if !IsObject(rgb)
        return "Unknown"

    if (rgb.r > 200 && rgb.g < 120 && rgb.b < 120)
        return "Red Tone"

    if (rgb.g > 200 && rgb.r < 120)
        return "Green Tone"

    if (rgb.b > 200 && rgb.r < 120)
        return "Blue Tone"

    if (Abs(rgb.r - rgb.g) < 20 && Abs(rgb.g - rgb.b) < 20)
        return "Neutral Gray"

    return "Custom Color"
}

BuildColorMap() {
    static maps := Map()
    static initialized := false

    if (initialized)
        return maps

    initialized := true

    ; ================= FULL COLOR DATABASE =================
        maps["000000"] := "Black"
    maps["000080"] := "Navy"
    maps["00008B"] := "DarkBlue"
    maps["0000CD"] := "MediumBlue"
    maps["0000FF"] := "Blue"
    maps["006400"] := "DarkGreen"
    maps["008000"] := "Green"
    maps["008080"] := "Teal"
    maps["008B8B"] := "DarkCyan"
    maps["00BFFF"] := "DeepSkyBlue"
    maps["00CED1"] := "DarkTurquoise"
    maps["00FA9A"] := "MediumSpringGreen"
    maps["00FF00"] := "Lime"
    maps["00FF7F"] := "SpringGreen"
    maps["00FFFF"] := "Cyan"

    maps["191970"] := "MidnightBlue"
    maps["1E90FF"] := "DodgerBlue"
    maps["20B2AA"] := "LightSeaGreen"
    maps["228B22"] := "ForestGreen"
    maps["2E8B57"] := "SeaGreen"
    maps["2F4F4F"] := "DarkSlateGray"
    maps["32CD32"] := "LimeGreen"
    maps["3CB371"] := "MediumSeaGreen"

    maps["40E0D0"] := "Turquoise"
    maps["4169E1"] := "RoyalBlue"
    maps["4682B4"] := "SteelBlue"
    maps["483D8B"] := "DarkSlateBlue"
    maps["48D1CC"] := "MediumTurquoise"
    maps["4B0082"] := "Indigo"
    maps["556B2F"] := "DarkOliveGreen"
    maps["5F9EA0"] := "CadetBlue"

    maps["6495ED"] := "CornflowerBlue"
    maps["663399"] := "RebeccaPurple"
    maps["66CDAA"] := "MediumAquaMarine"
    maps["696969"] := "DimGray"
    maps["6A5ACD"] := "SlateBlue"
    maps["6B8E23"] := "OliveDrab"
    maps["708090"] := "SlateGray"
    maps["778899"] := "LightSlateGray"

    maps["7B68EE"] := "MediumSlateBlue"
    maps["7CFC00"] := "LawnGreen"
    maps["7FFF00"] := "Chartreuse"
    maps["7FFFD4"] := "Aquamarine"

    maps["800000"] := "Maroon"
    maps["800080"] := "Purple"
    maps["808000"] := "Olive"
    maps["808080"] := "Gray"

    maps["87CEEB"] := "SkyBlue"
    maps["87CEFA"] := "LightSkyBlue"
    maps["8A2BE2"] := "BlueViolet"
    maps["8B0000"] := "DarkRed"
    maps["8B008B"] := "DarkMagenta"
    maps["8B4513"] := "SaddleBrown"
    maps["8FBC8F"] := "DarkSeaGreen"

    maps["90EE90"] := "LightGreen"
    maps["9370DB"] := "MediumPurple"
    maps["9400D3"] := "DarkViolet"
    maps["98FB98"] := "PaleGreen"
    maps["9932CC"] := "DarkOrchid"
    maps["9ACD32"] := "YellowGreen"

    maps["A0522D"] := "Sienna"
    maps["A52A2A"] := "Brown"
    maps["A9A9A9"] := "DarkGray"

    maps["ADD8E6"] := "LightBlue"
    maps["ADFF2F"] := "GreenYellow"
    maps["AFEEEE"] := "PaleTurquoise"

    maps["B0C4DE"] := "LightSteelBlue"
    maps["B0E0E6"] := "PowderBlue"
    maps["B22222"] := "FireBrick"
    maps["B8860B"] := "DarkGoldenRod"
    maps["BA55D3"] := "MediumOrchid"
    maps["BC8F8F"] := "RosyBrown"
    maps["BDB76B"] := "DarkKhaki"

    maps["C0C0C0"] := "Silver"
    maps["C71585"] := "MediumVioletRed"

    maps["CD5C5C"] := "IndianRed"
    maps["CD853F"] := "Peru"

    maps["D2691E"] := "Chocolate"
    maps["D2B48C"] := "Tan"
    maps["D3D3D3"] := "LightGray"
    maps["D8BFD8"] := "Thistle"
    maps["DA70D6"] := "Orchid"
    maps["DAA520"] := "GoldenRod"
    maps["DB7093"] := "PaleVioletRed"

    maps["DC143C"] := "Crimson"
    maps["DCDCDC"] := "Gainsboro"
    maps["DDA0DD"] := "Plum"
    maps["DEB887"] := "BurlyWood"

    maps["E0FFFF"] := "LightCyan"
    maps["E6E6FA"] := "Lavender"
    maps["E9967A"] := "DarkSalmon"

    maps["EE82EE"] := "Violet"
    maps["EEE8AA"] := "PaleGoldenRod"

    maps["F08080"] := "LightCoral"
    maps["F0E68C"] := "Khaki"
    maps["F0F8FF"] := "AliceBlue"
    maps["F0FFF0"] := "HoneyDew"
    maps["F0FFFF"] := "Azure"

    maps["F4A460"] := "SandyBrown"
    maps["F5DEB3"] := "Wheat"
    maps["F5F5DC"] := "Beige"
    maps["F5F5F5"] := "WhiteSmoke"
    maps["F5FFFA"] := "MintCream"

    maps["F8F8FF"] := "GhostWhite"

    maps["FA8072"] := "Salmon"
    maps["FAEBD7"] := "AntiqueWhite"
    maps["FAF0E6"] := "Linen"
    maps["FAFAD2"] := "LightGoldenRodYellow"

    maps["FF0000"] := "Red"
    maps["FF00FF"] := "Magenta"
    maps["FF1493"] := "DeepPink"
    maps["FF4500"] := "OrangeRed"
    maps["FF6347"] := "Tomato"
    maps["FF69B4"] := "HotPink"
    maps["FF7F50"] := "Coral"
    maps["FF8C00"] := "DarkOrange"
    maps["FFA07A"] := "LightSalmon"
    maps["FFA500"] := "Orange"

    maps["FFB6C1"] := "LightPink"
    maps["FFC0CB"] := "Pink"
    maps["FFD700"] := "Gold"
    maps["FFDAB9"] := "PeachPuff"
    maps["FFDEAD"] := "NavajoWhite"

    maps["FFE4B5"] := "Moccasin"
    maps["FFE4C4"] := "Bisque"
    maps["FFE4E1"] := "MistyRose"
    maps["FFEBCD"] := "BlanchedAlmond"
    maps["FFEFD5"] := "PapayaWhip"
    maps["FFF0F5"] := "LavenderBlush"
    maps["FFF5EE"] := "SeaShell"
    maps["FFF8DC"] := "Cornsilk"
    maps["FFFACD"] := "LemonChiffon"

    maps["FFFAF0"] := "FloralWhite"
    maps["FFFAFA"] := "Snow"

    maps["FFFF00"] := "Yellow"
    maps["FFFFE0"] := "LightYellow"
    maps["FFFFF0"] := "Ivory"
    maps["FFFFFF"] := "White"

    return maps
}

