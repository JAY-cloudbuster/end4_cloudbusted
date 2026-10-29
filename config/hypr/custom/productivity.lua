-- Productivity additions for the end4-enhanced shell
-- Loaded from custom/keybinds.lua. Safe to delete this file to undo everything here.

--##! Window switcher
-- Hold Alt, tap Tab to cycle (Shift+Tab backwards), release Alt to switch
hl.bind("ALT + Tab", hl.dsp.global("quickshell:windowSwitcherNext"), { description = "Window: Switch windows (Alt+Tab)" })
hl.bind("ALT + SHIFT + Tab", hl.dsp.global("quickshell:windowSwitcherPrev"))
-- Releasing Alt confirms. transparent so apps still see Alt normally.
hl.bind("ALT_L", hl.dsp.global("quickshell:windowSwitcherRelease"), { ignore_mods = true, transparent = true, release = true })
hl.bind("ALT_R", hl.dsp.global("quickshell:windowSwitcherRelease"), { ignore_mods = true, transparent = true, release = true })

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
-- move and resize freely; the app's maximize button fills the space again.
-- (Minimize is handled by the shell: services/WindowMinimize.qml)
local restore_size = { width = 0.6, height = 0.65 } -- fraction of the monitor

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

-- Un-maximizes caused by something else are ignored for a moment: keybind toggles keep
-- their old behaviour, and a window opening or moving onto a workspace un-maximizes the
-- window already there as a side effect. open_early fires before that side effect.
local ignore_changes = false
local function ignore_briefly()
    ignore_changes = true
    hl.timer(function() ignore_changes = false end, { timeout = 300, type = "oneshot" })
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
        local width, height = 1100, 700
        if win.monitor then
            width = math.floor(win.monitor.width * restore_size.width)
            height = math.floor(win.monitor.height * restore_size.height)
        end
        floated_by_restore[win.address] = true
        hl.dispatch(hl.dsp.window.float({ action = "enable", window = target }))
        hl.dispatch(hl.dsp.window.resize({ x = width, y = height, exact = true, window = target }))
        hl.dispatch(hl.dsp.window.center({ window = target }))
    end
end)
