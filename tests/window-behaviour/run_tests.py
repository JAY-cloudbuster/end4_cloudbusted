#!/usr/bin/env python3
"""End-to-end tests for title-bar button handling (Hyprland Lua + shell WindowMinimize).

Runs on an empty workspace with GTK test windows that send real xdg requests,
plus real keypresses through ydotool. Prints PASS/FAIL per case.
"""
import json
import os
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
WINTEST = os.path.join(HERE, "wintest.py")
TEST_WS = 9
os.environ.setdefault("YDOTOOL_SOCKET", "/run/user/1000/.ydotool_socket")

KEY = {"super": 125, "alt": 56, "shift": 42, "tab": 15, "d": 32, "f": 33, "8": 9, "minus": 12, "esc": 1}
results = []
procs = []


def sh(*args):
    return subprocess.run(args, capture_output=True, text=True).stdout


def lua(code):
    sh("hyprctl", "eval", code)


def clients():
    return json.loads(sh("hyprctl", "clients", "-j"))


def find(app_id):
    return next((c for c in clients() if c["class"] == app_id), None)


def wait_for(app_id, timeout=5):
    end = time.time() + timeout
    while time.time() < end:
        c = find(app_id)
        if c and c["mapped"]:
            return c
        time.sleep(0.1)
    return None


