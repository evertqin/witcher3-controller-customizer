"""Own a fresh game process, load a pinned visible save, replay probes, and close."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys
import time
import uuid

from assertions import read_ocr
from menu_session import require_labels
from probe_session import verify_journal, validate_steps, scenario_timeout
from windows_ui import Desktop


def matches_fixture(text, fixture=None):
    pattern = fixture['row_pattern'] if fixture else r'An Invitation from Keira Metz\s*[-–]\s*Sunday,\s*October\s+1\s*1,\s*2026\s+7:10:06\s+AM'
    return bool(re.search(pattern, text, re.I)
                and 'manual save slot' in text.casefold())


def load_fixture(path):
    fixture = json.loads(path.read_text(encoding='utf-8'))
    name = fixture.get('save_name', '')
    if not isinstance(name, str) or Path(name).name != name or not name.startswith('ManualSave_') or not name.endswith('.sav'):
        raise ValueError('Fixture requires one manual-save filename')
    if not isinstance(fixture.get('sha256'), str) or not re.fullmatch('[0-9a-f]{64}', fixture['sha256']):
        raise ValueError('Fixture requires a pinned SHA-256')
    pattern = fixture.get('row_pattern')
    labels = fixture.get('hud_labels')
    if not isinstance(pattern, str) or not pattern.strip():
        raise ValueError('Fixture requires a visible save-row pattern')
    re.compile(pattern)
    if not isinstance(labels, list) or not labels or any(not isinstance(label, str) or not label.strip() for label in labels):
        raise ValueError('Fixture requires nonempty gameplay HUD labels')
    return fixture


def ffmpeg_image(ffmpeg, image, filter_value, output=None):
    argv = [ffmpeg, '-hide_banner', '-loglevel', 'error', '-y', '-i', str(image),
            '-vf', filter_value, '-frames:v', '1']
    argv += [str(output)] if output else ['-f', 'rawvideo', 'pipe:1']
    return subprocess.run(argv, capture_output=True, check=True, timeout=20,
                          creationflags=subprocess.CREATE_NO_WINDOW).stdout


def highlighted(ffmpeg, image, index):
    # Calibrated 2560x1440 English save list. Border absent on unselected rows.
    y = 246 + round(index * 250 / 3)
    pixels = ffmpeg_image(ffmpeg, image, f'crop=14:40:740:{y},format=gray')
    return any(sum(value >= 70 for value in pixels[column::14]) >= 36 for column in range(14))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('scenario', type=Path, nargs='?')
    parser.add_argument('--journal', type=Path, required=True)
    parser.add_argument('--exe', type=Path, required=True)
    parser.add_argument('--save', type=Path, required=True)
    parser.add_argument('--fixture', type=Path, help='Explicit pinned save filename/hash, visible row pattern and HUD labels')
    parser.add_argument('--ffmpeg', required=True)
    parser.add_argument('--title-only', action='store_true', help='Switch scheme and inspect diagram in the same title Settings instance, without loading')
    parser.add_argument('--pause-input', choices=('controller', 'keyboard'), default='controller')
    parser.add_argument('--output', type=Path, default=Path(__file__).parent / 'evidence/game-tests')
    args = parser.parse_args()
    installed = verify_journal(args.journal)
    if args.scenario is None:
        filename = 'phase11-smoke.json' if 'Phase11Candidate' in installed else 'phase1-smoke.json'
        args.scenario = Path(__file__).with_name(filename)
    scenario = json.loads(args.scenario.read_text(encoding='utf-8'))
    validate_steps(scenario['steps'])
    verify_journal(args.journal)
    save_hash = hashlib.sha256(args.save.read_bytes()).hexdigest()
    fixture = load_fixture(args.fixture) if args.fixture else None
    expected_hash = fixture['sha256'] if fixture else '1b32a68488aa519fc7a9924d957029cf17de5ed32a49a1edd03f16c758d0c77d'
    if save_hash != expected_hash or (fixture and args.save.name != fixture['save_name']):
        parser.error('Save filename/hash differs from the explicitly pinned fixture')
    desktop = Desktop()
    if desktop.windows(args.exe):
        parser.error('Existing game window; close it before an owned fresh launch')
    directory = args.output.resolve() / (datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ') + '-' + uuid.uuid4().hex[:8])
    directory.mkdir(parents=True)
    report = dict(status='running', save=str(args.save), save_sha256=save_hash,
                  scope='pinned_fixture_and_native_callback_replay', gameplay_verified=False,
                  fixture=fixture)
    process = None
    target = None
    try:
        process = subprocess.Popen([str(args.exe)], cwd=str(args.exe.parent))
        report['owned_pid'] = process.pid
        deadline = time.monotonic() + 120
        while time.monotonic() < deadline:
            if process.poll() is not None:
                raise RuntimeError('Game exited before main menu')
            windows = desktop.windows(args.exe, process.pid)
            if not windows:
                time.sleep(1)
                continue
            try:
                target = desktop.target(args.exe, process.pid, 'The Witcher 3')
                desktop.focus(target, owned_startup=True)
            except RuntimeError as error:
                # Keep actual window/focus diagnostics; do not turn missing frames into a gameplay verdict.
                event = dict(error=str(error), windows=windows,
                             minimized=[bool(desktop.user.IsIconic(w['hwnd'])) for w in windows])
                report.setdefault('startup_window_events', []).append(event)
                (directory / 'startup-window-events.json').write_text(
                    json.dumps(report['startup_window_events'], indent=2), encoding='utf-8')
                time.sleep(1)
                continue
            try:
                desktop.screenshot(target, directory / 'startup.png', args.ffmpeg, 'desktop')
            except RuntimeError as error:
                report.setdefault('startup_window_events', []).append(dict(error=str(error), stage='owned_startup_capture'))
                time.sleep(1)
                continue
            raw = read_ocr(directory / 'startup.png')
            text = raw['Text']
            if all(label in text.casefold() for label in ['continue', 'new game', 'load game', 'settings']):
                break
            if re.search(r'Space\s+Skip', text, re.I):
                desktop.key(target, 'SPACE', 0.15)
            time.sleep(1)
        else:
            raise RuntimeError('Main menu not recognized within startup timeout')
        if (target['width'], target['height']) != (2560, 1440):
            raise RuntimeError('Save-list calibration requires 2560x1440')
        if args.title_only:
            from menu_session import cycle, SCHEMES
            desired = scenario.get('title_scheme', SCHEMES[0])
            if desired not in SCHEMES:
                raise ValueError('Unsupported title scheme')
            from gamepad import menu_controller, press_menu_button
            with menu_controller(desktop, target) as (pad, slot):
                report['virtual_controller_slot'] = slot
                report['observations'] = cycle(desktop, target, directory, args.ffmpeg, switch_scheme=desired, inspect_diagram=True, title_screen=True,
                    menu_input=lambda key: press_menu_button(desktop, target, pad, slot, key))
            report['scope'] = 'title_same_settings_diagram_refresh'
            report['status'] = 'evidence_collected'
        if not args.title_only:
            for key in ['DOWN', 'DOWN', 'E']:
                desktop.key(target, key, 0.05 if key == 'DOWN' else 0.15)
                time.sleep(0.5)
            image = directory / 'save-list.png'
            desktop.screenshot(target, image, args.ffmpeg, 'desktop')
            require_labels(read_ocr(image)['Text'], ['Load game', 'Delete saved game'])
            if not highlighted(args.ffmpeg, image, 0):
                raise RuntimeError('Save list did not start with the first row selected')

            def move_selection(previous, next_row, key, capture):
                # DirectInput can miss a tap; retry only when the old border is still proven.
                for attempt in range(3):
                    desktop.key(target, key, 0.15)
                    deadline = time.monotonic() + 1.5
                    while True:
                        time.sleep(0.3)
                        desktop.screenshot(target, capture, args.ffmpeg, 'desktop')
                        if highlighted(args.ffmpeg, capture, next_row):
                            return
                        if not highlighted(args.ffmpeg, capture, previous):
                            raise RuntimeError('Save selection moved outside calibrated visible rows')
                        if time.monotonic() >= deadline:
                            break
                    (capture.parent / f'{capture.stem}-missed-{attempt}.png').write_bytes(capture.read_bytes())
                raise RuntimeError('Save navigation tap was not acknowledged')

            matches = []
            for index in range(11):
                image = directory / f'save-selection-{index:02d}.png'
                if index:
                    move_selection(index - 1, index, 'DOWN', image)
                else:
                    desktop.screenshot(target, image, args.ffmpeg, 'desktop')
                if not highlighted(args.ffmpeg, image, index):
                    raise RuntimeError('Save selection moved outside calibrated visible rows')
                row = directory / f'save-row-{index:02d}.png'
                y = 215 + round(index * 250 / 3)
                ffmpeg_image(args.ffmpeg, image, f'crop=1400:90:750:{y},scale=2800:180', row)
                raw = read_ocr(row)
                (row.with_suffix('.json')).write_text(json.dumps(raw, indent=2), encoding='utf-8')
                if matches_fixture(raw['Text'], fixture):
                    matches.append(index)
            if len(matches) > 1:
                raise RuntimeError('Exact fixture is ambiguous in visible save rows')
            scrolls = 0
            if matches:
                index = matches[0]
                for current in range(10, index, -1):
                    move_selection(current, current - 1, 'UP', directory / f'selected-up-{current:02d}.png')
            else:
                # Beyond the first visible page, Down keeps the selection on row 10
                # and scrolls one save. Require changed row pixels before proceeding;
                # only the exact pinned manual timestamp can authorize loading.
                index = 10
                previous_pixels = ffmpeg_image(args.ffmpeg, image,
                    'crop=1400:90:750:1048,format=gray')
                limit = min(200, len(list(args.save.parent.glob('*.sav'))))
                for scrolls in range(1, limit + 1):
                    image = directory / f'save-scroll-{scrolls:03d}.png'
                    row = directory / f'save-scroll-row-{scrolls:03d}.png'
                    advanced = False
                    for attempt in range(3):
                        desktop.key(target, 'DOWN', 0.15)
                        deadline = time.monotonic() + 1.5
                        while time.monotonic() < deadline:
                            time.sleep(0.3)
                            desktop.screenshot(target, image, args.ffmpeg, 'desktop')
                            if not highlighted(args.ffmpeg, image, index):
                                raise RuntimeError('Paged save selection left the calibrated last row')
                            pixels = ffmpeg_image(args.ffmpeg, image,
                                'crop=1400:90:750:1048,format=gray')
                            if pixels != previous_pixels:
                                advanced = True
                                previous_pixels = pixels
                                break
                        if advanced:
                            break
                    if not advanced:
                        raise RuntimeError('Save list did not advance; end reached or input unacknowledged')
                    ffmpeg_image(args.ffmpeg, image, 'crop=1400:90:750:1048,scale=2800:180', row)
                    raw = read_ocr(row)
                    row.with_suffix('.json').write_text(json.dumps(raw, indent=2), encoding='utf-8')
                    if matches_fixture(raw['Text'], fixture):
                        break
                else:
                    raise RuntimeError('Exact pinned fixture not found within bounded save paging')
            report['save_list_scrolls'] = scrolls
            selected = directory / 'selected-save.png'
            desktop.screenshot(target, selected, args.ffmpeg, 'desktop')
            if not highlighted(args.ffmpeg, selected, index):
                raise RuntimeError('Requested save selection border not confirmed')
            selected_row = directory / 'selected-save-row.png'
            ffmpeg_image(args.ffmpeg, selected, f'crop=1400:90:750:{215 + round(index * 250 / 3)},scale=2800:180', selected_row)
            selected_ocr = read_ocr(selected_row)
            (directory / 'selected-save-ocr.json').write_text(json.dumps(selected_ocr, indent=2), encoding='utf-8')
            if not matches_fixture(selected_ocr['Text'], fixture):
                raise RuntimeError('Final selected timestamp no longer matches fixture')
            report['selected_save_row'] = index
            desktop.key(target, 'E', 0.15)
            deadline = time.monotonic() + 120
            while time.monotonic() < deadline:
                desktop.guard(target)
                desktop.screenshot(target, directory / 'loaded.png', args.ffmpeg, 'desktop')
                text = read_ocr(directory / 'loaded.png')['Text'].casefold()
                labels = fixture['hud_labels'] if fixture else ['an invitation from keira metz', 'talk to keira']
                if all(label.casefold() in text for label in labels):
                    break
                time.sleep(1)
            else:
                raise RuntimeError('Fixture gameplay HUD not recognized')
            command = [sys.executable, str(Path(__file__).with_name('probe_session.py')),
                       str(args.scenario.resolve()), '--journal', str(args.journal), '--exe', str(args.exe),
                       '--pid', str(process.pid), '--ready-console-closed', '--ffmpeg', args.ffmpeg,
                       '--pause-input', args.pause_input,
                       '--output', str(directory / 'probes')]
            child = subprocess.run(command, capture_output=True, text=True, timeout=scenario_timeout(scenario['steps']))
            (directory / 'probe.log').write_text(child.stdout + child.stderr, encoding='utf-8')
            if child.returncode:
                raise RuntimeError('Probe scenario failed; inspect probe.log and nested evidence')
            receipts = list((directory / 'probes').glob('*/result.json'))
            if len(receipts) != 1:
                raise RuntimeError('Expected one fresh probe receipt')
            report['probe_receipt'] = str(receipts[0])
            report['status'] = 'evidence_collected'
    except Exception as error:
        report.update(status='failed', error=str(error))
    finally:
        if process is not None and process.poll() is None:
            try:
                # Fullscreen focus loss can temporarily hide the owned window.
                matches = desktop.windows(args.exe, process.pid,
                                          'The Witcher 3', include_hidden=True)
                if len(matches) != 1:
                    raise RuntimeError('Owned close window missing or ambiguous')
                target = matches[0]
                desktop.identity_guard(target)
                if not desktop.user.PostMessageW(target['hwnd'], 0x10, 0, 0):
                    raise RuntimeError('Native close request failed')
                process.wait(timeout=20)
            except Exception as error:
                report['close_warning'] = str(error)
        report['owned_game_closed'] = process is not None and process.poll() is not None
        report['save_unchanged'] = hashlib.sha256(args.save.read_bytes()).hexdigest() == save_hash
        if not report['save_unchanged'] or not report['owned_game_closed']:
            report['status'] = 'failed'
        (directory / 'result.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
    print(directory / 'result.json')
    return 0 if report['status'] == 'evidence_collected' else 1


if __name__ == '__main__':
    raise SystemExit(main())
