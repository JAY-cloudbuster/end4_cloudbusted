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
