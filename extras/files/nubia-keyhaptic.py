#!/usr/bin/python3
# Wibracja przy naciśnięciu przycisków pod ekranem (Nubia NX591J, Sailfish OS).
# Android robił to we frameworku; w Sailfishu przyciski nie generują zdarzeń ngfd.
import glob, os, struct

KEYS = {158, 172}            # KEY_BACK, KEY_HOMEPAGE (patrz cap-button-codes w DTS)
PULSE_MS = b"45"
VIBRATOR = "/sys/class/timed_output/vibrator/enable"
EVENT = struct.Struct("llHHi")


def touch_device():
    for d in glob.glob("/sys/class/input/event*/device/name"):
        if open(d).read().strip() == "nubia_synaptics_dsx":
            return "/dev/input/" + d.split("/")[4]
    raise SystemExit("brak urządzenia nubia_synaptics_dsx")


with open(touch_device(), "rb") as dev:
    while True:
        _, _, etype, code, value = EVENT.unpack(dev.read(EVENT.size))
        if etype == 1 and value == 1 and code in KEYS:   # EV_KEY, wciśnięcie
            try:
                with open(VIBRATOR, "wb") as v:
                    v.write(PULSE_MS)
            except OSError:
                pass