def spawn(app_id, *steps):
    p = subprocess.Popen([sys.executable, WINTEST, app_id, *steps],
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    procs.append(p)
    return wait_for(app_id)


def focus(app_id):
    c = find(app_id)
    if c:
        lua(f"hl.dispatch(hl.dsp.focus({{ window = 'address:{c['address']}' }}))")
        time.sleep(0.3)


def keys(*combo):
    codes = [KEY[k] for k in combo]
    seq = [f"{c}:1" for c in codes] + [f"{c}:0" for c in reversed(codes)]
    sh("ydotool", "key", *seq)
    time.sleep(0.6)


def close_all():
    for c in clients():
        if c["class"].startswith("claude."):
            lua(f"hl.dispatch(hl.dsp.window.close({{ window = 'address:{c['address']}' }}))")
    time.sleep(0.6)
    for p in procs:
        if p.poll() is None:
            p.kill()
    procs.clear()


def check(name, condition, detail=""):
    results.append((name, condition, detail))
    print(f"{'PASS' if condition else 'FAIL'}  {name}" + (f"  [{detail}]" if detail else ""), flush=True)


def state(c):
    return f"ws={c['workspace']['name']} fs={c['fullscreen']} float={c['floating']} size={c['size']}" if c else "gone"


def test(fn):
    print(f"\n== {fn.__doc__}", flush=True)
    try:
        fn()
    except Exception as e:  # keep going so one broken case doesn't hide the rest
        check(fn.__doc__, False, f"exception: {e}")
    close_all()


# ---------------------------------------------------------------- maximize / restore

def t_restore():
    """T1 restore button floats a maximized tiled window, centered"""
    spawn("claude.t1", "maximize@1", "unmaximize@2.5")
    time.sleep(3.3)
    c = find("claude.t1")
    check("floated", c and c["floating"], state(c))
    check("restore size ~60%x65%", c and abs(c["size"][0] - 1152) < 5 and abs(c["size"][1] - 780) < 5, state(c))
    mid_x = c["at"][0] + c["size"][0] / 2 if c else 0
    check("centered horizontally", abs(mid_x - 960) < 20, f"center x={mid_x}")


def t_restore_then_maximize():
    """T2 maximize after restore puts it back into tiling"""
    spawn("claude.t2", "maximize@1", "unmaximize@2.5", "maximize@4")
    time.sleep(4.8)
    c = find("claude.t2")
    check("tiled again", c and not c["floating"], state(c))
    check("maximized", c and c["fullscreen"] == 1, state(c))


def t_open_neighbor():
    """T3 opening a window next to a maximized one does not float it"""
    spawn("claude.t3a", "maximize@0.5")
    time.sleep(1.5)
    spawn("claude.t3b")
    time.sleep(1)
    c = find("claude.t3a")
    check("neighbor stays tiled", c and not c["floating"], state(c))


def t_close_neighbor():
    """T4 closing a window next to a maximized one does not float it"""
    spawn("claude.t4a")
    spawn("claude.t4b", "close@3")
    focus("claude.t4a")
    lua(f"hl.dispatch(hl.dsp.window.fullscreen({{ mode = 'maximized', action = 'set', window = 'address:{find('claude.t4a')['address']}' }}))")
    time.sleep(3)
    c = find("claude.t4a")
    check("survivor stays tiled", c and not c["floating"], state(c))


def t_keybind_maximize():
    """T5 Super+D toggling keeps the window tiled"""
    spawn("claude.t5")
    focus("claude.t5")
    keys("super", "d")
    c = find("claude.t5")
    check("Super+D maximizes", c and c["fullscreen"] == 1, state(c))
    keys("super", "d")
    c = find("claude.t5")
    check("Super+D again: un-maximized and still tiled", c and c["fullscreen"] == 0 and not c["floating"], state(c))


def t_keybind_fullscreen():
    """T6 Super+F fullscreen round trip keeps the window tiled"""
    spawn("claude.t6", "maximize@0.8")
    time.sleep(1.2)
    focus("claude.t6")
    keys("super", "f")
    c = find("claude.t6")
    check("Super+F fullscreen", c and c["fullscreen"] == 2, state(c))
    keys("super", "f")
    c = find("claude.t6")
    check("Super+F again: still tiled", c and not c["floating"], state(c))


def t_app_fullscreen():
    """T7 app fullscreen (like a video) from maximized and back keeps it tiled"""
    spawn("claude.t7", "maximize@1", "fullscreen@2", "unfullscreen@3")
    time.sleep(3.8)
    c = find("claude.t7")
    check("still tiled after leaving fullscreen", c and not c["floating"], state(c))


def t_move_workspace():
    """T8 moving a maximized window to another workspace keeps it tiled"""
    spawn("claude.t8", "maximize@0.8")
    time.sleep(1.2)
    focus("claude.t8")
    keys("super", "alt", "8")  # dotfiles: Super+Alt+N sends the window to workspace N
    c = find("claude.t8")
    check("moved", c and c["workspace"]["name"] != str(TEST_WS), state(c))
    check("still tiled after move", c and not c["floating"], state(c))
    lua(f"hl.dispatch(hl.dsp.focus({{ workspace = {TEST_WS} }}))")
    time.sleep(0.4)


def t_floating_dialog():
    """T9 a window floated by the user is left alone when it maximizes"""
    c = spawn("claude.t9", "maximize@2")
    lua(f"hl.dispatch(hl.dsp.window.float({{ action = 'enable', window = 'address:{c['address']}' }}))")
    time.sleep(2.6)
    c = find("claude.t9")
    check("still floating (not forced into tiling)", c and c["floating"], state(c))


# ---------------------------------------------------------------- minimize

def minimize_by_key(app_id):
    focus(app_id)
    keys("super", "shift", "minus")
    time.sleep(0.6)


def t_minimize_key():
    """T10 Super+Shift+Minus hides the focused window"""
    spawn("claude.t10")
    minimize_by_key("claude.t10")
    c = find("claude.t10")
    check("moved to special:minimized", c and c["workspace"]["name"] == "special:minimized", state(c))


def t_app_minimize_request():
    """T10b an app's own minimize request is harmless (Hyprland ignores it)"""
    spawn("claude.t10b", "minimize@1")
    time.sleep(2)
    c = find("claude.t10b")
    check("window still there and tiled", c and not c["floating"], state(c))


def t_minimize_restore_alttab():
    """T11 Alt+Tab brings a minimized window back"""
    spawn("claude.t11a")
    spawn("claude.t11b")
    minimize_by_key("claude.t11b")
    focus("claude.t11a")
    keys("alt", "tab")  # most recent other window = t11b
    time.sleep(1)
    c = find("claude.t11b")
    check("back on the test workspace", c and c["workspace"]["name"] == str(TEST_WS), state(c))
    active = json.loads(sh("hyprctl", "activewindow", "-j")).get("class")
    check("and focused", active == "claude.t11b", f"active={active}")


def t_minimize_survives_reload():
    """T12 minimized windows still restore after a shell reload"""
    spawn("claude.t12")
    minimize_by_key("claude.t12")
    shell_qml = os.path.expanduser("~/.config/quickshell/end4-enhanced/shell.qml")
    os.utime(shell_qml)  # touch -> Quickshell reloads
    time.sleep(6)
    # The reload makes the shell's conflict checker pop a dialog (kded6) that steals focus
    sh("pkill", "-f", "killDialog.qml")
    time.sleep(0.5)
    c = find("claude.t12")
    check("was minimized", c and c["workspace"]["name"] == "special:minimized", state(c))
    lua(f"hl.dispatch(hl.dsp.focus({{ window = 'address:{c['address']}' }}))")
    time.sleep(1.2)
    c = find("claude.t12")
    check("restored after reload", c and c["workspace"]["name"] == str(TEST_WS), state(c))


def t_no_focus_loop():
    """T13 restoring does not start a focus loop"""
    spawn("claude.t13")
    minimize_by_key("claude.t13")
    sock = f"{os.environ['XDG_RUNTIME_DIR']}/hypr/{os.environ['HYPRLAND_INSTANCE_SIGNATURE']}/.socket2.sock"
    rec = subprocess.Popen(["timeout", "3", "socat", "-u", f"UNIX-CONNECT:{sock}", "-"],
                           stdout=subprocess.PIPE, text=True)
    time.sleep(0.2)
    focus("claude.t13")
    out = rec.communicate()[0]
    focus_events = out.count("activewindowv2>>")
    check("few focus events (no loop)", focus_events < 10, f"{focus_events} focus events in 3s")


def t_close_minimized():
    """T14 closing a minimized window works and leaves nothing behind"""
    spawn("claude.t14", "close@3")
    minimize_by_key("claude.t14")
    time.sleep(3)
    check("window gone", find("claude.t14") is None)


# ---------------------------------------------------------------- window switcher

def switcher_open():
    layers = json.loads(sh("hyprctl", "layers", "-j"))
    return any(l["namespace"] == "quickshell:windowSwitcher"
               for m in layers.values() for lv in m["levels"].values() for l in lv)


def active_class():
    return json.loads(sh("hyprctl", "activewindow", "-j")).get("class")


def press(code, down):
    sh("ydotool", "key", f"{code}:{1 if down else 0}")
    time.sleep(0.3)


def t_alttab_switch():
    """T15 Alt+Tab switches to the previous window and closes"""
    spawn("claude.t15a")
    spawn("claude.t15b")
    press(KEY["alt"], True)
    sh("ydotool", "key", f"{KEY['tab']}:1", f"{KEY['tab']}:0")
    time.sleep(0.6)
    check("switcher opens while Alt is held", switcher_open())
    press(KEY["alt"], False)
    time.sleep(0.6)
    check("switcher closes on Alt release", not switcher_open())
    check("switched to previous window", active_class() == "claude.t15a", f"active={active_class()}")


def t_alttab_resting_pointer():
    """T16 a mouse resting in the middle doesn't steal the selection"""
    spawn("claude.t16a")
    spawn("claude.t16b")
    sh("ydotool", "mousemove", "--absolute", "-x", "960", "-y", "600")
    time.sleep(0.3)
    keys("alt", "tab")
    time.sleep(0.6)
    check("switched to previous window", active_class() == "claude.t16a", f"active={active_class()}")


def t_alttab_cycle_back():
    """T17 Alt+Tab, Tab, Shift+Tab lands back on the previous window"""
    spawn("claude.t17a")
    spawn("claude.t17b")
    press(KEY["alt"], True)
    for _ in range(2):
        sh("ydotool", "key", f"{KEY['tab']}:1", f"{KEY['tab']}:0")
        time.sleep(0.3)
    sh("ydotool", "key", f"{KEY['shift']}:1", f"{KEY['tab']}:1", f"{KEY['tab']}:0", f"{KEY['shift']}:0")
    time.sleep(0.3)
    press(KEY["alt"], False)
    time.sleep(0.6)
    check("ends on the previous window", active_class() == "claude.t17a", f"active={active_class()}")


def t_alttab_cancel():
    """T18 Alt+Escape cancels without switching"""
    spawn("claude.t18a")
    spawn("claude.t18b")
    press(KEY["alt"], True)
    sh("ydotool", "key", f"{KEY['tab']}:1", f"{KEY['tab']}:0")
    time.sleep(0.4)
    sh("ydotool", "key", f"{KEY['esc']}:1", f"{KEY['esc']}:0")
    time.sleep(0.3)
    press(KEY["alt"], False)
    time.sleep(0.6)
    check("switcher closed", not switcher_open())
    check("focus unchanged", active_class() == "claude.t18b", f"active={active_class()}")


def main():
    original_ws = json.loads(sh("hyprctl", "activeworkspace", "-j"))["id"]
    lua(f"hl.dispatch(hl.dsp.focus({{ workspace = {TEST_WS} }}))")
    time.sleep(0.5)
    try:
        for t in [t_restore, t_restore_then_maximize, t_open_neighbor, t_close_neighbor,
                  t_keybind_maximize, t_keybind_fullscreen, t_app_fullscreen, t_move_workspace,
                  t_floating_dialog, t_minimize_key, t_app_minimize_request, t_minimize_restore_alttab,
                  t_minimize_survives_reload, t_no_focus_loop, t_close_minimized,
                  t_alttab_switch, t_alttab_resting_pointer, t_alttab_cycle_back, t_alttab_cancel]:
            if len(sys.argv) > 1 and not any(t.__doc__.startswith(a) for a in sys.argv[1:]):
                continue
            test(t)
    finally:
        close_all()
        lua(f"hl.dispatch(hl.dsp.focus({{ workspace = {original_ws} }}))")
    failed = [r for r in results if not r[1]]
    print(f"\n{len(results) - len(failed)}/{len(results)} checks passed")
    for name, _, detail in failed:
        print(f"  FAIL {name} [{detail}]")


main()
