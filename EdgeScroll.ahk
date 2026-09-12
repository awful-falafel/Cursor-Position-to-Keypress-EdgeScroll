#Requires AutoHotkey v2.0
#SingleInstance Force  ; replaces any already-running copy of this script
Persistent()
; ============================================================
;  EdgeScroll — accessibility edge-scroller (AHK v2)
;  Triggers WASD keypresses when the mouse cursor touches
;  the extreme edges of the primary monitor.
;
;  Tray icon:
;    - Left-click / menu: Enable/Disable, Game Mode, Settings
;    - Exit fully unloads the script
;  Game Mode:
;    - Reserved for low-level injection behavior. If a target game
;      runs elevated, restart this script as Administrator.
; ============================================================

; ---------------- Settings (persisted to INI) ----------------
iniFile := A_ScriptDir "\EdgeScroll.ini"
; How many pixels from the physical edge still count as "at the edge".
; 1 = literally right up against the edge (what you asked for).
edgeThreshold := IniRead(iniFile, "Settings", "EdgeThreshold", 1)
; Poll interval in ms. Small = responsive, negligible CPU.
pollMs := IniRead(iniFile, "Settings", "PollInterval", 10)
repeatMs := IniRead(iniFile, "Settings", "RepeatInterval", 30)

enabled := IniRead(iniFile, "State", "Enabled", 1)
gameMode := IniRead(iniFile, "State", "GameMode", 0)
; Optional: only trigger while this process (e.g. "game.exe") is active.
; Empty = always active. Selected via the tray "Focus process" picker.
targetProcess := IniRead(iniFile, "State", "TargetProcess", "")
; Launch with Windows (off by default).
autostart := IniRead(iniFile, "State", "Autostart", 0)
; When on, EdgeScroll keeps firing the held edge even if the cursor leaves
; the primary monitor (e.g. the user drags the cursor to a secondary screen).
ignoreOtherMonitors := IniRead(iniFile, "State", "IgnoreOtherMonitors", 0)

; Edge -> key map (WASD by default). Editable from the Settings window;
; values are single letters or AHK key names (e.g. "Left", "Space").
LoadEdgeKeys() {
    global iniFile
    m := Map("left", "a", "right", "d", "top", "w", "bottom", "s")
    for k, def in m
        m[k] := Trim(IniRead(iniFile, "Keys", k, def))
    return m
}
edgeKeys := LoadEdgeKeys()

; ---------------- Primary monitor bounds ----------------
GetPrimaryBounds() {
    ; In AHK, monitor 1 is always the primary monitor. Use its full rect
    ; (not the work area) since games span the entire screen.
    MonitorGet(1, &left, &top, &right, &bottom)
    return {left: left, top: top, right: right - 1, bottom: bottom - 1}
}

bounds := GetPrimaryBounds()

; ---------------- Send helpers ----------------
SendKey(key, down) {
    vk := Map("a", 0x41, "d", 0x44, "w", 0x57, "s", 0x53)
    code := vk.Has(StrLower(key)) ? vk[StrLower(key)] : 0
    if (code = 0) {
        ; Fallback for arbitrary remapped keys: plain Send
        if down
            SendInput("{" key " down}")
        else
            SendInput("{" key " up}")
        return
    }
    scan := Map(0x41, 0x1E, 0x44, 0x20, 0x57, 0x11, 0x53, 0x1F)
    flagsDown := 0x0008 ; KEYEVENTF_SCANCODE
    flagsUp := 0x0008 | 0x0002 ; scancode | keyup
    ; Scancode-based injection is accepted by most game engines,
    ; unlike SendMode synthetic keys.
    DllCall("keybd_event", "UChar", 0, "UChar", scan[code],
        "UInt", down ? flagsDown : flagsUp, "UPtr", 0)
}

; ---------------- Edge detection loop ----------------
held := Map("left", false, "right", false, "top", false, "bottom", false)

