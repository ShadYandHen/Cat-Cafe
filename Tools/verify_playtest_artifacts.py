#!/usr/bin/env python3
"""Verify exported payload isolation and all PCK entry checksums. No save access.
Usage: python3 Tools/verify_playtest_artifacts.py export/windows/PawPadsCafe.pck export/android/PawPadsCafe-debug.apk
"""
import hashlib
import io
from pathlib import Path
import struct
import sys
import zipfile


def pck_entries(path):
    raw = Path(path).read_bytes()
    stream = io.BytesIO(raw)
    def read(fmt):
        return struct.unpack(fmt, stream.read(struct.calcsize(fmt)))
    magic, version, major, minor, patch, flags, base = read('<6IQ')
    assert magic == 0x43504447 and version in (2, 3) and not flags & 1, 'Unsupported/encrypted PCK'
    if version == 3:
        stream.seek(read('<Q')[0])
    else:
        stream.seek(64, 1)
    entries = {}
    for _ in range(read('<I')[0]):
        name = stream.read(read('<I')[0]).rstrip(b'\0').decode()
        offset, size = read('<QQ')
        digest = stream.read(16)
        entry_flags, = read('<I')
        assert entry_flags == 0, (name, entry_flags)
        data = raw[base+offset:base+offset+size]
        assert len(data) == size and hashlib.md5(data).digest() == digest, name
        entries[name.removeprefix('res://')] = data
    return entries


def verify(entries):
    for name in entries:
        assert not any(part in ('Tools', 'ArtReferences', 'Docs', 'export') for part in name.split('/')), name
        assert not name.endswith(('.keystore', '.jks', '.pem')), name
    for path in Path('Data').rglob('*.json'):
        assert path.as_posix() in entries, str(path)
        assert entries[path.as_posix()] == path.read_bytes(), str(path)
    assert 'Scenes/Title.tscn.remap' in entries or 'Scenes/Title.tscn' in entries


if __name__ == '__main__':
    pck = pck_entries(sys.argv[1])
    verify(pck)
    with zipfile.ZipFile(sys.argv[2]) as apk:
        assert apk.testzip() is None
        entries = {n.removeprefix('assets/'): apk.read(n) for n in apk.namelist() if n.startswith('assets/') and not n.endswith('/')}
        verify(entries)
        assert {'lib/arm64-v8a/libgodot_android.so', 'lib/armeabi-v7a/libgodot_android.so'} <= set(apk.namelist())
    print(f'PASS: {len(pck)} PCK checksums, {len(entries)} Android assets; runtime catalogs intact; no development harness, references, documentation or signing keys')
