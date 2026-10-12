"""ViGEm Xbox controller adapter with independent XInput verification."""
import argparse
from contextlib import contextmanager
import ctypes as C
from datetime import datetime, timezone
import json
from pathlib import Path
import sys
import time

sys.path.insert(0, str(Path(__file__).parent / 'vendor'))


class PadState(C.Structure):
    _fields_ = [('buttons', C.c_uint16), ('left_trigger', C.c_uint8),
                ('right_trigger', C.c_uint8), ('lx', C.c_int16), ('ly', C.c_int16),
                ('rx', C.c_int16), ('ry', C.c_int16)]


class State(C.Structure):
    _fields_ = [('packet', C.c_uint32), ('pad', PadState)]


def read_states():
    dll = C.WinDLL('xinput1_4.dll')
    dll.XInputGetState.argtypes = [C.c_uint32, C.POINTER(State)]
    dll.XInputGetState.restype = C.c_uint32
    result = {}
    for index in range(4):
        state = State()
        if dll.XInputGetState(index, C.byref(state)) == 0:
            result[index] = {'buttons':state.pad.buttons, 'packet':state.packet,
                             'rx':state.pad.rx, 'ry':state.pad.ry}
    return result



def press_menu_button(desktop, target, pad, slot, key):
    import vgamepad as vg
    names = {'DOWN': 'XUSB_GAMEPAD_DPAD_DOWN', 'UP': 'XUSB_GAMEPAD_DPAD_UP',
             'LEFT': 'XUSB_GAMEPAD_DPAD_LEFT', 'RIGHT': 'XUSB_GAMEPAD_DPAD_RIGHT',
             'E': 'XUSB_GAMEPAD_A', 'ESC': 'XUSB_GAMEPAD_B'}
    button = getattr(vg.XUSB_BUTTON, names[key])
    try:
        desktop.guard(target)
        pad.press_button(button)
        pad.update()
        deadline = time.monotonic() + 0.15
        while time.monotonic() < deadline:
            desktop.guard(target)
            time.sleep(0.01)
        if read_states()[slot]['buttons'] != int(button):
            raise RuntimeError('Menu controller readback mismatch')
    finally:
        pad.release_button(button)
        pad.update()
    time.sleep(0.25)
    desktop.guard(target)
    if read_states()[slot]['buttons'] != 0:
        raise RuntimeError('Menu controller release readback mismatch')


@contextmanager
def menu_controller(desktop, target):
    import vgamepad as vg
    before = set(read_states())
    pad = vg.VX360Gamepad()
    try:
        deadline = time.monotonic() + 5
        while len(set(read_states()) - before) != 1:
            desktop.guard(target)
            if time.monotonic() > deadline:
                raise RuntimeError('Menu controller attachment not confirmed')
            time.sleep(0.05)
        slot = (set(read_states()) - before).pop()
        yield pad, slot
    finally:
        pad.reset()
        pad.update()
        del pad


def selftest():
    import vgamepad as vg
    before = read_states()
    if len(before) == 4:
        raise RuntimeError('All four XInput slots occupied')
    pad = vg.VX360Gamepad()
    records = []
    try:
        deadline = time.monotonic() + 5
        while True:
            attached = read_states()
            added = set(attached) - set(before)
            if len(added) == 1:
                index = added.pop()
                break
            if time.monotonic() > deadline:
                raise RuntimeError('Could not identify exactly one new XInput slot')
            time.sleep(0.05)
        pad.reset()
        pad.update()
        for label, button, expected in [('A',vg.XUSB_BUTTON.XUSB_GAMEPAD_A,0x1000),
                                       ('L3',vg.XUSB_BUTTON.XUSB_GAMEPAD_LEFT_THUMB,0x0040)]:
            pad.press_button(button)
            pad.update()
            time.sleep(0.15)
            pressed = read_states().get(index, {}).get('buttons')
            if pressed != expected:
                raise RuntimeError(f'{label} readback mismatch: {pressed}')
            pad.release_button(button)
            pad.update()
            time.sleep(0.15)
            released = read_states().get(index, {}).get('buttons')
            if released != 0:
                raise RuntimeError(f'{label} release mismatch: {released}')
            records.append({'button':label,'pressed_bits':pressed,'released_bits':released})
    finally:
        pad.reset()
        pad.update()
        del pad
    time.sleep(0.2)
    if index in read_states():
        raise RuntimeError('Virtual controller did not detach')
    return {'status':'passed','scope':'driver_and_XInput_only', 'gameplay_verified':False,
            'utc':datetime.now(timezone.utc).isoformat(), 'slot':index,
            'checks':records,'detached':True}


def sequence(path, exe, pid):
    import vgamepad as vg
    from windows_ui import Desktop
    desktop = Desktop()
    target = desktop.target(exe, pid)
    desktop.focus(target)
    actions = json.loads(Path(path).read_text())
    buttons = {'A':vg.XUSB_BUTTON.XUSB_GAMEPAD_A,'L3':vg.XUSB_BUTTON.XUSB_GAMEPAD_LEFT_THUMB}
    for action in actions:
        if action['button'] not in buttons or not 0 < action['seconds'] <= 10:
            raise ValueError('Invalid button/duration')
        if action['kind'] not in ('down','up','wait'):
            raise ValueError('Invalid action kind')
    pad = vg.VX360Gamepad()
    try:
        for action in actions:
            desktop.guard(target)
            if action['kind'] == 'down':
                pad.press_button(buttons[action['button']])
            elif action['kind'] == 'up':
                pad.release_button(buttons[action['button']])
            pad.update()
            until = time.monotonic() + action['seconds']
            while time.monotonic() < until:
                desktop.guard(target)
                time.sleep(0.01)
    finally:
        pad.reset()
        pad.update()
        del pad
    return {'status':'input_delivered','gameplay_verified':False}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--self-test',action='store_true')
    parser.add_argument('--sequence',type=Path)
    parser.add_argument('--exe')
    parser.add_argument('--pid',type=int)
    parser.add_argument('--output',type=Path)
    args = parser.parse_args()
    if args.self_test:
        result = selftest()
    elif args.sequence and args.exe and args.pid:
        result = sequence(args.sequence,args.exe,args.pid)
    else:
        parser.error('Supply --self-test or --sequence with --exe and --pid')
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(result,indent=2),encoding='utf-8')
    print(json.dumps(result,indent=2))


if __name__ == '__main__':
    main()
