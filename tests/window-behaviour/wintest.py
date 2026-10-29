#!/usr/bin/env python3
"""Test window that sends real xdg-toplevel requests, like an app's title-bar buttons.

Usage: wintest.py APP_ID [ACTION@SECONDS ...]
  actions: maximize, unmaximize, minimize, close
Example: wintest.py claude.t1 maximize@1 unmaximize@3 close@6
"""
import sys
import gi

gi.require_version("Gtk", "4.0")
from gi.repository import Gtk, GLib

app_id = sys.argv[1]
steps = [arg.split("@") for arg in sys.argv[2:]]


def on_activate(app):
    window = Gtk.ApplicationWindow(application=app, title=app_id)
    window.set_default_size(500, 350)
    window.set_child(Gtk.Label(label=f"{app_id}\n" + " ".join(sys.argv[2:])))
    window.present()

    def run(action):
        print(f"[{app_id}] {action}", flush=True)
        if action == "close":
            window.close()
        else:
            getattr(window, action)()
        return GLib.SOURCE_REMOVE

    for action, seconds in steps:
        GLib.timeout_add(int(float(seconds) * 1000), run, action)


app = Gtk.Application(application_id=app_id)
app.connect("activate", on_activate)
app.run([])
