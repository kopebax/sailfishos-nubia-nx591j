#!/usr/bin/python3
# Drive the voice call audio path of nubia-audiobridge.
#
# The port uses its own PulseAudio <-> 32-bit audio HAL bridge instead of
# module-droid-card, so nothing puts the HAL into AUDIO_MODE_IN_CALL during a
# call and the voice path stays silent. Watch ofono calls and the voicecall
# speaker / microphone mute settings and send "call 1|2" (SIM slot) /
# "normal" / "speaker 0|1" / "mute 0|1" to the bridge.

import os
import re
import subprocess
import sys
import threading

CTL_FIFO = '/run/nubia-audio/ctl'
SESSION_BUS = 'unix:path=/run/user/100000/dbus/user_bus_socket'
# Voice path is needed once the call is set up; a ringing call still plays
# the ringtone through PulseAudio.
CALL_STATES = ('active', 'held', 'dialing', 'alerting')

lock = threading.Lock()
state = {'call': 0, 'speaker': False}


def log(msg):
    print(msg, flush=True)


def send(cmd):
    try:
        fd = os.open(CTL_FIFO, os.O_WRONLY | os.O_NONBLOCK)
    except OSError as e:
        log('cannot open %s: %s' % (CTL_FIFO, e))
        return
    try:
        os.write(fd, (cmd + '\n').encode())
    finally:
        os.close(fd)
    log('-> ' + cmd)


def ofono(path, method):
    r = subprocess.run(['dbus-send', '--system', '--print-reply', '--dest=org.ofono',
                        path, method], stdout=subprocess.PIPE,
                       stderr=subprocess.DEVNULL, universal_newlines=True, timeout=10)
    return r.stdout


def call_slot():
    """SIM slot (1 or 2) with a call in progress, 0 if none."""
    modems = re.findall(r'object path "(/ril_(\d+))"', ofono('/', 'org.ofono.Manager.GetModems'))
    for modem, index in modems:
        calls = ofono(modem, 'org.ofono.VoiceCallManager.GetCalls')
        for st in re.findall(r'string "State"\s+variant\s+string "(\w+)"', calls):
            if st in CALL_STATES:
                return int(index) + 1
    return 0


def update_call():
    with lock:
        now = call_slot()
        if now == state['call']:
            return
        state['call'] = now
        if now:
            send('speaker %d' % state['speaker'])
            send('call %d' % now)
        else:
            state['speaker'] = False
            send('normal')


def watch(cmd, handler):
    mon = subprocess.Popen(cmd, stdout=subprocess.PIPE, universal_newlines=True)
    for line in mon.stdout:
        handler(line)
    return mon.wait()


def on_ofono(line):
    if line.startswith('signal '):
        update_call()


pending = None


def on_voicecall(line):
    # voicecall-ui calls setAudioMode("ihf" | "earpiece") and
    # setMuteMicrophone(bool); the argument follows on the next line.
    # (audioModeChanged carries no value and the properties cannot be read
    # as root.)
    global pending
    if line.startswith('method call '):
        m = re.search(r'member=(setAudioMode|setMuteMicrophone)', line)
        pending = m.group(1) if m else None
        return
    if pending == 'setAudioMode':
        m = re.search(r'string "(ihf|earpiece)"', line)
        if not m:
            return
        pending = None
        with lock:
            speaker = m.group(1) == 'ihf'
            if speaker != state['speaker']:
                state['speaker'] = speaker
                if state['call']:
                    send('speaker %d' % speaker)
    elif pending == 'setMuteMicrophone':
        m = re.search(r'boolean (true|false)', line)
        if not m:
            return
        pending = None
        with lock:
            send('mute %d' % (m.group(1) == 'true'))


def main():
    send('normal')
    threading.Thread(target=watch, daemon=True, args=(
        ['dbus-monitor', '--address', SESSION_BUS,
         "type='method_call',interface='org.nemomobile.voicecall.VoiceCallManager',member='setAudioMode'",
         "type='method_call',interface='org.nemomobile.voicecall.VoiceCallManager',member='setMuteMicrophone'"],
        on_voicecall)).start()
    return watch(['dbus-monitor', '--system',
                  "type='signal',sender='org.ofono',interface='org.ofono.VoiceCallManager'",
                  "type='signal',sender='org.ofono',interface='org.ofono.VoiceCall'"],
                 on_ofono)


if __name__ == '__main__':
    sys.exit(main())
