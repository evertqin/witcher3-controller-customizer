"""Replay console probes and A/L3 gestures, capturing evidence without claiming gameplay pass."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import sys
import subprocess
import time
import uuid

from windows_ui import Desktop


def scenario_timeout(steps):
    switches = sum(step['kind'] in ('preset_switch', 'scheme_switch') for step in steps)
    diagrams = sum(step['kind'] == 'settings_diagram' for step in steps)
    return min(900, 180 + 30 * switches + 45 * diagrams)


def verify_journal(path):
    journal = json.loads(path.read_text(encoding='utf-8-sig'))
    if journal['Restored'] or not journal['InstallationComplete']:
        raise RuntimeError('Inactive installation journal')
    game = Path(journal['GamePath'])
    for item in journal['Items']:
        target = (game / item['RelativePath']).resolve()
        if not target.is_relative_to(game.resolve()):
            raise RuntimeError('Journal path escapes game directory')
        if hashlib.sha256(target.read_bytes()).hexdigest() != item['InstalledSha256']:
            raise RuntimeError(f'Owned file changed: {target}')
    if 'Phase11Candidate' in journal:
        from remove_scheme_aliases import remove_aliases
        migration = journal['Phase11Candidate']
        candidate = Path(migration['CandidateDirectory'])
        receipt = json.loads((candidate / 'candidate.json').read_text(encoding='utf-8'))
        appendix = (candidate / 'full-scheme-appendix.ini').read_bytes()
        if hashlib.sha256(appendix).hexdigest() != receipt['files']['full-scheme-appendix.ini']:
            raise RuntimeError('Owned full-scheme appendix changed')
        if 'registered_aliases_sha256' in receipt:
            appendix = (candidate / 'registered-aliases.ini').read_bytes()
            if hashlib.sha256(appendix).hexdigest() != receipt['registered_aliases_sha256']:
                raise RuntimeError('Registered alias ownership evidence changed')
        remove_aliases(Path(migration['InputPath']).read_bytes().decode('utf-8-sig'),
                       appendix.decode('utf-8'), receipt['aliases'])
    return journal


def validate_steps(steps):
    allowed = {'ccProbeLoaded()', 'ccProbeContexts()', 'ccProbeRideReset()', 'ccProbeRideStart()', 'ccProbeFallback()',
               'ccProbeRideStatus()', 'ccProbeFootStart()', 'ccProbeFootStatus()', 'ccProbeContextMode(true)',
               'ccProbeContextMode(false)', 'ccProbeDiagram(false)'}
    if not steps:
        raise ValueError('No probe steps')
    for step in steps:
        if step['kind'] == 'console':
            if step['command'] not in allowed:
                raise ValueError('Unsupported probe command')
        elif step['kind'] == 'gesture':
            if step['button'] not in ('A', 'L3', 'X', 'RB') or step['gesture'] not in ('hold', 'double_hold', 'press'):
                raise ValueError('Unsupported controller gesture')
        elif step['kind'] in ('settings_cycle', 'settings_inspect', 'settings_diagram', 'horse_stop', 'dismount', 'draw_sword'):
            if set(step) != {'kind'}:
                raise ValueError('Settings cycle does not accept extra actions')
        elif step['kind'] == 'scheme_switch':
            from menu_session import SCHEMES
            if set(step) != {'kind', 'preset'} or step['preset'] not in SCHEMES:
                raise ValueError('Unsupported scheme selection')
        elif step['kind'] == 'preset_switch':
            if set(step) != {'kind', 'preset'} or step['preset'] not in ('Current', 'Alt1'):
                raise ValueError('Unsupported preset selection')
        else:
            raise ValueError('Unsupported probe step')


def run(args):
    scenario = json.loads(args.scenario.read_text())
    steps = scenario['steps']
    validate_steps(steps)
    journal = verify_journal(args.journal)
    desktop = Desktop()
    target = desktop.target(args.exe, args.pid)
    directory = args.output.resolve() / (datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ')
                                         + '-' + uuid.uuid4().hex[:8])
    directory.mkdir(parents=True)
    report = {'status': 'running', 'gameplay_verified': False, 'steps': [],
              'pause_input_requested': args.pause_input,
              'target': target, 'scenario': scenario, 'cook_snapshot': journal['CookSnapshot'],
              'installed_hashes': {i['RelativePath']: i['InstalledSha256'] for i in journal['Items']}}
    pad = None
    console_open = False
    routing_touched = False
    console_sequence = 0
    try:
        desktop.focus(target)
        if any(s['kind'] == 'gesture' for s in steps) or (args.pause_input == 'controller' and
                any(s['kind'] in ('settings_cycle', 'settings_inspect', 'settings_diagram', 'preset_switch', 'scheme_switch') for s in steps)):
            import vgamepad as vg
            from gamepad import read_states
            before = set(read_states())
            pad = vg.VX360Gamepad()
            deadline = time.monotonic() + 5
            while len(set(read_states()) - before) != 1:
                desktop.guard(target)
                if time.monotonic() > deadline:
                    raise RuntimeError('Virtual controller attachment not confirmed')
                time.sleep(0.05)
            slot = (set(read_states()) - before).pop()
            report['virtual_controller_slot'] = slot
            buttons = {'A': vg.XUSB_BUTTON.XUSB_GAMEPAD_A,
                       'L3': vg.XUSB_BUTTON.XUSB_GAMEPAD_LEFT_THUMB,
                       'X': vg.XUSB_BUTTON.XUSB_GAMEPAD_X,
                       'RB': vg.XUSB_BUTTON.XUSB_GAMEPAD_RIGHT_SHOULDER}

        def pause(seconds):
            deadline = time.monotonic() + seconds
            while time.monotonic() < deadline:
                desktop.guard(target)
                time.sleep(0.01)

        def console(command):
            nonlocal console_open, console_sequence
            console_sequence += 1
            prefix = directory / f'console-{console_sequence:02d}'
            desktop.key(target, 'BACKTICK', 0.20)
            console_open = True
            pause(0.4)
            desktop.screenshot(target, prefix.with_name(prefix.name + '-open.png'), args.ffmpeg, 'desktop')
            desktop.text(target, command)
            typed = prefix.with_name(prefix.name + '-typed.png')
            desktop.screenshot(target, typed, args.ffmpeg, 'desktop')
            # Read only the calibrated current prompt, never console history.
            from assertions import read_ocr, parse_console_prompt
            cropped = prefix.with_name(prefix.name + '-prompt.png')
            width, height = target['width'], target['height']
            region = f'crop={round(width * 1000 / 2560)}:{round(height * 100 / 1440)}:0:{round(height * 280 / 1440)}'
            deadline = time.monotonic() + 8
            attempts = []
            while True:
                subprocess.run([args.ffmpeg, '-hide_banner', '-loglevel', 'error', '-y', '-i', str(typed),
                                '-vf', region, '-frames:v', '1', str(cropped)], check=True,
                               capture_output=True, timeout=20, creationflags=subprocess.CREATE_NO_WINDOW)
                ocr = read_ocr(cropped)
                attempts.append(ocr)
                prefix.with_name(prefix.name + '-prompt.json').write_text(json.dumps(attempts, indent=2), encoding='utf-8')
                try:
                    parse_console_prompt(ocr['Text'], command)
                    break
                except RuntimeError:
                    if time.monotonic() > deadline:
                        raise
                # Cursor blink can resemble a letter; inspect fresh pixels without new input.
                pause(0.25)
                desktop.screenshot(target, typed, args.ffmpeg, 'desktop')
            desktop.key(target, 'ENTER', 0.15)
            pause(0.4)
            desktop.key(target, 'BACKTICK', 0.15)
            console_open = False
            pause(0.4)

        def open_pause():
            button = vg.XUSB_BUTTON.XUSB_GAMEPAD_BACK
            try:
                pad.press_button(button)
                pad.update()
                pause(0.20)
                if read_states()[slot]['buttons'] != int(button):
                    raise RuntimeError('Pause controller readback mismatch')
            finally:
                pad.release_button(button)
                pad.update()
            pause(0.25)
            if read_states()[slot]['buttons'] != 0:
                raise RuntimeError('Pause controller release readback mismatch')

        for index, step in enumerate(steps):
            desktop.guard(target)
            if step['kind'] == 'console':
                if step['command'] == 'ccProbeContextMode(true)':
                    routing_touched = True
                console(step['command'])
            elif step['kind'] == 'draw_sword':
                from full_schemes import Record, parse
                if 'Phase11Candidate' not in journal:
                    raise RuntimeError('Sword-draw fixture requires owned schema-2 input')
                profile = Path(journal['Phase11Candidate']['InputPath'])
                contexts = parse(profile.read_bytes().decode('utf-8-sig'))
                required = Record('IK_1', '(Action=SteelSword)', 0).signature
                if not all(required in {r.signature for r in contexts[c]} for c in ('Exploration', 'Combat')):
                    raise RuntimeError('Native sword-draw fixture key changed; input refused')
                desktop.key(target, '1', 0.15)
                pause(2.5)
            elif step['kind'] == 'dismount':
                # Native keyboard hold is preserved across all three scheme aliases.
                desktop.key(target, 'E', 1.5)
                pause(2.0)
            elif step['kind'] == 'horse_stop':
                # Pinned personal Horse aliases retain native IK_X=(Action=Stop).
                desktop.key(target, 'X', 1.0)
                pause(1.0)
            elif step['kind'] in ('settings_cycle', 'settings_inspect', 'settings_diagram', 'preset_switch', 'scheme_switch'):
                from menu_session import cycle
                menu_directory = directory / f'{index:02d}-menus'
                menu_directory.mkdir()
                menu_observations = cycle(desktop, target, menu_directory, args.ffmpeg,
                                          inspect_preset=step['kind'] == 'settings_inspect',
                                          switch_preset=step.get('preset') if step['kind'] == 'preset_switch' else None,
                                          switch_scheme=step.get('preset') if step['kind'] == 'scheme_switch' else None,
                                          inspect_diagram=step['kind'] == 'settings_diagram',
                                          open_pause=open_pause if pad is not None and args.pause_input == 'controller' else None)
            else:
                button = buttons[step['button']]
                if step['gesture'] == 'double_hold':
                    pad.press_button(button)
                    pad.update()
                    pause(0.08)
                    pad.release_button(button)
                    pad.update()
                    pause(0.10)
                pad.press_button(button)
                pad.update()
                pause(0.15 if step['gesture'] == 'press' else 1.0)
                pressed = read_states()[slot]['buttons']
                if pressed != int(button):
                    raise RuntimeError('Controller readback mismatch')
                pad.release_button(button)
                pad.update()
                pause(0.25)
                if read_states()[slot]['buttons'] != 0:
                    raise RuntimeError('Controller release readback mismatch')
            screenshot = directory / f'{index:02d}-{step["kind"]}.png'
            desktop.screenshot(target, screenshot, args.ffmpeg, "desktop")
            if step.get('command') in ('ccProbeRideReset()', 'ccProbeFootStart()'):
                from assertions import read_ocr
                deadline = time.monotonic() + 8
                ack = 'cc foot counters reset' if step['command'] == 'ccProbeFootStart()' else 'cc ride counters reset'
                while ack not in read_ocr(screenshot)['Text'].casefold():
                    if time.monotonic() > deadline:
                        raise RuntimeError('Counter reset acknowledgement missing; gestures refused')
                    pause(0.25)
                    desktop.screenshot(target, screenshot, args.ffmpeg, 'desktop')
            entry = dict(step, screenshot=screenshot.name, status='delivered')
            if step['kind'] in ('settings_cycle', 'settings_inspect', 'settings_diagram', 'preset_switch', 'scheme_switch'):
                entry['menu_observations'] = menu_observations
                entry['pause_input'] = 'controller' if pad is not None and args.pause_input == 'controller' else 'keyboard'
            report['steps'].append(entry)
            if step.get('expected_context') or step.get('expected_foot_scheme'):
                from assertions import read_ocr, parse_ride, parse_foot
                cropped = directory / f'{index:02d}-ride-crop.png'
                width, height = target['width'], target['height']
                region = f'crop={round(width * 800 / 2560)}:{round(height * 420 / 1440)}:{round(width * 80 / 2560)}:{round(height * 1000 / 1440)},scale=1600:840'
                if step.get('expected_foot_scheme'):
                    region = f'crop={round(width * 1000 / 2560)}:{round(height * 190 / 1440)}:{round(width * 110 / 2560)}:{round(height * 1210 / 1440)},scale=2000:380'
                deadline = time.monotonic() + 8
                attempt = 0
                while True:
                    subprocess.run([args.ffmpeg, '-hide_banner', '-loglevel', 'error', '-y', '-i', str(screenshot),
                                    '-vf', region, '-frames:v', '1', str(cropped)], check=True,
                                   capture_output=True, timeout=20, creationflags=subprocess.CREATE_NO_WINDOW)
                    ocr = read_ocr(cropped)
                    (directory / f'{index:02d}-ocr.json').write_text(json.dumps(ocr, indent=2), encoding='utf-8')
                    try:
                        entry['assertion'] = (parse_foot(ocr['Text'], step['expected_foot_scheme'])
                                              if step.get('expected_foot_scheme') else
                                              parse_ride(ocr['Text'], step['expected_context']))
                        break
                    except RuntimeError as error:
                        # Retry unreadable frames only; semantic counter failures stop immediately.
                        if not str(error).startswith('Notification assertion missing/ambiguous') or time.monotonic() > deadline:
                            raise
                    (directory / f'{index:02d}-ride-waiting-{attempt}.png').write_bytes(screenshot.read_bytes())
                    (directory / f'{index:02d}-ride-waiting-{attempt}.json').write_text(json.dumps(ocr, indent=2), encoding='utf-8')
                    attempt += 1
                    pause(0.25)
                    desktop.screenshot(target, screenshot, args.ffmpeg, 'desktop')
            if step.get('command') == 'ccProbeFallback()':
                from assertions import read_ocr, parse_fallback
                cropped = directory / f'{index:02d}-fallback-crop.png'
                width, height = target['width'], target['height']
                region = f'crop={round(width * 620 / 2560)}:{round(height * 90 / 1440)}:{round(width * 110 / 2560)}:{round(height * 1280 / 1440)},scale=1860:270'
                subprocess.run([args.ffmpeg, '-hide_banner', '-loglevel', 'error', '-y', '-i', str(screenshot),
                                '-vf', region, '-frames:v', '1', str(cropped)], check=True,
                               capture_output=True, timeout=20, creationflags=subprocess.CREATE_NO_WINDOW)
                ocr = read_ocr(cropped)
                (directory / f'{index:02d}-ocr.json').write_text(json.dumps(ocr, indent=2), encoding='utf-8')
                entry['assertion'] = parse_fallback(ocr['Text'])
        verify_journal(args.journal)
        report['status'] = 'evidence_collected'
    except Exception as error:
        report.update(status='failed', error=str(error))
        if ('Menu boundary not recognized' in str(error) or
                str(error).startswith(('Notification assertion', 'Unbalanced native',
                                       'Unexpected callback', 'Callback totals', 'Wrong riding'))):
            try:
                console('ccProbeMenuState()')
                screenshot = directory / 'failure-menu-state.png'
                desktop.screenshot(target, screenshot, args.ffmpeg, 'desktop')
                from assertions import read_ocr
                report['failure_menu_state'] = read_ocr(screenshot)
            except Exception as diagnostic_error:
                report['diagnostic_error'] = str(diagnostic_error)
    finally:
        if pad is not None:
            pad.reset()
            pad.update()
            del pad
        # Only restore console/routing while the same process retains foreground.
        try:
            desktop.guard(target)
            if console_open:
                desktop.key(target, 'BACKTICK')
            if routing_touched:
                console('ccProbeContextMode(false)')
                report['routing_disable_command_delivered'] = True
        except Exception as error:
            report['cleanup_warning'] = str(error) + '; routing resets on full restart'
        (directory / 'result.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
    print(str(directory / 'result.json'))
    return 0 if report['status'] == 'evidence_collected' else 1


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('scenario', type=Path)
    parser.add_argument('--journal', type=Path, required=True)
    parser.add_argument('--exe', required=True)
    parser.add_argument('--pid', type=int, required=True)
    parser.add_argument('--ready-console-closed', action='store_true')
    parser.add_argument('--pause-input', choices=('controller', 'keyboard'), default='controller')
    parser.add_argument('--ffmpeg', default='ffmpeg')
    parser.add_argument('--output', type=Path, default=Path(__file__).parent / 'evidence/probes')
    args = parser.parse_args()
    if not args.ready_console_closed:
        parser.error('Inspect loaded gameplay first; then supply --ready-console-closed')
    sys.path.insert(0, str(Path(__file__).parent / 'vendor'))
    return run(args)


if __name__ == '__main__':
    sys.exit(main())
