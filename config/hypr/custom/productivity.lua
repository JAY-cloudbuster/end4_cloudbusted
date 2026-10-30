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
      -- YouTube Music web app installed from Brave
      cmd = "/opt/brave-bin/brave --profile-directory=Default --app-id=cinhimbnkkaeohfgghhklpknlkffjgod" },
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