EvaluateEdges() {
    global bounds, edgeThreshold, held, enabled, ignoreOtherMonitors
    if !enabled {
        ReleaseAll()
        return
    }
    CoordMode("Mouse", "Screen")
    MouseGetPos(&mx, &my, &mWin)

    ; Optional process focus: only trigger while the chosen process is
    ; the foreground window's process.
    if !IsTargetActive() {
        ReleaseAll()
        return
    }

    ; By default, only the primary monitor's edge counts (otherwise a cursor
    ; sitting on a neighboring monitor at the same coordinate boundary would
    ; falsely hold a movement key). When "ignore other monitors" is on, the
    ; secondary monitor is treated as an extension of the primary, so the
    ; edge keys stay held even if the cursor drags off-screen onto another
    ; display.
    onPrimary := true
    if !ignoreOtherMonitors {
        onPrimary := (mx >= bounds.left && mx <= bounds.right
            && my >= bounds.top && my <= bounds.bottom)
    }

    atLeft   := onPrimary && (mx <= bounds.left + edgeThreshold - 1)
    atRight  := onPrimary && (mx >= bounds.right - edgeThreshold + 1)
    atTop    := onPrimary && (my <= bounds.top + edgeThreshold - 1)
    atBottom := onPrimary && (my >= bounds.bottom - edgeThreshold + 1)

    CheckEdge("left", atLeft)
    CheckEdge("right", atRight)
    CheckEdge("top", atTop)
    CheckEdge("bottom", atBottom)
}

; NOTE: the old CycleThreshold tray item was replaced by the Settings
; window's editable trigger-zone field.

CheckEdge(name, active) {
    global held, edgeKeys
    ; Corners intentionally overlap: e.g. top-left holds W AND A at once,
    ; because each edge is tracked independently.
    if (active && !held[name]) {
        held[name] := true
        SendKey(edgeKeys[name], true)
    } else if (!active && held[name]) {
        held[name] := false
        SendKey(edgeKeys[name], false)
    }
}

ReleaseAll() {
    global held, edgeKeys
    for name, isHeld in held {
        if (isHeld) {
            held[name] := false
            SendKey(edgeKeys[name], false)
        }
    }
}

; Timer drives everything.
SetTimer(EvaluateEdges, pollMs)
; While a key is held, re-send the down event periodically so the OS
; and editors see sustained/repeating input (a single synthetic key-down
; does not hardware-auto-repeat).
SetTimer(RepeatHeldKeys, repeatMs)

RepeatHeldKeys() {
    global held, edgeKeys
    for name, isHeld in held
        if (isHeld)
            SendKey(edgeKeys[name], true)
}

; Release anything held and quit cleanly (tray Exit or logoff).
OnExit(CleanupAndExit)

CleanupAndExit(reason, code) {
    ReleaseAll()
}

; ---------------- Autostart (Windows startup) ----------------
; Registers/unregisters a HKCU Run entry so EdgeScroll launches with Windows.
; Off by default; toggled from the Settings window.
ApplyAutostart(on) {
    regKey := "HKCU\Software\Microsoft\Windows\CurrentVersion\Run"
    if on {
        ; Compiled exe: quote the exe. Source script: run via the AHK interpreter.
        cmd := A_IsCompiled ? '"' A_ScriptFullPath '"' : '"' A_AhkPath '" "' A_ScriptFullPath '"'
        RegWrite(cmd, "REG_SZ", regKey, "EdgeScroll")
    } else {
        ; No entry exists unless the user enabled autostart at least once.
        try
            RegDelete(regKey, "EdgeScroll")
    }
}

; Make sure the registry matches the INI on startup (e.g. INI restored from backup).
ApplyAutostart(autostart)

; ---------------- Tray UI ----------------
tray := A_TrayMenu
tray.Delete() ; rebuild cleanly

