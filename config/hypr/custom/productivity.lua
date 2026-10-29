-- Productivity additions for the end4-enhanced shell
-- Loaded from custom/keybinds.lua. Safe to delete this file to undo everything here.

--##! Window switcher
-- Hold Alt, tap Tab to cycle (Shift+Tab backwards), release Alt to switch
local switcher_open = false
local function switcher(action)
    return function()
        switcher_open = action ~= "Cancel"
        hl.dispatch(hl.dsp.global("quickshell:windowSwitcher" .. action))
    end
end
hl.bind("ALT + Tab", switcher("Next"), { description = "Window: Switch windows (Alt+Tab)" })
hl.bind("ALT + SHIFT + Tab", switcher("Prev"))
hl.bind("ALT + Escape", switcher("Cancel"))
-- Releasing Alt confirms. Not a release bind: Hyprland skips those when another key (Tab)
-- was pressed while Alt was held, so watch raw key events instead. Apps still see Alt normally.
local alt_keycodes = { [64] = true, [108] = true } -- Alt_L, Alt_R
hl.on("input.keyboard.key", function(keycode, _, pressed)
    if switcher_open and pressed == 0 and alt_keycodes[keycode] then
        switcher_open = false
        hl.dispatch(hl.dsp.global("quickshell:windowSwitcherRelease"))
    end
end)

--##! Window search
-- Launcher in open-windows mode (or type "," in the launcher)
hl.bind("SUPER + Comma", hl.dsp.global("quickshell:overviewWindowsToggle"), { description = "Window: Search open windows" })

--##! Scratchpads
-- Each is a special workspace that launches its app the first time it's opened.
-- Press the key again to hide it; the app keeps running in the background.
-- The original Super+S scratchpad is untouched.
local scratchpads = {
    { name = "term",    key = "SUPER + Grave", description = "Scratchpad: Terminal",
      cmd = "foot --app-id=scratch-term" },
    { name = "notes",   key = "SUPER + Y",     description = "Scratchpad: Quick notes",
      cmd = "foot --app-id=scratch-notes sh -c 'mkdir -p ~/Notes && exec nvim ~/Notes/scratch.md'" },
    { name = "music",   key = "SUPER + U",     description = "Scratchpad: Music",
      cmd = "spotify-launcher" },
    { name = "monitor", key = "SUPER + H",     description = "Scratchpad: System monitor",
      cmd = "foot --app-id=scratch-monitor btop" },
}
for _, pad in ipairs(scratchpads) do
    hl.workspace_rule({ workspace = "special:" .. pad.name, on_created_empty = pad.cmd, gaps_out = 60 })
    hl.bind(pad.key, hl.dsp.workspace.toggle_special(pad.name), { description = pad.description })
end

--##! Focus mode
-- Do Not Disturb + pomodoro focus round; press again to end
hl.bind("SUPER + Z", hl.dsp.global("quickshell:focusModeToggle"), { description = "Shell: Toggle focus mode" })

--##! Title-bar buttons: maximize / restore
-- A tiled window already fills its space, so an app's restore button used to do nothing visible.
-- Now restoring a maximized tiled window turns it into a normal floating window you can
-- move and resize freely; the app's maximize button puts it back into tiling.
local restore_size = { width = 0.6, height = 0.65 } -- fraction of the monitor
local restore_delay_ms = 150

--##! Minimize
-- Hyprland has no minimized state, and 0.56 doesn't report an app's own minimize button
-- (no event at all), so minimizing is a keybind: the window moves to a hidden special
-- workspace. Focusing it again from anywhere (Alt+Tab, launcher, dock) brings it back.
local minimized_workspace = "special:minimized"
hl.bind("SUPER + SHIFT + Minus", hl.dsp.window.move({ workspace = minimized_workspace, follow = false }),
    { description = "Window: Minimize" })
hl.on("window.active", function(win)
    if not win or not win.workspace or win.workspace.name ~= minimized_workspace then return end
    -- The monitor's regular workspace, not the special one currently showing
    local target = win.monitor and win.monitor.active_workspace
    if not target then return end
    local window = "address:" .. win.address
    hl.dispatch(hl.dsp.window.move({ workspace = target.id, window = window }))
    hl.dispatch(hl.dsp.focus({ window = window }))
end)

