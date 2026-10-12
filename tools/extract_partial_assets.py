"""Extract only complete, CRC-verified entries from an in-progress ZIP download."""
import argparse
from pathlib import Path
import struct
import zlib

def extract_complete(source, destination):
    destination = Path(destination).resolve()
    destination.mkdir(parents=True, exist_ok=True)
    count = 0
    with Path(source).open('rb') as stream:
        size = stream.seek(0, 2)
        position = 0
        while position + 30 <= size:
            stream.seek(position)
            header = stream.read(30)
            if header[:4] != b'PK\x03\x04':
                break
            version, flags, method, time, date, crc, packed, unpacked, namesize, extrasize = struct.unpack('<5H3I2H', header[4:])
            name = stream.read(namesize).decode('utf-8')
            start = position + 30 + namesize + extrasize
            if flags & 8 or start + packed > size:
                break
            target = (destination / name).resolve()
            if destination not in target.parents:
                raise ValueError('Unsafe archive path: ' + name)
            if not name.endswith('/') and not target.exists():
                stream.seek(start)
                data = stream.read(packed)
                if method == 8:
                    data = zlib.decompress(data, -15)
                elif method != 0:
                    raise ValueError('Unsupported ZIP compression')
                if len(data) != unpacked or zlib.crc32(data) & 0xffffffff != crc:
                    raise ValueError('Invalid archive entry: ' + name)
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(data)
                count += 1
                print('EXTRACTED', name)
            position = start + packed
    print('Verified entries extracted:', count)

if __name__ == '__main__':
    import sys
    args = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else sys.argv[1:]
    extract_complete(*args)