UpdateTrayMenu() {
    global tray, enabled, gameMode
    tray.Delete()
    tray.Add((enabled ? "Disable (currently ON)" : "Enable (currently OFF)"), ToggleEnabled)
    tray.Add()
    tray.Add((gameMode ? "Game Mode: ON" : "Game Mode: OFF"), ToggleGameMode)
    tray.Add("Settings...", ShowSettings)
    tray.Add()
    focusLabel := targetProcess = "" ? "Focus process: Any" : "Focus process: " targetProcess
    tray.Add(focusLabel, ShowProcessPicker)
    tray.Add()
    tray.Add("Exit", (*) => ExitApp())
    tray.Default := (enabled ? "Disable (currently ON)" : "Enable (currently OFF)")
    TraySetIcon("shell32.dll", enabled ? 44 : 110)
}

ToggleEnabled(*) {
    global enabled
    enabled := !enabled
    IniWrite(enabled, iniFile, "State", "Enabled")
    if !enabled
        ReleaseAll()
    UpdateTrayMenu()
}

ToggleGameMode(*) {
    global gameMode
    gameMode := !gameMode
    IniWrite(gameMode, iniFile, "State", "GameMode")
    UpdateTrayMenu()
}

; NOTE: CycleThreshold was replaced by the Settings window's editable
; trigger-zone field.

; ---------------- Key capture (press a key) ----------------
CaptureKeyFor(edge, current) {
    static capGui := unset
    if IsSet(capGui)
        capGui.Destroy()
    capGui := Gui("+AlwaysOnTop", "EdgeScroll - Set " edge " edge key")
    capGui.AddText(, "Press a key for the " edge " edge...`nEsc keeps the current key.")
    capGui.Show()
    ; Bare single-key capture: any key ends the hook (KeyOpt E) and its
    ; normalized name is returned. Letters may report via EndKey or Input.
    ih := InputHook("V T6")
    ih.KeyOpt("{All}", "E")
    ih.Start()
    ih.Wait()
    capGui.Destroy()
    name := ih.EndKey
    if (name = "")
        name := ih.Input
    if (name = "Escape" || name = "")
        return current
    return name
}

