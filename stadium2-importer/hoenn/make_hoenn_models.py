#!/usr/bin/env python3
"""Make the 3D battle models for Hoenn Pokemon (#252-386) from your own
Pokemon Colosseum disc image (.iso, .gcm or Dolphin .ciso).

  python3 make_hoenn_models.py [disc image] [--out <STADIUM2_IMPORTER folder>]

The models go to colosseum/normal|shiny/<dex>.dsm in the importer's mod folder
(the folder above this one). Start the game afterwards."""
import json, os, shlex, shutil, struct, sys
sys.dont_write_bytecode = True
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import colo2dsm, disc

SIZE = 52.25 / 8.891283502383645   # Colosseum -> Stadium 2 size: median species height onto 52.25
IMAGES = ('.iso', '.gcm', '.ciso')


def find_disc(args):
    if args: return args[0]
    for d in (os.path.join(HERE, '..', 'baseroms'), HERE):
        for f in sorted(os.listdir(d)) if os.path.isdir(d) else ():
            if f.lower().endswith(IMAGES): return os.path.join(d, f)
    try:
        typed = input('Drag your Pokemon Colosseum disc image (.iso, .gcm or .ciso) here and press Enter: ').strip()
    except EOFError:
        return None
    parts = shlex.split(typed) if typed else []
    return parts[0] if parts else None


def resized(blob):
    """Rewrite the pack's root scale and height/floor/radius for SIZE."""
    b = bytearray(blob)
    factor = (SIZE / colo2dsm.UNITS) / struct.unpack_from('<f', b, 16)[0]
    struct.pack_into('<f', b, 16, SIZE / colo2dsm.UNITS)
    for off in (21, 25, 29):
        struct.pack_into('<f', b, off, struct.unpack_from('<f', b, off)[0] * factor)
    return bytes(b)


def main():
    args = sys.argv[1:]
    out = os.path.normpath(os.path.join(HERE, '..'))
    if '--out' in args:
        i = args.index('--out'); out = args[i + 1]; del args[i:i + 2]
    try:
        if json.load(open(os.path.join(out, 'manifest.json'))).get('id') != 'STADIUM2_IMPORTER': raise ValueError
    except (OSError, ValueError):
        sys.exit(f'{out} is not the STADIUM2_IMPORTER mod folder (use --out).')
    path = find_disc(args)
    if not path or not os.path.isfile(path):
        sys.exit('No disc image found: give the path to your Pokemon Colosseum .iso, .gcm or .ciso.')
    if not path.lower().endswith(IMAGES):
        sys.exit('Use a plain disc image (.iso, .gcm or .ciso). Dolphin converts .rvz, .wia and .nkit:'
                 ' right-click the game, Convert File, format ISO.')
    d = disc.Disc(path)
    if d.id not in disc.GAME_IDS:
        sys.exit(f'This is not Pokemon Colosseum (game id {d.id!r}).')

    names = json.load(open(os.path.join(HERE, 'hoenn_names.json')))
    files = d.files()
    categories = colo2dsm.move_categories()
    todo = [n for n in names if f'pkx_{n}.fsys' in files]
    made, failed = {}, []
    for k, name in enumerate(todo, 1):
        off, size = files[f'pkx_{name}.fsys']
        try:
            (meta, scene), = disc.load_pkx(disc.fsys_first(d.read(off, size)), name)
            data = colo2dsm.convert(scene.models[0], meta.pkx_header, categories)
            made[name] = resized(colo2dsm.pack(names[name], data, 1.0 / colo2dsm.UNITS))
            print(f'[{k}/{len(todo)}] {name}', flush=True)
        except Exception as ex:
            failed.append(name)
            print(f'[{k}/{len(todo)}] {name} failed: {ex}', flush=True)

    # one pack per dex: the plain name wins over forms; shiny from rare_<name>
    groups = {}
    for name in made:
        groups.setdefault((names[name], name.startswith('rare_')), []).append(name)
    dst = os.path.join(out, 'colosseum'); tmp = dst + '.new'
    shutil.rmtree(tmp, ignore_errors=True)
    for v in ('normal', 'shiny'): os.makedirs(os.path.join(tmp, v))
    count = {False: 0, True: 0}
    for (dex, rare), group in sorted(groups.items()):
        if rare and (dex, False) not in groups: continue
        best = sorted(group, key=lambda n: ('_' in n, len(n), n))[0]
        open(os.path.join(tmp, 'shiny' if rare else 'normal', f'{dex:03d}.dsm'), 'wb').write(made[best])
        count[rare] += 1
    shutil.rmtree(dst, ignore_errors=True)
    os.rename(tmp, dst)
    print(f'\nMade {count[False]} Hoenn models (+{count[True]} shiny) in {dst}')
    if failed: print('Could not convert:', ', '.join(failed))
    print('Start the game: Hoenn Pokemon now use 3D models in battle.')


if __name__ == '__main__':
    main()
