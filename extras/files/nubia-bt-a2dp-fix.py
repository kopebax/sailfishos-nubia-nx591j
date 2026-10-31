#!/usr/bin/python3
# Keep A2DP speakers/headphones in the right direction.
#
# Some speakers that also offer an A2DP source role (e.g. LAMAX Dots2 Touch)
# open their stream towards our A2DP sink endpoint when they connect. The
# phone then "receives" audio from the speaker and bluetoothd fails to connect
# the a2dp-sink profile we actually want (EBUSY), so nothing plays on it.
# When a transport to our sink endpoint shows up for a device that is itself an
# A2DP sink, drop it and connect the a2dp-sink profile instead.

import re
import subprocess
import sys
import time

A2DP_SOURCE = '0000110a-0000-1000-8000-00805f9b34fb'
A2DP_SINK = '0000110b-0000-1000-8000-00805f9b34fb'
DEV_RE = re.compile(r'(/org/bluez/hci\d+/dev_[0-9A-F_]{17})/sep\d+/fd\d+')


def log(msg):
    print(msg, flush=True)


def bluez(path, iface, method, *args):
    cmd = ['dbus-send', '--system', '--print-reply', '--dest=org.bluez',
           path, '%s.%s' % (iface, method)] + list(args)
    r = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                       universal_newlines=True, timeout=30)
    return r.returncode == 0, r.stdout


def device_uuids(dev):
    ok, out = bluez(dev, 'org.freedesktop.DBus.Properties', 'Get',
                    'string:org.bluez.Device1', 'string:UUIDs')
    return re.findall(r'string "([0-9a-f-]+)"', out) if ok else []


def fix(dev):
    if A2DP_SINK not in device_uuids(dev):
        return
    log('%s: remote A2DP source stream, switching to a2dp-sink' % dev)
    bluez(dev, 'org.bluez.Device1', 'DisconnectProfile', 'string:' + A2DP_SOURCE)
    time.sleep(1)
    ok, out = bluez(dev, 'org.bluez.Device1', 'ConnectProfile', 'string:' + A2DP_SINK)
    if not ok:
        log('%s: ConnectProfile failed: %s' % (dev, out.strip()))


def main():
    mon = subprocess.Popen(
        ['dbus-monitor', '--system',
         "type='signal',sender='org.bluez',interface='org.freedesktop.DBus.ObjectManager',member='InterfacesAdded'"],
        stdout=subprocess.PIPE, universal_newlines=True)
    dev = None
    for line in mon.stdout:
        if line.startswith('signal '):
            dev = None
            continue
        m = DEV_RE.search(line)
        if m and 'object path' in line:
            dev = m.group(1)
        elif dev and A2DP_SINK in line:
            # MediaTransport1.UUID names our local endpoint: a sink transport
            # means the remote device is streaming to us
            fix(dev)
            dev = None
    return mon.wait()


if __name__ == '__main__':
    sys.exit(main())
