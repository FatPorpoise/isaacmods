#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///
"""
Binding of Isaac (Repentance+, 32-bit isaac-ng.exe under Proton) render-thread spin fix.

The GL submission thread (module 'isaac-ng_Submission') busy-polls its command
queue: lock -> see empty -> unlock -> immediately re-lock, with no sleep. It burns
a full core under Wine (RtlEnterCriticalSection churn around wglMakeCurrent).

This patch redirects the queue-empty branch through a code cave that calls
kernel32!Sleep(1) before looping, so the thread idles instead of spinning.
Effect (measured): that thread 103% -> ~1% of a core, 60 FPS unchanged.

Idempotent, verifies the exact known build, backs up once, refuses on any mismatch.
Re-run it any time Steam re-syncs / updates and reverts the exe.

Usage:
    uv run python patch_spinfix.py --check     # read-only: report, touch nothing
    uv run python patch_spinfix.py             # apply (game must be closed)
    uv run python patch_spinfix.py --revert    # restore from .orig backup
"""
import struct, sys, shutil, os, glob

EXE = "/home/bate/.local/share/Steam/steamapps/common/The Binding of Isaac Rebirth/isaac-ng.exe"
IMAGE_BASE = 0x400000

# --- offsets discovered for build v1.9.7.17 (virtual addresses, image base 0x400000) ---
SITE_VA      = 0xa9e9c6                      # queue-empty branch jmp
SITE_ORIG    = bytes.fromhex("e9d3000000")   # jmp 0xa9ea9e  (original 5 bytes)
CONT_VA      = 0xa9ea9e                      # loop continuation (jmp target)
CAVE_VA      = 0x417e30                      # >=21 bytes of 0xCC padding
SLEEP_IAT_VA = 0xb182d8                      # [slot] -> kernel32!Sleep (game's own import)


def parse_pe(data):
    e_lfanew = struct.unpack_from('<I', data, 0x3c)[0]
    assert data[e_lfanew:e_lfanew+4] == b'PE\x00\x00', "not a PE file"
    coff = e_lfanew + 4
    num_sec = struct.unpack_from('<H', data, coff + 2)[0]
    opt_size = struct.unpack_from('<H', data, coff + 16)[0]
    opt = coff + 20
    image_base = struct.unpack_from('<I', data, opt + 28)[0]
    sec_off = opt + opt_size
    secs = []
    for i in range(num_sec):
        o = sec_off + i * 40
        vsize, vaddr, rawsize, rawptr = struct.unpack_from('<IIII', data, o + 8)
        secs.append((vaddr, vsize, rawptr, rawsize))
    return image_base, secs


def va2off(va, image_base, secs):
    rva = va - image_base
    for vaddr, vsize, rawptr, rawsize in secs:
        if vaddr <= rva < vaddr + max(vsize, rawsize):
            return rawptr + (rva - vaddr)
    raise ValueError("VA 0x%x maps to no section" % va)


def build_stub():
    # pushad; pushfd; mov ebp,esp; push 1; call [Sleep]; mov esp,ebp; popfd; popad; jmp CONT
    stub  = bytes([0x60, 0x9C, 0x89, 0xE5, 0x6A, 0x01, 0xFF, 0x15])
    stub += struct.pack('<I', SLEEP_IAT_VA)
    stub += bytes([0x89, 0xEC, 0x9D, 0x61])
    jmp_va = CAVE_VA + len(stub)
    stub += b'\xE9' + struct.pack('<i', CONT_VA - (jmp_va + 5))
    return stub


def game_running():
    for p in glob.glob('/proc/[0-9]*/comm'):
        try:
            if open(p).read().strip() == 'isaac-ng.exe':
                return True
        except OSError:
            pass
    return False


def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else "--apply"
    if not os.path.exists(EXE):
        sys.exit("exe not found: %s" % EXE)

    data = bytearray(open(EXE, 'rb').read())
    image_base, secs = parse_pe(data)
    if image_base != IMAGE_BASE:
        sys.exit("unexpected ImageBase 0x%x — refuse" % image_base)

    site_off = va2off(SITE_VA, image_base, secs)
    cave_off = va2off(CAVE_VA, image_base, secs)
    stub = build_stub()
    site_new = b'\xE9' + struct.pack('<i', CAVE_VA - (SITE_VA + 5))
    bak = EXE + ".orig"

    cur_site = bytes(data[site_off:site_off + 5])
    cur_cave = bytes(data[cave_off:cave_off + len(stub)])
    patched = (cur_site == site_new and cur_cave == stub)
    original = (cur_site == SITE_ORIG and cur_cave[:21] == b'\xcc' * 21)

    if mode == "--revert":
        if os.path.exists(bak):
            shutil.copy2(bak, EXE)
            print("reverted from %s" % bak)
        else:
            sys.exit("no backup at %s" % bak)
        return

    print("SITE file-offset 0x%x  CAVE file-offset 0x%x" % (site_off, cave_off))
    print("current SITE bytes: %s" % cur_site.hex())
    if patched:
        print("STATUS: already patched — nothing to do")
        return
    if not original:
        sys.exit("STATUS: bytes don't match known build v1.9.7.17 — game changed; "
                 "refuse to patch. Re-derive offsets for the new build.")
    print("STATUS: clean, known build — ready to patch")

    if mode == "--check":
        print("(check mode: nothing written)")
        return

    if game_running():
        sys.exit("REFUSE: isaac-ng.exe is running — close the game first "
                 "(patching a live-mmapped exe can crash it).")

    if not os.path.exists(bak):
        shutil.copy2(EXE, bak)
        print("backup -> %s" % bak)
    data[cave_off:cave_off + len(stub)] = stub
    data[site_off:site_off + 5] = site_new
    open(EXE, 'wb').write(data)
    print("PATCHED: spin-fix installed (Sleep(1) on queue-empty branch)")


if __name__ == "__main__":
    main()
