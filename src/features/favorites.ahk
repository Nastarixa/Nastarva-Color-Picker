LoadFavorites(app) {
    favPath := A_ScriptDir "\color\favorites.txt"
    app.favorites := []
    
    if !FileExist(favPath)
        return
    
    for line in StrSplit(FileRead(favPath, "UTF-8"), "`n", "`r") {
        line := Trim(line)
        if (line = "" || SubStr(line, 1, 1) = ";")
            continue
        
        parts := StrSplit(line, "|")
        if parts.Length >= 3 {
            hex := Trim(parts[1])
            rgb := Trim(parts[2])
            name := Trim(parts[3])
            role := parts.Length >= 4 ? Trim(parts[4]) : "Favorite"
            tag := parts.Length >= 5 ? Trim(parts[5]) : ""
            app.favorites.Push({ hex: hex, rgb: rgb, name: name, role: role, tag: tag })
        }
    }
}

SaveFavorites(app) {
    favPath := A_ScriptDir "\color\favorites.txt"
    lines := []
    lines.Push("; Nastarva Favorite Colors")
    lines.Push("; Format: HEX|RGB|Name|Role|Tag")
    
    for fav in app.favorites {
        lines.Push(fav.hex "|" fav.rgb "|" fav.name "|" fav.role "|" fav.tag)
    }
    
    if FileExist(favPath)
        FileDelete(favPath)
    FileAppend(JoinFavLines(lines), favPath, "UTF-8")
}

JoinFavLines(lines) {
    text := ""
    for i, line in lines
        text .= line (i < lines.Length ? "`r`n" : "")
    return text
}

AddFavoriteColor(app, hex, rgb, name, role, tag := "") {
    for fav in app.favorites {
        if (fav.hex = hex)
            return false
    }
    
    app.favorites.Push({ hex: hex, rgb: rgb, name: name, role: role, tag: tag })
    SaveFavorites(app)
    return true
}

RemoveFavoriteColor(app, hex) {
    for i, fav in app.favorites {
        if (fav.hex = hex) {
            app.favorites.RemoveAt(i)
            SaveFavorites(app)
            return true
        }
    }
    return false
}

IsFavoriteColor(app, hex) {
    for fav in app.favorites {
        if (fav.hex = hex)
            return true
    }
    return false
}

ShowFavoritesWindow(app) {
    if app.HasOwnProp("favoritesGui") && SafeGetGuiHwnd(app.favoritesGui) {
        app.favoritesGui.Show()
        return
    }

    g := Gui("+AlwaysOnTop +ToolWindow", "⭐ Favorite Colors")
    g.BackColor := "323338"
    g.SetFont("s9", "Consolas")

    g.AddText("xm y+5 cFFFFFF", "Your saved favorite colors:")
    g.favList := g.AddListView("xm w420 h250 -Multi", ["HEX", "RGB", "Name", "Role", "Palette"])
    totalW := 420
    hexW := 70
    remaining := totalW - hexW - 20
    each := Floor(remaining / 4)
    g.favList.ModifyCol(1, hexW)
    Loop 4
        g.favList.ModifyCol(A_Index + 1, each)

    g.favColorMap := Map()
    idx := 0
    for fav in app.favorites {
        idx++
        paletteHint := fav.tag != "" ? fav.tag : ""
        g.favList.Add("", "#" fav.hex, fav.rgb, fav.name, fav.role, paletteHint)
        g.favColorMap[idx] := fav
    }

    if idx > 0 {
        g.favList.Modify(1, "Select Focus")
    }

    g.AddButton("xm y+5 w105 h24", "📋 Copy HEX")
        .OnEvent("Click", (*) => FavCopyHex(app, g))
    g.AddButton("x+5 w105 h24", "📋 Copy RGB")
        .OnEvent("Click", (*) => FavCopyRGB(app, g))
    g.AddButton("x+5 w105 h24", "➕ Add to Section")
        .OnEvent("Click", (*) => FavAddToSection(app, g))
    g.AddButton("x+5 w105 h24", "🗑 Remove")
        .OnEvent("Click", (*) => FavRemove(app, g))

    g.AddButton("xm y+5 w420 h24", "❌ Close")
        .OnEvent("Click", (*) => g.Destroy())

    g.Show("AutoSize Center")
    app.favoritesGui := g
}

