InitApp() {
    return {
        version: "3.5",
        CheckActive: false,
        lastPickHex: "",
        historyVisible: false,
        g_UsePhysicalCoords: true,

        historyMax: 0,

        pickGui: 0,
        pickGuiRoleVisible: false,
        historyGui: 0,
        roleMenuGui: 0,
        roleMenuHwnd: 0,
        pinMenuGui: 0,
        lastHex: "",
        stableCount: 0,
        selectedRole: "Base",

        palettes: Map(),
        paletteOrder: [],
        paletteGui: 0,
        activePalette: 0,
        lastSize: { w: 0, h: 0 },
        events: Map(),
        toastTick: 0,
        lastCopyType: "",
        displayMode: "hex",
        pickerTickFn: 0,
        screenshotPollFn: 0,
        helpGui: 0,

        ui: {
            controls: Map(),
            sectionHeaders: Map(),
            sectionGuis: Map(),
            sectionPositions: Map(),
            panelDragHwnds: Map(),
            controlHexByHwnd: Map(),
            sectionByHwnd: Map(),
            batchSelected: Map(),
            lockLayoutOrder: false,
            drag: {
                active: false,
                hex: "",
                targetHex: "",
                targetSection: ""
            },
            panelMove: {
                active: false,
                pending: false,
                tickFn: 0,
                hwnd: 0,
                startMouseX: 0,
                startMouseY: 0,
                offsetX: 0,
                offsetY: 0,
                lastX: "",
                lastY: "",
                lastMoveTick: 0,
                nextX: "",
                nextY: ""
            },
            generation: 0,
            itemW: 194,
            itemH: 30,
            gap: 4,
            cols: 10,
            rows: 3
        },

        screenshotCapture: {
            active: false,
            deadline: 0,
            tempPath: "",
            savedClipboard: 0
        },

        toast: {
            gui: 0,
            running: false,
            startY: 0,
            curY: 0,
            endY: 0,
            x: 0,
            step: 0,
            type: "normal",
            dismissable: false,
            hasShownHelp: false
        },

        compactMode: false,
        headerCompactMode: false,
        fullCompactMode: false,
        layoutMode: false,
        favorites: [],
        favoritesGui: 0
    }
}

InitEvents(app) {
    app.events["history_changed"] := []
    OnMessage(0x84, (wParam, lParam, msg, hwnd) => HistoryPanelHitTest(app, wParam, lParam, msg, hwnd))
    OnMessage(0x201, (wParam, lParam, msg, hwnd) => HistoryDragMouseDown(app, wParam, lParam, msg, hwnd))
    OnMessage(0x200, (wParam, lParam, msg, hwnd) => HistoryMouseMove(app, wParam, lParam, msg, hwnd))
    OnMessage(0x202, (wParam, lParam, msg, hwnd) => HistoryDragMouseUp(app, wParam, lParam, msg, hwnd))
    OnMessage(0x204, (wParam, lParam, msg, hwnd) => HistoryRightClick(app, wParam, lParam, msg, hwnd))
    OnMessage(0x207, (wParam, lParam, msg, hwnd) => HistoryMiddleClick(app, wParam, lParam, msg, hwnd))
    OnMessage(0x201, (wParam, lParam, msg, hwnd) => DismissMenusOnClickOutside(app, wParam, lParam, msg, hwnd))
}

Emit(app, name) {
    global _emitLock

    if _emitLock
        return

    if !app.events.Has(name)
        return

    _emitLock := true
    try {
        for _, fn in app.events[name]
            fn()
    } finally {
        _emitLock := false
    }
}

HistoryMiddleClick(app, wParam, lParam, msg, hwnd) {
    if !app.historyVisible {
        return
    }

    if app.ui.HasOwnProp("sectionByHwnd") && app.ui.sectionByHwnd.Has(hwnd) {
        sectionName := app.ui.sectionByHwnd[hwnd]
        OpenSectionMenu(app, sectionName)
        return
    }

    if !app.ui.HasOwnProp("controlHexByHwnd") || !app.ui.controlHexByHwnd.Has(hwnd) {
        return
    }

    token := app.ui.controlHexByHwnd[hwnd]
    if !token {
        return
    }

    if SafeGetGuiHwnd(app.pinMenuGui)
        try app.pinMenuGui.Hide()
    if SafeGetGuiHwnd(app.roleMenuGui)
        try app.roleMenuGui.Hide()

    OpenRoleMenu(app, token)
}

HistoryRightClick(app, wParam, lParam, msg, hwnd) {
    if !app.historyVisible
        return

    if app.ui.HasOwnProp("sectionByHwnd") && app.ui.sectionByHwnd.Has(hwnd) {
        sectionName := app.ui.sectionByHwnd[hwnd]
        SetSelectedSection(app, sectionName)
        return
    }
}

GetMonitorFromPoint(x, y) {
    count := MonitorGetCount()
    Loop count {
        MonitorGetWorkArea(A_Index, &L, &T, &R, &B)
        if (x >= L && x <= R && y >= T && y <= B)
            return A_Index
    }
    return 1
}

DetectColorType(val) {
    if RegExMatch(val, "^[0-9A-Fa-f]{6}$")
        return "hex"
    if RegExMatch(val, "^\d+,\s*\d+,\s*\d+$")
        return "rgb"
    return "unknown"
}

SafeGetGuiHwnd(guiObj) {
    if !IsObject(guiObj)
        return 0

    try return guiObj.Hwnd
    catch
        return 0
}

SafeGetControlHwnd(ctrlObj) {
    if !IsObject(ctrlObj)
        return 0

    try return ctrlObj.Hwnd
    catch
        return 0
}

DismissMenusOnClickOutside(app, wParam, lParam, msg, hwnd) {
    if SafeGetGuiHwnd(app.roleMenuGui) {
        roleHwnd := SafeGetGuiHwnd(app.roleMenuGui)
        if (hwnd != roleHwnd && !IsChildOfMenu(app.roleMenuGui, hwnd)) {
            try app.roleMenuGui.Destroy()
        }
    }

    if SafeGetGuiHwnd(app.pinMenuGui) {
        pinHwnd := SafeGetGuiHwnd(app.pinMenuGui)
        if (hwnd != pinHwnd && !IsChildOfMenu(app.pinMenuGui, hwnd)) {
            try app.pinMenuGui.Destroy()
        }
    }
}

IsChildOfMenu(menuGui, hwnd) {
    if !SafeGetGuiHwnd(menuGui)
        return false

    menuHwnd := SafeGetGuiHwnd(menuGui)
    parent := DllCall("GetParent", "Ptr", hwnd)
    while (parent) {
        if (parent = menuHwnd)
            return true
        parent := DllCall("GetParent", "Ptr", parent)
    }
    return (hwnd = menuHwnd)
}
