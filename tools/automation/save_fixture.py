"""Discover manual saves and pin an explicit save for guarded game replay."""
import argparse
from datetime import datetime
import hashlib
import json
from pathlib import Path
import re


def describe(save):
    save = save.resolve()
    if not save.name.startswith('ManualSave_') or save.suffix != '.sav':
        raise ValueError('Select an explicit ManualSave_*.sav file')
    before = save.stat()
    digest = hashlib.sha256(save.read_bytes()).hexdigest()
    after = save.stat()
    if (before.st_size, before.st_mtime_ns) != (after.st_size, after.st_mtime_ns):
        raise RuntimeError('Save changed while pinning; retry after saving finishes')
    return {'save_name': save.name, 'path': str(save), 'sha256': digest,
            'timestamp_local': datetime.fromtimestamp(before.st_mtime).astimezone().isoformat(),
            'bytes': before.st_size, 'thumbnail': str(save.with_suffix('.png')),
            'metadata': str(save.with_suffix('.json'))}


def make_fixture(save, title, hud_labels):
    if not title.strip() or not hud_labels or any(not value.strip() for value in hud_labels):
        raise ValueError('Visible title and nonempty gameplay HUD labels are required')
    result = describe(save)
    stamp = datetime.fromisoformat(result['timestamp_local'])
    day = r'\s*'.join(str(stamp.day))
    hour = r'\s*'.join(str(stamp.hour % 12 or 12))
    weekday = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'][stamp.weekday()]
    month = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August',
             'September', 'October', 'November', 'December'][stamp.month - 1]
    suffix = 'AM' if stamp.hour < 12 else 'PM'
    result['row_pattern'] = (re.escape(title.strip()) + rf'\s*[-–]\s*{weekday},\s*{month}\s+{day},\s*'
                             rf'{stamp.year}\s+{hour}:{stamp.minute:02}:{stamp.second:02}\s+{suffix}')
    result['hud_labels'] = hud_labels
    result['timestamp_source'] = 'filesystem modification time; must match the uniquely visible manual-save row'
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    actions = parser.add_subparsers(dest='action', required=True)
    discover = actions.add_parser('list')
    discover.add_argument('--profile', type=Path, required=True)
    discover.add_argument('--limit', type=int, default=10)
    pin = actions.add_parser('pin')
    pin.add_argument('--save', type=Path, required=True)
    pin.add_argument('--title', required=True)
    pin.add_argument('--hud-label', action='append', required=True)
    pin.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    if args.action == 'list':
        if not 1 <= args.limit <= 100:
            parser.error('Limit must be between 1 and 100')
        directory = args.profile / 'gamesaves'
        if not directory.is_dir():
            parser.error('Redirected profile gamesaves directory is missing')
        saves = sorted(directory.glob('ManualSave_*.sav'), key=lambda p: p.stat().st_mtime_ns, reverse=True)
        print(json.dumps([describe(p) for p in saves[:args.limit]], indent=2))
    else:
        fixture = make_fixture(args.save, args.title, args.hud_label)
        # Do not replace an existing pinned fixture or a user's save.
        with args.output.open('x', encoding='utf-8') as stream:
            json.dump(fixture, stream, indent=2)
        print(args.output.resolve())


if __name__ == '__main__':
    main()
