#!/usr/bin/env python3
"""Audit PT_LOAD segments of native libraries in AARs, APKs or AABs."""
import argparse
import struct
import sys
import zipfile


def load_segments(data):
    if data[:4] != b'\x7fELF' or data[4] not in (1, 2) or data[5] not in (1, 2):
        raise ValueError('invalid ELF header')
    elf64 = data[4] == 2
    endian = '<' if data[5] == 1 else '>'
    phoff = struct.unpack_from(endian + ('Q' if elf64 else 'I'), data, 32 if elf64 else 28)[0]
    entsize, count = struct.unpack_from(endian + 'HH', data, 54 if elf64 else 42)
    segments = []
    for idx in range(count):
        ph = struct.unpack_from(endian + ('II6Q' if elf64 else '8I'), data, phoff + idx * entsize)
        if ph[0] == 1:
            offset, vaddr = ph[2:4] if elf64 else ph[1:3]
            segments.append((ph[-1], (offset - vaddr) % 16384 == 0))
    if not segments:
        raise ValueError('no PT_LOAD segments')
    return segments


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('archives', nargs='+')
    args = parser.parse_args()
    passed = True
    for path in args.archives:
        with zipfile.ZipFile(path) as archive:
            names = sorted(name for name in archive.namelist() if name.endswith('.so'))
            if not names:
                print(f'{path}: no shared libraries', file=sys.stderr)
                passed = False
            for name in names:
                segments = load_segments(archive.read(name))
                ok = all(align >= 16384 and congruent for align, congruent in segments)
                print(f'{path} {name} PT_LOAD min={min(align for align, _ in segments)} {"PASS" if ok else "FAIL"}')
                passed &= ok
    return 0 if passed else 1


if __name__ == '__main__':
    sys.exit(main())
