#!/usr/bin/env python3
"""Install a Pokemon Stadium 2 (USA) ROM for the Stadium 2 importer.

Why this exists: the importer's battle-effect decoder carries address tables
derived from the USA disc only, and it reads the ROM bytes it finds at those
addresses. A Europe (NP3P) disc imports models, poses and move animations
correctly -- those tables do keep the USA offsets -- but its effect overlay is
somewhere else, so `battleFxCatalog()` fails and MOVE EFFECTS never happen.
That failure is quiet unless lib/StadiumModels.lua reports it (it does now).

This also handles the file ORDER, which is the other trap: a `.n64` download is
usually byteswapped (v64), and the importer's decoder opens the file directly
rather than normalising it, so a v64 file can pass the importer's model import
and still decode garbage for effects.

    tools/install_stadium2_rom.sh <path-to-rom> [identity]

    identity  defaults to the QA identity, pokemon-love2d-rseqa. Pass
              pokemon-love2d for the real game.

The ROM is never copied into this repository: it is written into the game
identity's own `mods/STADIUM2_IMPORTER/baseroms/`, which is gitignored and
stays on this machine.

After this, clear the importer's cache so it re-extracts with the new disc, then
let the game rebuild it:

    rm -rf "<identity>/mod_storage/emerald/*/STADIUM2_IMPORTER/cache"

and turn on the importer's MOVE EFFECTS (BETA) row.
"""
import hashlib
import os
import shutil
import sys

# Layout.US_MD5 in the importer: the only revision its effect tables describe.
US_MD5 = "1561c75d11cedf356a8ddb1a4a5f9d5d"
EU_MD5 = "b1271db50d6ef8f6b53cc640c3743e4f"
ROM_SIZE = 0x4000000
US_TITLE = "POKEMON STADIUM 2"

MAGIC_Z64 = bytes.fromhex("80371240")
MAGIC_V64 = bytes.fromhex("37804012")
MAGIC_N64 = bytes.fromhex("40123780")


def normalise(data):
    """Same three byte orders the importer's Rom.normalise accepts."""
    if data[:4] == MAGIC_Z64:
        return data, "z64"
    if data[:4] == MAGIC_V64:
        swapped = bytearray(data)
        swapped[0::2], swapped[1::2] = swapped[1::2], swapped[0::2]
        return bytes(swapped), "v64"
    if data[:4] == MAGIC_N64:
        swapped = bytearray(data)
        swapped[0::4], swapped[1::4], swapped[2::4], swapped[3::4] = (
            swapped[3::4], swapped[2::4], swapped[1::4], swapped[0::4])
        return bytes(swapped), "n64"
    return None, "unrecognised (first bytes %s)" % data[:4].hex()


def main(argv):
    if len(argv) < 2:
        print(__doc__)
        return 2
    source = argv[1]
    identity = argv[2] if len(argv) > 2 else "pokemon-love2d-rseqa"

    if not os.path.isfile(source):
        print("no such ROM: %s" % source)
        return 1
    with open(source, "rb") as handle:
        raw = handle.read()

    data, order = normalise(raw)
    if data is None:
        print("cannot read this file: %s" % order)
        return 1
    if len(data) != ROM_SIZE:
        print("wrong size: %d bytes (Stadium 2 is %d)" % (len(data), ROM_SIZE))
        return 1

    title = data[0x20:0x34].replace(b"\0", b"").decode("latin1").strip()
    digest = hashlib.md5(data).hexdigest()
    print("order  : %s -> z64" % order)
    print("title  : %s" % title)
    print("md5    : %s" % digest)

    if title.upper() != US_TITLE:
        print("wrong title: this is not Pokemon Stadium 2")
        return 1
    if digest == EU_MD5:
        print("This is the EUROPE revision (NP3P). The importer reads it for "
              "models and move animations, but its battle-effect tables are "
              "not the ones the decoder carries, so MOVE EFFECTS cannot work. "
              "A USA disc is needed.")
        return 1
    if digest != US_MD5:
        print("This Stadium 2 revision is neither the supported USA disc nor "
              "the Europe one. The importer may read its models; its effects "
              "are not described by these tables.")
        return 1

    target_dir = os.path.expanduser(
        "~/Library/Application Support/%s/mods/STADIUM2_IMPORTER/baseroms" % identity)
    if not os.path.isdir(target_dir):
        print("no importer baseroms directory at:\n  %s\n"
              "Is STADIUM2_IMPORTER installed in the '%s' identity?"
              % (target_dir, identity))
        return 1

    target = os.path.join(target_dir, "stadium2.z64")
    if os.path.exists(target):
        with open(target, "rb") as handle:
            existing, _ = normalise(handle.read())
        if existing is not None:
            existing_md5 = hashlib.md5(existing).hexdigest()
            if existing_md5 == US_MD5:
                print("already installed: %s" % target)
                return 0
            keep = os.path.join(target_dir, "stadium2_previous.z64.bak")
            shutil.copy2(target, keep)
            print("kept the previous disc at %s" % keep)

    # Always written as z64: the effect decoder opens this file directly
    # instead of normalising it.
    with open(target, "wb") as handle:
        handle.write(data)
    print("installed: %s" % target)

    cache_glob = os.path.expanduser(
        "~/Library/Application Support/%s/mod_storage/emerald" % identity)
    if os.path.isdir(cache_glob):
        cleared = []
        for root, dirs, _files in os.walk(cache_glob):
            if os.path.basename(root) == "STADIUM2_IMPORTER" and "cache" in dirs:
                shutil.rmtree(os.path.join(root, "cache"))
                cleared.append(os.path.join(root, "cache"))
        for path in cleared:
            print("cleared cached import: %s" % path)
        if cleared:
            print("The importer will rebuild it on the next boot (~4 minutes).")
    print("\nNext: start the %s identity and turn on the importer's "
          "MOVE EFFECTS (BETA) row." % identity)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