-- Hyprland only reports the resulting state, not the app's request, so remember each
-- window's last state and only react to maximized -> normal
local fullscreen_state = {}
-- Windows floated by a restore click; their maximize click puts them back into tiling
local floated_by_restore = {}
for _, win in ipairs(hl.get_windows()) do fullscreen_state[win.address] = win.fullscreen end
hl.on("window.open", function(win) fullscreen_state[win.address] = win.fullscreen end)
-- window.close, not window.destroy: by destroy the address is already gone (nil)
hl.on("window.close", function(win)
    fullscreen_state[win.address] = nil
    floated_by_restore[win.address] = nil
end)

-- Un-maximizes caused by something else are ignored: keybind toggles keep their old
-- behaviour, and a window opening, closing or moving un-maximizes windows as a side effect.
-- Those events can arrive just before or just after the state change, so besides the brief
-- ignore window, a restore is only acted on if no such event happened during restore_delay_ms.
local ignore_changes = false
local side_effects = 0
local function ignore_briefly()
    ignore_changes = true
    side_effects = side_effects + 1
    hl.timer(function() ignore_changes = false end, { timeout = 300, type = "oneshot" })
end

local function window_by_address(address)
    for _, win in ipairs(hl.get_windows()) do
        if win.address == address then return win end
    end
end
hl.on("window.open_early", ignore_briefly)
hl.on("window.open", ignore_briefly)
hl.on("window.close", ignore_briefly)
hl.on("window.move_to_workspace", ignore_briefly)

local function keybind_fullscreen(dispatcher)
    return function()
        ignore_briefly()
        hl.dispatch(dispatcher)
    end
end
hl.unbind("SUPER + D")
hl.unbind("SUPER + F")
hl.unbind("SUPER + ALT + F")
hl.bind("SUPER + D", keybind_fullscreen(hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" })),
    { description = "Window: Maximize" })
hl.bind("SUPER + F", keybind_fullscreen(hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" })),
    { description = "Window: Fullscreen" })
hl.bind("SUPER + ALT + F", keybind_fullscreen(hl.dsp.window.fullscreen_state({ internal = 0, client = 3, action = "toggle" })),
    { description = "Window: Fullscreen spoof" })

hl.on("window.fullscreen", function(win)
    local before = fullscreen_state[win.address]
    fullscreen_state[win.address] = win.fullscreen
    -- Only the focused window: clicking its button focuses it, while windows un-maximized as a
    -- side effect (another window maximizing or opening on the same workspace) aren't focused
    if ignore_changes or not win.active then return end
    local target = "address:" .. win.address

    -- Maximize on a window we floated: back into the tiling layout, maximized
    if before == 0 and win.fullscreen == 1 and win.floating and floated_by_restore[win.address] then
        floated_by_restore[win.address] = nil
        ignore_briefly()
        hl.dispatch(hl.dsp.window.float({ action = "disable", window = target }))
        hl.dispatch(hl.dsp.window.fullscreen({ mode = "maximized", action = "set", window = target }))
        return
    end

    -- Restore on a maximized tiled window: free-floating, centered
    if before == 1 and win.fullscreen == 0 and not win.floating then
        local address = win.address
        local workspace = win.workspace and win.workspace.id
        local seen_side_effects = side_effects
        hl.timer(function()
            if side_effects ~= seen_side_effects then return end
            local now = window_by_address(address)
            if not now or now.floating or now.fullscreen ~= 0 or not now.active then return end
            if (now.workspace and now.workspace.id) ~= workspace then return end

            local width, height = 1100, 700
            if now.monitor then
                width = math.floor(now.monitor.width * restore_size.width)
                height = math.floor(now.monitor.height * restore_size.height)
            end
            floated_by_restore[address] = true
            hl.dispatch(hl.dsp.window.float({ action = "enable", window = target }))
            hl.dispatch(hl.dsp.window.resize({ x = width, y = height, exact = true, window = target }))
            hl.dispatch(hl.dsp.window.center({ window = target }))
        end, { timeout = restore_delay_ms, type = "oneshot" })
    end
end)
