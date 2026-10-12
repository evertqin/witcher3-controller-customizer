"""Replay a calibrated keyboard menu route, stopping at unrecognized screens."""
import argparse
from datetime import datetime, timezone
import json
from pathlib import Path
import re
import shutil
import subprocess
import time
import uuid

from assertions import read_ocr
from windows_ui import Desktop


def require_labels(text, labels):
    normalized = re.sub(r'\s+', ' ', text).casefold()
    missing = [label for label in labels if label.casefold() not in normalized]
    if missing:
        raise RuntimeError('Menu boundary not recognized: ' + ', '.join(missing))


def settings_items(lines):
    items = [line.strip().upper() for line in lines]
    if items.count('SETTINGS') > 1:
        raise RuntimeError('Settings heading ambiguous')
    if 'SETTINGS' in items:
        # Background HUD can appear above the exact menu heading.
        items = items[items.index('SETTINGS') + 1:]
    if 'BACK' in items:
        items = items[:items.index('BACK') + 1]
    return items


def preset_index(lines, title_screen=False):
    items = settings_items(lines)
    allowed = {'SOUND', 'CONTROLS', 'CONTROLLER SCHEME', 'KEY BINDINGS', 'GAMEPLAY',
               'VIDEO', 'ACCESSIBILITY', 'LANGUAGE', 'CONTROLLER CUSTOMIZER', 'BACK'}
    if title_screen:
        allowed.add('INSTALLED')
    ending = 'INSTALLED' if title_screen else 'BACK'
    if not items or items[0] != 'SOUND' or items[-1] != ending or any(x not in allowed for x in items):
        raise RuntimeError('Settings ordering cannot be established from OCR')
    if len(items) != len(set(items)) or 'CONTROLLER CUSTOMIZER' not in items:
        raise RuntimeError('Dedicated preset category missing or ambiguous')
    return items.index('CONTROLLER CUSTOMIZER')


def selected_preset(text):
    names = re.findall(r'\b(Current|Alt[1lI])\s*:', text)
    if len(names) != 1:
        raise RuntimeError('Preset row missing or ambiguous')
    return 'Current' if names[0] == 'Current' else 'Alt1'


SCHEMES = ('Current (original)', 'DarkSoul', 'DarkSoul Alt1')


def selected_scheme(text):
    names = re.findall(r'\bCurrent\s*\(original\)|\bDark\s*Soul\s*Alt\s*[1lI]\b|\bDark\s*Soul\b(?!\s*Alt)', text, re.I)
    if len(names) != 1:
        raise RuntimeError('Scheme row missing or ambiguous')
    normalized = re.sub(r'\s+', '', names[0]).casefold()
    if normalized == 'current(original)':
        return SCHEMES[0]
    return SCHEMES[2] if 'alt' in normalized else SCHEMES[1]


