#!/usr/bin/python3
# Bring up the WCNSS (Pronto) Bluetooth core for BlueZ on the Nubia NX591J.
#
# Waits for the APPS_RIVA_BT_CMD/ACL SMD channels (WCNSS firmware is up),
# hands the BD address stored in /persist/bluetooth/.bt_nv.bin to the hci_smd
# driver (it programs it on the first power on; without it the controller
# reports 00:00:00:00:5A:AD) and creates hci0.

import glob
import os
import sys
import time

NV_FILE = '/persist/bluetooth/.bt_nv.bin'
PARAMS = '/sys/module/hci_smd/parameters/'
HCI0 = '/sys/class/bluetooth/hci0'


def log(msg):
    print(msg, flush=True)


def wait_for(cond, timeout):
    end = time.monotonic() + timeout
    while time.monotonic() < end:
        if cond():
            return True
        time.sleep(0.2)
    return False


def read_bdaddr():
    # 01 00 06 <address, little endian>
    try:
        data = open(NV_FILE, 'rb').read()
    except OSError as e:
        log('no BD address: %s' % e)
        return None
    if len(data) < 9 or data[2] != 6 or data[3:9] in (b'\0' * 6, b'\xff' * 6):
        log('no valid BD address in %s' % NV_FILE)
        return None
    return ':'.join('%02x' % b for b in reversed(data[3:9]))


def main():
    if os.path.exists(HCI0):
        return 0
    if not wait_for(lambda: glob.glob('/sys/bus/platform/devices/APPS_RIVA_BT_CMD*'), 60):
        log('WCNSS BT channels did not appear')
        return 1
    # /persist is mounted by droid-hal-init
    wait_for(lambda: os.path.exists(NV_FILE), 30)
    addr = read_bdaddr()
    if addr:
        with open(PARAMS + 'bdaddr', 'w') as f:
            f.write(addr)
        log('BD address %s' % addr)
    with open(PARAMS + 'hcismd_set', 'w') as f:
        f.write('1')
    # hci0 is registered once WCNSS opens the channels
    if not wait_for(lambda: os.path.exists(HCI0), 60):
        log('hci0 did not appear')
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
