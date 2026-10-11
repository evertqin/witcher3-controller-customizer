"""Small Windows UI adapter: explicit executable/PID, guarded input, window capture."""
import argparse
import ctypes as C
from ctypes import wintypes as W
import json
import os
from pathlib import Path
import subprocess
import time


class KeyboardInput(C.Structure):
    _fields_ = [("vk", W.WORD), ("scan", W.WORD), ("flags", W.DWORD),
                ("time", W.DWORD), ("extra", C.c_size_t)]


class MouseInput(C.Structure):
    _fields_ = [("x", W.LONG), ("y", W.LONG), ("data", W.DWORD),
                ("flags", W.DWORD), ("time", W.DWORD), ("extra", C.c_size_t)]


class InputData(C.Union):
    _fields_ = [("keyboard", KeyboardInput), ("mouse", MouseInput)]


class Input(C.Structure):
    _fields_ = [("kind", W.DWORD), ("data", InputData)]


class Desktop:
    def __init__(self):
        if os.name != "nt":
            raise RuntimeError("Windows interactive desktop required")
        self.user = C.WinDLL("user32", use_last_error=True)
        self.kernel = C.WinDLL("kernel32", use_last_error=True)
        self.user.SetProcessDPIAware()
        self.user.GetForegroundWindow.restype = W.HWND
        self.user.GetWindowThreadProcessId.argtypes = [W.HWND, C.POINTER(W.DWORD)]
        self.user.GetWindowTextLengthW.argtypes = [W.HWND]
        self.user.GetWindowTextW.argtypes = [W.HWND, W.LPWSTR, C.c_int]
        self.user.IsWindowVisible.argtypes = [W.HWND]
        self.user.IsIconic.argtypes = [W.HWND]
        self.user.SetForegroundWindow.argtypes = [W.HWND]
        self.user.GetClientRect.argtypes = [W.HWND, C.POINTER(W.RECT)]
        self.user.ClientToScreen.argtypes = [W.HWND, C.POINTER(W.POINT)]
        self.kernel.OpenProcess.argtypes = [W.DWORD, W.BOOL, W.DWORD]
        self.kernel.OpenProcess.restype = W.HANDLE
        self.kernel.QueryFullProcessImageNameW.argtypes = [W.HANDLE, W.DWORD, W.LPWSTR, C.POINTER(W.DWORD)]
        self.kernel.CloseHandle.argtypes = [W.HANDLE]
        self.user.VkKeyScanW.argtypes = [W.WCHAR]
        self.user.VkKeyScanW.restype = C.c_short
        self.user.MapVirtualKeyW.argtypes = [W.UINT, W.UINT]
        self.user.MapVirtualKeyW.restype = W.UINT
        self.user.keybd_event.argtypes = [W.BYTE, W.BYTE, W.DWORD, C.c_size_t]
        self.user.SendInput.argtypes = [W.UINT, C.POINTER(Input), C.c_int]
        self.user.SendInput.restype = W.UINT
        self.user.mouse_event.argtypes = [W.DWORD, W.DWORD, W.DWORD, W.DWORD, C.c_size_t]
        self.user.SetCursorPos.argtypes = [C.c_int, C.c_int]
        self.user.GetMenu.argtypes = [W.HWND]
        self.user.GetMenu.restype = W.HMENU
        self.user.GetSubMenu.argtypes = [W.HMENU, C.c_int]
        self.user.GetSubMenu.restype = W.HMENU
        self.user.GetMenuItemCount.argtypes = [W.HMENU]
        self.user.GetMenuStringW.argtypes = [W.HMENU, W.UINT, W.LPWSTR, C.c_int, W.UINT]
        self.user.GetMenuItemID.argtypes = [W.HMENU, C.c_int]
        self.user.GetMenuItemID.restype = W.UINT
        self.user.PostMessageW.argtypes = [W.HWND, W.UINT, W.WPARAM, W.LPARAM]
        self.user.GetClassNameW.argtypes = [W.HWND, W.LPWSTR, C.c_int]
        self.user.SendMessageW.argtypes = [W.HWND, W.UINT, W.WPARAM, W.LPARAM]
        self.user.SendMessageW.restype = W.LPARAM

    def native_value(self, window, automation_id, text, script):
        process = subprocess.run(["powershell.exe", "-NoProfile", "-ExecutionPolicy", "Bypass",
                                  "-File", str(script), "-TargetProcessId", str(window["pid"]),
                                  "-Action", "Inspect"], capture_output=True, text=True,
                                 timeout=20, creationflags=subprocess.CREATE_NO_WINDOW)
        if process.returncode:
            raise RuntimeError(process.stderr)
        found = []
        for control in json.loads(process.stdout):
            if control["AutomationId"] != automation_id or not control["Enabled"] or control["Offscreen"]:
                continue
            handle = control["Handle"]
            kind = C.create_unicode_buffer(256)
            self.user.GetClassNameW(handle, kind, len(kind))
            if kind.value == "Edit":
                found.append(handle)
        if len(found) != 1:
            raise RuntimeError("Expected one enabled native Edit with exact AutomationId")
        owner = W.DWORD()
        self.user.GetWindowThreadProcessId(found[0], C.byref(owner))
        self.identity_guard(window)
        if owner.value != window["pid"]:
            raise RuntimeError("Edit process identity mismatch")
        buffer = C.create_unicode_buffer(text)
        if not self.user.SendMessageW(found[0], 0xC, 0, C.cast(buffer, C.c_void_p).value):
            raise RuntimeError("Edit refused WM_SETTEXT")
        value = C.create_unicode_buffer(self.user.SendMessageW(found[0], 0xE, 0, 0) + 1)
        self.user.SendMessageW(found[0], 0xD, len(value), C.cast(value, C.c_void_p).value)
        if value.value != text:
            raise RuntimeError("Edit value readback mismatch")

    def menus(self, window):
        result = []

        def visit(menu, prefix):
            for index in range(self.user.GetMenuItemCount(menu)):
                buffer = C.create_unicode_buffer(512)
                self.user.GetMenuStringW(menu, index, buffer, len(buffer), 0x400)
                text = buffer.value.replace("&", "").split("\t")[0]
                if not text:
                    continue
                path = prefix + [text]
                child = self.user.GetSubMenu(menu, index)
                if child:
                    visit(child, path)
                else:
                    result.append({"path": "/".join(path), "id": self.user.GetMenuItemID(menu, index)})

        menu = self.user.GetMenu(window["hwnd"])
        if menu:
            visit(menu, [])
        return result

    def menu_invoke(self, window, path):
        matches = [m for m in self.menus(window) if m["path"] == path]
        if len(matches) != 1:
            raise RuntimeError("Expected one exact native menu path")
        self.identity_guard(window)
        if not self.user.PostMessageW(window["hwnd"], 0x111, matches[0]["id"], 0):
            raise C.WinError(C.get_last_error())

    def executable(self, pid):
        handle = self.kernel.OpenProcess(0x1000, False, pid)
        if not handle:
            return None
        try:
            buffer = C.create_unicode_buffer(32768)
            count = W.DWORD(len(buffer))
            if self.kernel.QueryFullProcessImageNameW(handle, 0, buffer, C.byref(count)):
                return buffer.value
            return None
        finally:
            self.kernel.CloseHandle(handle)

    def windows(self, executable, pid=None, title=None, include_hidden=False):
        found = []
        callback_type = C.WINFUNCTYPE(W.BOOL, W.HWND, W.LPARAM)

        @callback_type
        def collect(handle, _):
            if not include_hidden and not self.user.IsWindowVisible(handle):
                return True
            owner = W.DWORD()
            self.user.GetWindowThreadProcessId(handle, C.byref(owner))
            if pid is not None and owner.value != pid:
                return True
            path = self.executable(owner.value)
            if path is None or os.path.normcase(path) != os.path.normcase(str(Path(executable).resolve())):
                return True
            text = C.create_unicode_buffer(self.user.GetWindowTextLengthW(handle) + 1)
            self.user.GetWindowTextW(handle, text, len(text))
            if title is not None and text.value != title:
                return True
            rectangle = W.RECT()
            self.user.GetClientRect(handle, C.byref(rectangle))
            found.append({"hwnd": handle, "pid": owner.value, "title": text.value,
                          "exe": path, "width": rectangle.right, "height": rectangle.bottom})
            return True

        self.user.EnumWindows.argtypes = [callback_type, W.LPARAM]
        if not self.user.EnumWindows(collect, 0):
            raise C.WinError(C.get_last_error())
        return found

    def target(self, executable, pid=None, title=None):
        matches = self.windows(executable, pid, title)
        if len(matches) != 1:
            raise RuntimeError(f"Expected one visible target window, found {len(matches)}; specify PID/title")
        window = matches[0]
        if self.user.IsIconic(window["hwnd"]) or min(window["width"], window["height"]) < 1:
            raise RuntimeError("Target minimized or empty")
        return window

    def focus(self, window):
        self.user.SetForegroundWindow(window["hwnd"])
        deadline = time.monotonic() + 2
        while self.user.GetForegroundWindow() != window["hwnd"]:
            if time.monotonic() > deadline:
                raise RuntimeError("Cannot focus target; input refused")
            time.sleep(0.05)

    def guard(self, window):
        if self.user.GetForegroundWindow() != window["hwnd"]:
            owner = W.DWORD()
            self.user.GetWindowThreadProcessId(self.user.GetForegroundWindow(), C.byref(owner))
            executable = self.executable(owner.value)
            name = Path(executable).name if executable else 'unknown process'
            raise RuntimeError("Focus changed to " + name + "; input stopped")
        self.identity_guard(window)

    def identity_guard(self, window):
        owner = W.DWORD()
        self.user.GetWindowThreadProcessId(window["hwnd"], C.byref(owner))
        if owner.value != window["pid"]:
            raise RuntimeError("Window ownership changed")
        if self.executable(window["pid"]) != window["exe"]:
            raise RuntimeError("Process identity changed")

    def key(self, window, keys, hold=0.05):
        names = {"CTRL": 0x11, "SHIFT": 0x10, "ALT": 0x12, "ENTER": 0x0D,
                 "ESC": 0x1B, "TAB": 9, "SPACE": 0x20, "BACKTICK": 0xC0,
                 "UP": 0x26, "DOWN": 0x28, "LEFT": 0x25, "RIGHT": 0x27,
                 "BACKSPACE": 8, "DELETE": 0x2E, "HOME": 0x24, "END": 0x23}
        codes = []
        for name in keys.upper().split("+"):
            if len(name) == 1 and name.isalnum():
                codes.append(ord(name))
            elif name.startswith("F") and name[1:].isdigit() and 1 <= int(name[1:]) <= 24:
                codes.append(0x70 + int(name[1:]) - 1)
            else:
                codes.append(names[name])
        self.press(window, codes, hold)

    def press(self, window, codes, hold):
        pressed = []
        def send(scan, flags):
            event = Input(kind=1, data=InputData(keyboard=KeyboardInput(0, scan, flags | 8, 0, 0)))
            if self.user.SendInput(1, C.byref(event), C.sizeof(Input)) != 1:
                raise C.WinError(C.get_last_error())
        try:
            for code in codes:
                self.guard(window)
                extended = 1 if code in (0x21, 0x22, 0x23, 0x24, 0x25, 0x26, 0x27, 0x28, 0x2D, 0x2E) else 0
                scan = self.user.MapVirtualKeyW(code, 0)
                send(scan, extended)
                pressed.append((code, scan, extended))
                if code in (0x10, 0x11, 0x12):
                    # Let the game's modifier state advance before character input.
                    time.sleep(0.10)
            deadline = time.monotonic() + hold
            while time.monotonic() < deadline:
                self.guard(window)
                time.sleep(min(0.01, max(0, deadline - time.monotonic())))
        finally:
            for code, scan, extended in reversed(pressed):
                send(scan, extended | 2)
                if len(pressed) > 1:
                    time.sleep(0.05)

    def text(self, window, text):
        # Keyboard-layout translation works with native console character input.
        for character in text:
            value = self.user.VkKeyScanW(character)
            if value == -1:
                raise RuntimeError(f"Character unavailable on current keyboard: {character!r}")
            modifiers = value >> 8
            codes = [code for bit, code in ((1, 0x10), (2, 0x11), (4, 0x12)) if modifiers & bit]
            # DirectInput sampling misses short presses at low game frame rates.
            self.press(window, codes + [value & 0xFF], 0.10)
            time.sleep(0.05)

    def click(self, window, x, y):
        self.guard(window)
        if not 0 <= x < 1 or not 0 <= y < 1:
            raise RuntimeError("Click coordinates must be client-relative fractions in [0,1)")
        point = W.POINT(int(x * window["width"]), int(y * window["height"]))
        self.user.ClientToScreen(window["hwnd"], C.byref(point))
        self.user.SetCursorPos(point.x, point.y)
        self.guard(window)
        self.user.mouse_event(2, 0, 0, 0, 0)
        try:
            time.sleep(0.05)
        finally:
            self.user.mouse_event(4, 0, 0, 0, 0)

    def uia_click(self, window, name, script, automation_id=None, native=False):
        argv = ["powershell.exe", "-NoProfile", "-ExecutionPolicy", "Bypass",
                                  "-File", str(script), "-TargetProcessId", str(window["pid"]),
                                  "-Action", "Resolve", "-Name", name]
        if automation_id:
            argv += ["-AutomationId", automation_id]
        process = subprocess.run(argv, capture_output=True, text=True,
                                 timeout=20, creationflags=subprocess.CREATE_NO_WINDOW)
        if process.returncode:
            raise RuntimeError(process.stderr)
        control = json.loads(process.stdout)
        if native:
            handle = control["Handle"]
            owner = W.DWORD()
            self.user.GetWindowThreadProcessId(handle, C.byref(owner))
            kind = C.create_unicode_buffer(256)
            self.user.GetClassNameW(handle, kind, len(kind))
            self.identity_guard(window)
            if owner.value != window["pid"] or kind.value != "Button":
                raise RuntimeError("Native click restricted to target-owned Button controls")
            if not self.user.PostMessageW(handle, 0xF5, 0, 0):
                raise C.WinError(C.get_last_error())
            return
        origin = W.POINT(0, 0)
        self.user.ClientToScreen(window["hwnd"], C.byref(origin))
        self.click(window, (control["X"] + control["Width"] / 2 - origin.x) / window["width"],
                   (control["Y"] + control["Height"] / 2 - origin.y) / window["height"])

    def screenshot(self, window, output, ffmpeg, capture_mode="window"):
        Path(output).parent.mkdir(parents=True, exist_ok=True)
        source = ["-i", f"hwnd={window['hwnd']}"]
        if capture_mode == "desktop":
            self.guard(window)
            origin = W.POINT(0, 0)
            self.user.ClientToScreen(window["hwnd"], C.byref(origin))
            source = ["-offset_x", str(origin.x), "-offset_y", str(origin.y),
                      "-video_size", f"{window['width']}x{window['height']}", "-i", "desktop"]
        process = subprocess.run([str(ffmpeg), "-hide_banner", "-loglevel", "error", "-nostdin", "-y",
                                  "-f", "gdigrab", "-draw_mouse", "0", *source,
                                  "-frames:v", "1", "-update", "1", str(output)],
                                 stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=20,
                                 creationflags=subprocess.CREATE_NO_WINDOW)
        if process.returncode or not Path(output).is_file():
            raise RuntimeError(process.stdout.decode(errors="replace"))
        if capture_mode == "desktop":
            self.guard(window)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=["list", "close", "menus", "menu-invoke", "screenshot", "key", "text", "native-value", "click", "uia-click", "uia-native-click"])
    parser.add_argument("--exe", required=True)
    parser.add_argument("--pid", type=int)
    parser.add_argument("--title")
    parser.add_argument("--output")
    parser.add_argument("--ffmpeg", default="ffmpeg")
    parser.add_argument("--capture", choices=["window", "desktop"], default="window")
    parser.add_argument("--keys")
    parser.add_argument("--text")
    parser.add_argument("--x", type=float)
    parser.add_argument("--y", type=float)
    parser.add_argument("--hold", type=float, default=0.05)
    parser.add_argument("--name")
    parser.add_argument("--automation-id")
    parser.add_argument("--uia-script", default=str(Path(__file__).with_name("uia.ps1")))
    parser.add_argument("--allow-input", action="store_true")
    args = parser.parse_args()
    desktop = Desktop()
    if args.action == "list":
        print(json.dumps(desktop.windows(args.exe, args.pid, args.title), indent=2))
        return
    window = desktop.target(args.exe, args.pid, args.title)
    if args.action == "menus":
        print(json.dumps(desktop.menus(window), indent=2))
        return
    if args.action == "screenshot":
        if not args.output:
            parser.error("--output required")
        desktop.screenshot(window, args.output, args.ffmpeg, args.capture)
    else:
        if not args.allow_input:
            parser.error("Explicit --allow-input required")
        if args.action in ("key", "text", "click", "uia-click"):
            desktop.focus(window)
        if args.action == "key":
            desktop.key(window, args.keys, args.hold)
        elif args.action == "text":
            desktop.text(window, args.text)
        elif args.action == "native-value":
            desktop.native_value(window, args.automation_id, args.text, args.uia_script)
        elif args.action in ("uia-click", "uia-native-click"):
            desktop.uia_click(window, args.name, args.uia_script, args.automation_id,
                              args.action == "uia-native-click")
        elif args.action == "menu-invoke":
            desktop.menu_invoke(window, args.name)
        elif args.action == "close":
            desktop.identity_guard(window)
            if not desktop.user.PostMessageW(window["hwnd"], 0x10, 0, 0):
                raise C.WinError(C.get_last_error())
        else:
            desktop.click(window, args.x, args.y)
    print(json.dumps({"action": args.action, "target": window, "output": args.output}))


if __name__ == "__main__":
    main()
