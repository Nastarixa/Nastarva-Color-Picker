BatchRoleClick(app, role, ids) {
    for _, id in ids {
        item := GetItemById(app, id)
        if !item
            continue
        ApplyRoleMutationByHex(app.activePalette, role, item.hex)
    }
    Commit(app)

    CloseRoleMenu(app)

    for _, id in ids {
        RefreshSectionByItemId(app, id)
    }
    ShowToast(app, "Set " ids.Length " color(s) to " role)
}

BatchRoleBtnClick(btn, *) {
    global App
    app := App
    role := btn.role
    if SafeGetGuiHwnd(app.roleMenuGui) {
        targetIds := []
        for token, ctrl in app.ui.controls {
            if ctrl.selected {
                item := GetItemByToken(app, token)
                if item && item.HasOwnProp("id") {
                    targetIds.Push(item.id)
                }
            }
        }
        if targetIds.Length > 0 {
            BatchRoleClick(app, role, targetIds)
        }
    }
}

ApplyRoleMutationByHex(p, role, hex) {
    for item in p.colors {
        if (item.hex = hex) {
            item.role := role
            break
        }
    }
}

ApplyRoleMutationById(p, role, itemId) {
    for item in p.colors {
        if item.HasOwnProp("id") && item.id = itemId {
            item.role := role
            break
        }
    }
}

OpenRoleMenu(app, token) {
    targetIds := GetSelectedIds(app, token)

    item := GetItemById(app, targetIds[1])
    if !item
        return

    app.activePalette.selectedHex := item.hex
    app.activePalette.highlightToken := token

    DoHighlight(app, token)

    OpenRoleSubMenu(app, token, targetIds)
}

OpenRoleSubMenu(app, token, targetIds) {

    g := Gui("+AlwaysOnTop -Caption +ToolWindow")
    g.BackColor := "323338"
    g.SetFont("s9", "Consolas")
    g.MarginX := 8
    g.MarginY := 8

    label := (targetIds.Length > 1)
        ? "Set Role (" targetIds.Length " colors):"
        : "Set Role:"
    g.AddText("cFFFFFF", label)

    g.SetFont("s7", "Consolas")
    g.AddText("cAAAAAA", "Arrow Up/Down to change, Enter to confirm")

    g.SetFont("s9", "Consolas")
    roles := DefaultRoleOrder()

    if targetIds.Length = 1 {
        item := GetItemById(app, targetIds[1])
        hex := item ? item.hex : ""
        itemId := item ? item.id : ""
        currentRole := item ? NormalizeRoleName(item.role) : "Base"
        currentIdx := 1
        for i, r in roles {
            if NormalizeRoleName(r) = currentRole {
                currentIdx := i
                break
            }
        }
    } else {
        currentIdx := 1
    }

    g.currentIdx := currentIdx
    g.app := app
    g.token := token
    g.hex := hex
    g.itemId := itemId
    g.targetIds := targetIds
    g.roles := roles

    for r in roles {
        role := NormalizeRoleName(r)
        btn := g.AddButton("w160", GetRoleButtonLabel(role))
        btn.role := role
        if targetIds.Length = 1 {
            btn.OnEvent("Click", RoleBtnClick.Bind(app, role, token, hex))
        } else {
            btn.targetIds := targetIds
            btn.OnEvent("Click", BatchRoleBtnClickFromMenu.Bind(app, role, targetIds))
        }
    }

    g.upBtn := g.AddButton("w77", "▲ Up")
    g.upBtn.OnEvent("Click", (*) => RoleMenuChangeRole(app, g, -1))
    g.downBtn := g.AddButton("w77 x+6", "▼ Down")
    g.downBtn.OnEvent("Click", (*) => RoleMenuChangeRole(app, g, 1))

    cancelBtn := g.AddButton("w160", "Cancel")
    cancelBtn.OnEvent("Click", (*) => CloseRoleMenu(app))

    g.OnEvent("Escape", (*) => CloseRoleMenu(app))
    g.OnEvent("Close", (*) => CloseRoleMenu(app))

    UpdateRoleMenuHighlight(g)

    GetCursorPosForCapture(app, &x, &y)

    g.Show("AutoSize Hide")
    g.GetPos(,, &w, &h)

    mon := GetMonitorFromPoint(x, y)
    MonitorGetWorkArea(mon, &L, &T, &R, &B)
    xPos := Min(Max(L, x + 10), R - w)
    yPos := y - h - 10
    if (yPos < T)
        yPos := Min(y + 10, B - h)

    app.roleMenuGui := g
    g.Show("x" xPos " y" yPos)
}

RoleMenuChangeRole(app, g, dir) {
    roles := g.roles
    newIdx := g.currentIdx + dir
    if (newIdx < 1)
        newIdx := roles.Length
    if (newIdx > roles.Length)
        newIdx := 1

    g.currentIdx := newIdx
    UpdateRoleMenuHighlight(g)
}

UpdateRoleMenuHighlight(g) {
    roles := g.roles
    idx := g.currentIdx
    g.upBtn.Text := "Up: " NormalizeRoleName(roles[idx])
    g.downBtn.Text := "Down: " NormalizeRoleName(roles[idx])
}

CloseRoleMenu(app) {
    try {
        if app.HasOwnProp("roleMenuGui") && app.roleMenuGui {
            app.roleMenuGui.Destroy()
            app.roleMenuGui := 0
        }
    }
    try {
        if app.HasOwnProp("pinMenuGui") && app.pinMenuGui {
            app.pinMenuGui.Destroy()
            app.pinMenuGui := 0
        }
    }
}

RoleBtnClick(app, role, itemId, hex, ctrl, *) {
    try ctrl.Gui.Destroy()
    CloseRoleMenu(app)

    ApplyRoleMutationById(app.activePalette, role, itemId)
    Commit(app)
    if itemId != ""
        RefreshSectionByItemId(app, itemId)
    ShowToast(app, "Set " role)
}

BatchRoleBtnClickFromMenu(app, role, targetIds, ctrl, *) {
    try ctrl.Gui.Destroy()
    CloseRoleMenu(app)

    for _, id in targetIds {
        ApplyRoleMutationById(app.activePalette, role, id)
    }
    Commit(app)

    for _, id in targetIds {
        RefreshSectionByItemId(app, id)
    }
    ShowToast(app, "Set " targetIds.Length " color(s) to " role)
}
