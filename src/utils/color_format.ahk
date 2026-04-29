HexToRGB(hex) {
    if !IsObject(hex) && (hex = "" || StrLen(hex) != 6)
        return { r: 0, g: 0, b: 0 }

    try {
        return {
            r: Integer("0x" SubStr(hex, 1, 2)),
            g: Integer("0x" SubStr(hex, 3, 2)),
            b: Integer("0x" SubStr(hex, 5, 2))
        }
    }
    return { r: 0, g: 0, b: 0 }
}

GetRGBFromHex(hex) {
    if !IsObject(hex) && (hex = "" || StrLen(hex) != 6)
        return "0,0,0"

    rgb := HexToRGB(hex)
    return rgb.r "," rgb.g "," rgb.b
}

FormatColor(value, type) {
    return { value: value, type: type }
}

FormatColorInfo(item, mode := "full", app := 0) {
    fullCompact := IsObject(app) && app.HasOwnProp("fullCompactMode") && app.fullCompactMode
    if fullCompact
        return ""

    rgb := item.rgb
    role := NormalizeRoleName(item.role)
    section := item.HasOwnProp("section") ? item.section : "Default"
    name := item.HasOwnProp("name") ? Trim(item.name) : ""
    if (name = "")
        name := item.hex

    displayMode := IsObject(app) && app.HasOwnProp("displayMode") ? app.displayMode : "hex"
    primaryValue := displayMode = "rgb" ? rgb : "#" item.hex
    secondaryValue := displayMode = "rgb" ? item.hex : rgb

    compact := IsObject(app) && app.HasOwnProp("compactMode") && app.compactMode

    if (mode = "compact") {
        if compact
            return primaryValue
        icon := GetRoleIcon(role)
        return primaryValue " | " role (icon != "" ? " [" icon "]" : "")
    }

    if compact
        return primaryValue

    return (
        "PRIMARY: " primaryValue "`n"
        "SECONDARY: " secondaryValue "`n"
        "NAME: " name "`n"
        "ROLE: " role "`n"
        "SECTION: " section
    )
}

NormalizeRoleName(role) {
    role := Trim(role)
    if (role = "")
        return "Base"

    knownRoles := DefaultRoleOrder()

    for _, knownRole in knownRoles {
        if (role = knownRole)
            return knownRole
    }

    return role
}

GetRoleIcon(role) {
    role := NormalizeRoleName(role)
    switch role {
        case "Base": return "⬤"
        case "Highlight": return "✦"
        case "Shadow": return "▰"
        case "Hi Shadow": return "▼"
        case "2 Shadow": return "▣"
        case "Mask": return "░"
        case "Outline": return "◇"
        case "Black": return "⎕"
        default: return ""
    }
}

GetRoleButtonLabel(role) {
    role := NormalizeRoleName(role)
    icon := GetRoleIcon(role)
    return (icon != "" ? "[" icon "] " : "") role
}
