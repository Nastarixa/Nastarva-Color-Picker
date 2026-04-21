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

    section := item.HasOwnProp("section") ? item.section : "Default"

    if (mode = "compact")
        return item.hex " | " rgb " | " item.role " " GetRoleIcon(item.role)

    return (
        "HEX: #" item.hex "`n"
        "RGB: " rgb "`n"
        "ROLE: " item.role "`n"
        "SECTION: " section
    )
}

GetRoleIcon(role) {
    switch role {
        case "Base":       return "⚫"
        case "Highlight":  return "✨"
        case "Shadow":     return "⬛"
        case "2 Shadow":   return "♻️"
        case "Hi Shadow":  return "💞"
        default: return "•"
    }
}
