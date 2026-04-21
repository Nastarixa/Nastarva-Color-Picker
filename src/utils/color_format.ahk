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

    if (mode = "compact")
        return item.hex " | " rgb " | " role " " GetRoleIcon(role)

    return (
        "HEX: #" item.hex "`n"
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
        if (StrLen(role) > StrLen(knownRole) && SubStr(role, -StrLen(knownRole) + 1) = knownRole)
            return knownRole
    }

    return role
}

GetRoleIcon(role) {
    role := NormalizeRoleName(role)
    if RegExMatch(role, "^(\\d+)\\s*(.*)$", &m) {
        num := m[1]
        name := Trim(m[2])

        return GetNumberRoleIcon(num) " " name
    }
    switch role {
        default: return ""
    }
}
GetNumberRoleIcon(num) {
    switch num {
        case "1": return "①"
        case "2": return "②"
        case "3": return "③"
        case "4": return "④"
        case "5": return "⑤"
        case "6": return "⑥"
        case "7": return "⑦"
        case "8": return "⑧"
        case "9": return "⑨"
        default:  return "#" num
    }
}
GetRoleButtonLabel(role) {
    role := NormalizeRoleName(role)
    return GetRoleIcon(role) " " role
}