FavCopyHex(app, g) {
    sel := g.favList.GetNext()
    if !sel || !g.favColorMap.Has(sel)
        return
    fav := g.favColorMap[sel]
    A_Clipboard := fav.hex
    ShowToast(app, "✔ Copied #" fav.hex)
}

FavCopyRGB(app, g) {
    sel := g.favList.GetNext()
    if !sel || !g.favColorMap.Has(sel)
        return
    fav := g.favColorMap[sel]
    A_Clipboard := fav.rgb
    ShowToast(app, "✔ Copied " fav.rgb)
}

FavAddToSection(app, g) {
    sel := g.favList.GetNext()
    if !sel || !g.favColorMap.Has(sel)
        return
    fav := g.favColorMap[sel]
    
    targetSection := GetSelectedSectionName(app.activePalette)
    
    item := GetItemByHex(app, fav.hex)
    if item {
        MoveColorToSection(app, GetItemToken(item), targetSection)
        ShowToast(app, "➕ Added #" fav.hex " to " targetSection)
    } else {
        newItem := CreateItem(fav.hex, fav.rgb, fav.name, fav.role)
        newItem.section := targetSection
        newItem.isSaved := true
        Mutate(app, (p) => (
            AddSectionName(p, targetSection),
            AddColor(p, newItem)
        ))
        SaveHistory(app)
        if app.historyVisible {
            Emit(app, "history_changed")
        }
        app.ui.generation++
        RebuildUI(app)
        ShowToast(app, "➕ Added #" fav.hex " to " targetSection)
    }
}

FavRemove(app, g) {
    sel := g.favList.GetNext()
    if !sel || !g.favColorMap.Has(sel)
        return
    fav := g.favColorMap[sel]
    
    if WaitConfirmDialog(app, "Remove #" fav.hex " from favorites?", "Remove Favorite") {
        RemoveFavoriteColor(app, fav.hex)
        g.Destroy()
        ShowFavoritesWindow(app)
    }
}

WaitConfirmDialog(app, message, title) {
    confirmed := false
    
    g := Gui("+AlwaysOnTop -Caption +ToolWindow +Border", title)
    g.BackColor := "323338"
    g.SetFont("s9", "Consolas")
    g.MarginX := 16
    
    g.AddText("cFFFFFF w280", message)
    btnOk := g.AddButton("w130 h28 y+10", "OK")
    btnCancel := g.AddButton("w130 h28 x+10", "Cancel")
    btnOk.OnEvent("Click", (*) => (confirmed := true, g.Destroy()))
    btnCancel.OnEvent("Click", (*) => g.Destroy())
    
    g.OnEvent("Close", (*) => g.Destroy())
    
    g.Show("AutoSize Center")
    
    while SafeGetGuiHwnd(g) {
        Sleep 50
    }
    
    return confirmed
}

ToggleFavoriteFromPin(app, token) {
    if SafeGetGuiHwnd(app.pinMenuGui)
        app.pinMenuGui.Hide()

    item := GetItemByToken(app, token)
    if !item
        return
    
    if IsFavoriteColor(app, item.hex) {
        RemoveFavoriteColor(app, item.hex)
        ShowToast(app, "⭐ Removed #" item.hex " from favorites")
    } else {
        paletteName := app.activePalette.name
        AddFavoriteColor(app, item.hex, item.rgb, item.name, item.role, paletteName)
        ShowToast(app, "⭐ Added #" item.hex " to favorites")
    }
}