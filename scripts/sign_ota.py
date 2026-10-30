# Podpis "whole-file" paczki OTA (jak signapk -w) dla recovery LineageOS 14.1
import struct, subprocess, sys, os
src, dst, cert, key, tmp = sys.argv[1:6]
z = open(src, 'rb').read()
assert z[-22:-18] == b'PK\x05\x06' and z[-2:] == b'\x00\x00', "ZIP musi mieć pusty komentarz"
signed = z[:-2]                       # wszystko poza polem długości komentarza
open(os.path.join(tmp, 'data'), 'wb').write(signed)
sig = subprocess.run(['openssl', 'cms', '-sign', '-binary', '-noattr', '-nosmimecap', '-md', 'sha1',
                      '-signer', cert, '-inkey', key, '-in', os.path.join(tmp, 'data'), '-outform', 'DER'],
                     check=True, capture_output=True).stdout
total = len(sig) + 6
footer = struct.pack('<HHH', total, 0xffff, total)   # signature_start, 0xffff, comment_size
comment = sig + footer
assert b'PK\x05\x06' not in comment
open(dst, 'wb').write(signed + struct.pack('<H', len(comment)) + comment)
print("podpis:", len(sig), "B, komentarz:", len(comment), "B")
