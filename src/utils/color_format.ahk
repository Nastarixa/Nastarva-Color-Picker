HexToRGB(hex) {
    return {
        r: Integer("0x" SubStr(hex, 1, 2)),
        g: Integer("0x" SubStr(hex, 3, 2)),
        b: Integer("0x" SubStr(hex, 5, 2))
    }
}

GetRGBFromHex(hex) {
    rgb := HexToRGB(hex)
    return rgb.r "," rgb.g "," rgb.b
}

FormatColor(value, type) {
    return { value: value, type: type }
}

FormatColorInfo(item, mode := "full") {
    rgb := item.rgb
    role := NormalizeRoleName(item.role)
    section := item.HasOwnProp("section") ? item.section : "Default"
    name := item.HasOwnProp("name") ? Trim(item.name) : ""
    if (name = "")
        name := item.hex

    if (mode = "compact") {
        icon := GetRoleIcon(role)
        return rgb " | " role (icon != "" ? " [" icon "]" : "" item.hex " | " )
    }

    return (
        "HEX: #" item.hex "`n"
        "NAME: " name "`n"
        "RGB: " rgb "`n"
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
        case "Base": return "⚫"
        case "Highlight": return "✨"
        case "Shadow": return "⬛"
        case "Hi Shadow": return "♻️"
        case "2 Shadow": return "💞"
        default: return ""
    }
}

GetRoleButtonLabel(role) {
    role := NormalizeRoleName(role)
    icon := GetRoleIcon(role)
    return (icon != "" ? "[" icon "] " : "") role
}