def cycle(desktop, target, directory, ffmpeg, inspect_preset=False, switch_preset=None, open_pause=None, inspect_diagram=False, switch_scheme=None, title_screen=False, menu_input=None):
    observations = []

    def capture(name, labels, full=False, validator=None, timeout=8):
        image = directory / (name + '.png')
        cropped = directory / (name + '-column.png')
        width, height = target['width'], target['height']
        region = f'crop={round(width * 560 / 2560)}:{round(height * 720 / 1440)}:{round(width * 150 / 2560)}:{round(height * 390 / 1440)}'
        deadline = time.monotonic() + timeout
        attempt = 0
        while True:
            desktop.guard(target)
            desktop.screenshot(target, image, ffmpeg, 'desktop')
            subprocess.run([ffmpeg, '-hide_banner', '-loglevel', 'error', '-y', '-i', str(image),
                            '-vf', region, '-frames:v', '1', str(cropped)], check=True,
                           capture_output=True, timeout=20, creationflags=subprocess.CREATE_NO_WINDOW)
            raw = read_ocr(image if full else cropped)
            (directory / (name + '-ocr.json')).write_text(json.dumps(raw, indent=2), encoding='utf-8')
            try:
                require_labels(raw['Text'], labels)
                if validator:
                    validator(raw)
                break
            except RuntimeError:
                shutil.copy2(image, directory / f'{name}-waiting-{attempt}.png')
                (directory / f'{name}-waiting-{attempt}.json').write_text(json.dumps(raw, indent=2), encoding='utf-8')
                if time.monotonic() >= deadline:
                    raise
                attempt += 1
                time.sleep(0.3)
        observations.append(dict(screen=name, screenshot=image.name, required_labels=labels))
        return raw

    def key(name):
        if menu_input:
            menu_input(name)
        else:
            desktop.key(target, name, 0.05 if name == 'ESC' else 0.15)
        time.sleep(0.5)
        desktop.guard(target)

    # Calibrated English pause menu defaults to Resume; no coordinate clicking.
    if title_screen:
        capture("title", ["Continue", "New Game", "Load Game", "Settings"])
    elif open_pause:
        open_pause()
        time.sleep(0.5)
    else:
        desktop.key(target, 'ESC', 0.15)
        time.sleep(0.5)
    if not title_screen:
        capture('pause', ['Resume', 'Load Game', 'Settings', 'Quit to Main Menu'])
    for _ in range(3):
        key('DOWN')
    key('E')
    settings = capture('settings', ['Sound', 'Video', 'Gameplay'],
                       validator=lambda raw: preset_index(raw['Lines'], title_screen), timeout=40)
    if inspect_preset or switch_preset or switch_scheme:
        for _ in range(preset_index(settings['Lines'], title_screen)):
            key('DOWN')
        key('E')
        capture('preset', ['Controller Customizer', 'Controller scheme' if switch_scheme else 'Hold: canter'], full=True)
        def read_selection(name):
            image = directory / (name + '.png')
            cropped = directory / (name + '-row.png')
            desktop.screenshot(target, image, ffmpeg, 'desktop')
            width, height = target['width'], target['height']
            region = f'crop={round(width * 1650 / 2560)}:{round(height * 160 / 1440)}:{round(width * 730 / 2560)}:{round(height * 190 / 1440)}'
            subprocess.run([ffmpeg, '-hide_banner', '-loglevel', 'error', '-y', '-i', str(image),
                            '-vf', region, '-frames:v', '1', str(cropped)], check=True,
                           capture_output=True, timeout=20, creationflags=subprocess.CREATE_NO_WINDOW)
            raw = read_ocr(cropped)
            (directory / (name + '-ocr.json')).write_text(json.dumps(raw, indent=2), encoding='utf-8')
            return selected_scheme(raw['Text'])

        if switch_scheme:
            current = read_selection('initial-scheme')
            desired = SCHEMES.index(switch_scheme)
            while SCHEMES.index(current) != desired:
                position = SCHEMES.index(current)
                direction = 1 if desired > position else -1
                key('RIGHT' if direction == 1 else 'LEFT')
                confirmed = read_selection('selected-scheme-' + str(position + direction))
                if SCHEMES.index(confirmed) != position + direction:
                    raise RuntimeError('Scheme row did not confirm exactly one requested step')
                current = confirmed
            observations.append(dict(screen='selected-scheme', preset=current))
        if switch_preset:
            key('RIGHT' if switch_preset == 'Alt1' else 'LEFT')
            image = directory / 'selected-preset.png'
            desktop.screenshot(target, image, ffmpeg, 'desktop')
            cropped = directory / 'selected-preset-row.png'
            width, height = target['width'], target['height']
            region = f'crop={round(width * 1650 / 2560)}:{round(height * 160 / 1440)}:{round(width * 730 / 2560)}:{round(height * 190 / 1440)}'
            subprocess.run([ffmpeg, '-hide_banner', '-loglevel', 'error', '-y', '-i', str(image),
                            '-vf', region, '-frames:v', '1', str(cropped)], check=True,
                           capture_output=True, timeout=20, creationflags=subprocess.CREATE_NO_WINDOW)
            raw = read_ocr(cropped)
            (directory / 'selected-preset-ocr.json').write_text(json.dumps(raw, indent=2), encoding='utf-8')
            if selected_preset(raw['Text']) != switch_preset:
                raise RuntimeError('Preset row did not confirm requested selection')
            observations.append(dict(screen='selected-preset', screenshot=image.name, preset=switch_preset))
        key('ESC')
        capture('return-settings', ['Sound', 'Video', 'Gameplay'])
    if inspect_diagram:
        preset_index(settings['Lines'], title_screen)  # Validate the entire recognized category ordering.
        items = settings_items(settings['Lines'])
        position = preset_index(settings['Lines'], title_screen) if (inspect_preset or switch_preset or switch_scheme) else 0
        distance = items.index('CONTROLLER SCHEME') - position
        for _ in range(abs(distance)):
            key('DOWN' if distance > 0 else 'UP')
        key('E')
        capture('controller-scheme', ['Controller Scheme', 'Exploration', 'Pause Menu'], full=True)
        for name, labels in [('swimming', ['Swimming']), ('combat', ['Combat']),
                             ('horse', ['Canter', 'Gallop'])]:
            key('RIGHT')
            capture('diagram-' + name, labels, full=True)
        key('ESC')
        capture('return-settings', ['Sound', 'Video', 'Gameplay'])
    key('ESC')
    if title_screen:
        capture('return-title', ['Continue', 'New Game', 'Load Game', 'Settings'])
    else:
        capture('return-pause', ['Resume', 'Load Game', 'Settings', 'Quit to Main Menu'])
        key('ESC')
    return observations


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--exe', required=True)
    parser.add_argument('--pid', type=int, required=True)
    parser.add_argument('--ready-gameplay', action='store_true')
    parser.add_argument('--ffmpeg', default='ffmpeg')
    parser.add_argument('--output', type=Path, default=Path(__file__).parent / 'evidence/menus')
    args = parser.parse_args()
    if not args.ready_gameplay:
        parser.error('Inspect gameplay with console closed before --ready-gameplay')
    directory = args.output.resolve() / (datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ') + '-' + uuid.uuid4().hex[:8])
    directory.mkdir(parents=True)
    report = dict(status='running', scope='settings_menu_cycle', gameplay_verified=False)
    try:
        desktop = Desktop()
        target = desktop.target(args.exe, args.pid)
        desktop.focus(target)
        report['target'] = target
        report['observations'] = cycle(desktop, target, directory, args.ffmpeg)
        report['status'] = 'menu_cycle_delivered'
    except Exception as error:
        report.update(status='failed', error=str(error))
    (directory / 'result.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
    print(directory / 'result.json')
    return 0 if report['status'] == 'menu_cycle_delivered' else 1


if __name__ == '__main__':
    raise SystemExit(main())
