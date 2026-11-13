#!/usr/bin/env python3
"""向 64 位 Mach-O 的 load command 区追加一条 LC_LOAD_DYLIB。"""
import struct
import sys

LC_LOAD_DYLIB = 0xC
MH_MAGIC_64 = 0xFEEDFACF


def align8(v):
    return (v + 7) & ~7


def add_load_dylib(path, dylib_path):
    with open(path, "rb") as f:
        data = bytearray(f.read())

    magic, _, _, _, ncmds, sizeofcmds, _, _ = struct.unpack_from("<IiiIIIII", data, 0)
    if magic != MH_MAGIC_64:
        raise SystemExit("not a 64-bit Mach-O: %s" % path)

    end = 32 + sizeofcmds
    name = dylib_path.encode("utf-8") + b"\x00"
    cmdsize = align8(24 + len(name))

    if any(data[end:end + cmdsize]):
        raise SystemExit("no free space for LC_LOAD_DYLIB (need %d bytes at %d)" % (cmdsize, end))

    cmd = struct.pack("<IIIIII", LC_LOAD_DYLIB, cmdsize, 24, 2, 0x10000, 0x10000)
    payload = cmd + name
    payload += b"\x00" * (cmdsize - len(payload))

    data[end:end + cmdsize] = payload
    struct.pack_into("<II", data, 16, ncmds + 1, sizeofcmds + cmdsize)

    with open(path, "wb") as f:
        f.write(data)
    print("added %s (cmdsize=%d)" % (dylib_path, cmdsize))


if __name__ == "__main__":
    if len(sys.argv) != 3:
        raise SystemExit("usage: patch_load_command.py <mach-o> <dylib-install-path>")
    add_load_dylib(sys.argv[1], sys.argv[2])