; Bind a key button so its click handler captures its own edge name
; (a for-loop variable captured by a closure isn't valid at click time).
BindKeyButton(btn, edge, keys) {
    btn.OnEvent("Click", (*) => (
        keys[edge] := CaptureKeyFor(edge, keys[edge]),
        btn.Text := keys[edge]
    ))
}

ShowSettings(*) {
    static settingsGui := unset
    if IsSet(settingsGui)
        settingsGui.Destroy()
    settingsGui := Gui("+AlwaysOnTop", "EdgeScroll - Settings")
    settingsGui.MarginX := 14, settingsGui.MarginY := 12

    ; Explicit absolute coordinates so rows never chain/overlap.
    enChk := settingsGui.AddCheckBox("x16 y12 Checked" (enabled ? 1 : 0), "Edge scrolling active")
    gmChk := settingsGui.AddCheckBox("x16 y34 Checked" (gameMode ? 1 : 0), "Game Mode (lower-level key injection)")
    asChk := settingsGui.AddCheckBox("x16 y56 Checked" (autostart ? 1 : 0), "Start with Windows")
    igChk := settingsGui.AddCheckBox("x16 y78 Checked" (ignoreOtherMonitors ? 1 : 0), "Ignore other monitors (keep firing at primary edge)")

    settingsGui.AddText("x16 y108", "Trigger zone (pixels from edge)")
    zoneEdit := settingsGui.AddEdit("Number x16 y124 w80", String(edgeThreshold))

    settingsGui.AddText("x16 y162", "Poll interval (ms) - how often the cursor is checked")
    pollEdit := settingsGui.AddEdit("Number x16 y180 w80", String(pollMs))

    settingsGui.AddText("x16 y220", "Repeat interval (ms) - key-down re-send rate while held")
    repeatEdit := settingsGui.AddEdit("Number x16 y238 w80", String(repeatMs))

    uiKeys := Map("left", edgeKeys["left"], "right", edgeKeys["right"],
        "top", edgeKeys["top"], "bottom", edgeKeys["bottom"])
    settingsGui.AddText("x16 y292", "Edge keys (click a button, then press a key)")
    settingsGui.AddText("x16 y314", "Top edge:")
    kTopBtn := settingsGui.AddButton("x114 y312 w80", uiKeys["top"])
    settingsGui.AddText("x16 y342", "Left edge:")
    kLeftBtn := settingsGui.AddButton("x114 y340 w80", uiKeys["left"])
    settingsGui.AddText("x16 y370", "Bottom edge:")
    kBottomBtn := settingsGui.AddButton("x114 y368 w80", uiKeys["bottom"])
    settingsGui.AddText("x16 y398", "Right edge:")
    kRightBtn := settingsGui.AddButton("x114 y396 w80", uiKeys["right"])
    BindKeyButton(kTopBtn, "top", uiKeys)
    BindKeyButton(kLeftBtn, "left", uiKeys)
    BindKeyButton(kBottomBtn, "bottom", uiKeys)
    BindKeyButton(kRightBtn, "right", uiKeys)

    settingsGui.AddText("x16 y436", "Focus process (empty = any process, e.g. game.exe)")
    procEdit := settingsGui.AddEdit("x16 y454 w280", targetProcess)
    pickBtn := settingsGui.AddButton("x16 y480 w280", "Choose from running windows...")
    pickBtn.OnEvent("Click", (*) => (ShowProcessPicker(), procEdit.Value := targetProcess))

    settingsGui.AddButton("Default x16 y512 w90", "Save")
    settingsGui.OnEvent("Close", (*) => settingsGui.Destroy())

    saveBtn.OnEvent("Click", SaveSettings_Click)
    cancelBtn.OnEvent("Click", (*) => settingsGui.Destroy())

    SaveSettings_Click(*) {
        global edgeThreshold, pollMs, repeatMs, targetProcess, enabled, gameMode, autostart, ignoreOtherMonitors, edgeKeys, held
        z := Integer(zoneEdit.Value), p := Integer(pollEdit.Value), r := Integer(repeatEdit.Value)
        if (z < 1 || p < 1 || r < 1) {
            MsgBox("All numeric values must be at least 1.", "EdgeScroll", 48)
            return
        }
        newKeys := Map("left", uiKeys["left"], "right", uiKeys["right"],
            "top", uiKeys["top"], "bottom", uiKeys["bottom"])
        for k, v in newKeys {
            v := Trim(v)
            if (v = "") {
                MsgBox("Every edge needs a key assigned.", "EdgeScroll", 48)
                return
            }
            newKeys[k] := v
        }
        edgeThreshold := z, pollMs := p, repeatMs := r
        enabled := enChk.Value, gameMode := gmChk.Value
        newProc := Trim(procEdit.Value)
        procChanged := (StrCompare(newProc, targetProcess, true) != 0)
        targetProcess := newProc
        newAutostart := asChk.Value
        newIgnoreOtherMonitors := igChk.Value

        ; Apply keys: release anything held that's about to change, then swap.
        keysChanged := false
        for k, v in newKeys
            if (StrCompare(v, edgeKeys[k], true) != 0)
                keysChanged := true
        if keysChanged {
            for k, v in edgeKeys
                if (held[k])
                    SendKey(v, false)
            edgeKeys := newKeys
            for k, v in edgeKeys
                if (held[k])
                    SendKey(v, true)
        }

        IniWrite(edgeThreshold, iniFile, "Settings", "EdgeThreshold")
        IniWrite(pollMs, iniFile, "Settings", "PollInterval")
        IniWrite(repeatMs, iniFile, "Settings", "RepeatInterval")
        IniWrite(targetProcess, iniFile, "State", "TargetProcess")
        IniWrite(enabled, iniFile, "State", "Enabled")
        IniWrite(gameMode, iniFile, "State", "GameMode")
        IniWrite(autostart := newAutostart, iniFile, "State", "Autostart")
        IniWrite(ignoreOtherMonitors := newIgnoreOtherMonitors, iniFile, "State", "IgnoreOtherMonitors")
        for k, v in edgeKeys
            IniWrite(v, iniFile, "Keys", k)

        ApplyAutostart(autostart)
        SetTimer(EvaluateEdges, pollMs)
        SetTimer(RepeatHeldKeys, repeatMs)
        if !enabled || (procChanged && !IsTargetActive())
            ReleaseAll()
        settingsGui.Destroy()
        UpdateTrayMenu()
    }

    settingsGui.Show()
}

ShowProcessPicker(*) {
    global targetProcess
    ; Build a checklist of visible top-level windows grouped by process name.
    procs := Map() ; name -> sample window title (for context)
    for hwnd in WinGetList() {
        name := ProcessGetName(WinGetPID("ahk_id " hwnd))
        if (name = A_ScriptName || name = "explorer.exe")
            continue
        title := WinGetTitle("ahk_id " hwnd)
        if (title = "")
            continue
        if !procs.Has(name)
            procs[name] := title
    }
    if procs.Count = 0 {
        MsgBox("No eligible windows found.", "EdgeScroll", 48)
        return
    }
    names := []
    for name, t in procs
        names.Push(name)
    ; Sort case-insensitively for a tidy list (bubble sort).
    Loop names.Length - 1 {
        swapped := false
        Loop names.Length - A_Index {
            j := A_Index
            if StrCompare(names[j], names[j + 1], true) > 0 {
                tmp := names[j], names[j] := names[j + 1], names[j + 1] := tmp
                swapped := true
            }
        }
        if !swapped
            break
    }

    ; Simple selection GUI: DropDownList + buttons.
    static pickerGui := unset
    if IsSet(pickerGui)
        pickerGui.Destroy()
    pickerGui := Gui("+AlwaysOnTop", "EdgeScroll - Focus process")
    pickerGui.MarginX := 12, pickerGui.MarginY := 12
    pickerGui.AddText(, "Edge scrolling only triggers while this process is active:")
    dd := pickerGui.AddDropDownList("w360", ["(Any process)", names*])
    dd.Value := 1
    for i, n in names
        if (StrCompare(n, targetProcess, true) = 0)
            dd.Value := i + 1
    if (targetProcess = "")
        dd.Value := 1
    btnRow := pickerGui.AddButton("Default w80", "OK")
    cancelBtn := pickerGui.AddButton("w80 x+12", "Cancel")
    clearBtn := pickerGui.AddButton("w80 x+12", "Any process")
    pickChoice := ""
    btnRow.OnEvent("Click", (*) => (pickChoice := dd.Text, pickerGui.Destroy(), ApplyChoice(pickChoice)))
    cancelBtn.OnEvent("Click", (*) => pickerGui.Destroy())
    clearBtn.OnEvent("Click", (*) => (pickerGui.Destroy(), ApplyChoice("")))
    pickerGui.Show()
}

ApplyChoice(name) {
    global targetProcess
    targetProcess := (name = "(Any process)") ? "" : name
    IniWrite(targetProcess, iniFile, "State", "TargetProcess")
    if !IsTargetActive()
        ReleaseAll()
    UpdateTrayMenu()
}

IsTargetActive() {
    global targetProcess
    if (targetProcess = "")
        return true
    try hwnd := WinExist("A")
    if !hwnd
        return false
    try return (ProcessGetName(WinGetPID("ahk_id " hwnd)) = targetProcess)
    catch
        return false
}

UpdateTrayMenu()
msg := enabled ? "Running - touch a screen edge to move (WASD)." : "Disabled - enable from the tray menu."
TrayTip("EdgeScroll", msg)
