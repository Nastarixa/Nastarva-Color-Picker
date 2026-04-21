InitApp() {
    return {
        version: "3.0",
        CheckActive: false,
        historyVisible: false,
        g_UsePhysicalCoords: true,

        historyMax: 0,

        pickGui: 0,
        historyGui: 0,
        roleMenuGui: 0,
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
        pickerTickFn: 0,

        ui: {
            controls: Map(),
            sectionHeaders: Map(),
            sectionGuis: Map(),
            sectionPositions: Map(),
            panelDragHwnds: Map(),
            controlHexByHwnd: Map(),
            drag: {
                active: false,
                hex: "",
                targetHex: ""
            },
            panelMove: {
                active: false,
                hwnd: 0,
                offsetX: 0,
                offsetY: 0
            },
            generation: 0,
            itemW: 170,
            itemH: 30,
            gap: 4,
            cols: 10,
            rows: 3
        },

        toast: {
            gui: 0,
            running: false,
            startY: 0,
            curY: 0,
            endY: 0,
            x: 0,
            step: 0
        }
    }
}

InitEvents(app) {
    app.events["history_changed"] := [(*) => SafeRefreshHistoryUI(app)]
    OnMessage(0x84, (wParam, lParam, msg, hwnd) => HistoryPanelHitTest(app, wParam, lParam, msg, hwnd))
    OnMessage(0x201, (wParam, lParam, msg, hwnd) => HistoryDragMouseDown(app, wParam, lParam, msg, hwnd))
    OnMessage(0x200, (wParam, lParam, msg, hwnd) => HistoryMouseMove(app, wParam, lParam, msg, hwnd))
    OnMessage(0x202, (wParam, lParam, msg, hwnd) => HistoryDragMouseUp(app, wParam, lParam, msg, hwnd))
}

SafeRefreshHistoryUI(app) {
    if !app.historyVisible
        return

    RefreshHistoryUI(app)
}

Emit(app, name) {
    global _emitLock

    if _emitLock
        return

    if !app.events.Has(name)
        return

    if (name = "history_changed" && !app.historyVisible)
        return

    _emitLock := true
    try {
        for _, fn in app.events[name]
            fn()
    } finally {
        _emitLock := false
    }
}

DebouncedRefresh(app) {
    static pending := false

    if pending
        return

    pending := true
    SetTimer(() => (
        pending := false,
        SafeHistoryRefresh(app)
    ), -50)
}

SafeHistoryRefresh(app) {
    if !app.historyVisible
        return

    RefreshHistoryUI(app)
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
