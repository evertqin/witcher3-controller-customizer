"""Strict callback assertions from the game's freshly captured status notification."""
import json
import os
from pathlib import Path
import re
import subprocess


def parse_console_prompt(text, command):
    # Punctuation/cursor OCR varies; command letters and digits must match exactly.
    normalize = lambda value: re.sub(r'[^a-z0-9]', '', value.casefold())
    if normalize(text) != normalize(command):
        raise RuntimeError('Console prompt differs from requested command; execution refused')


def parse_ride(text, expected_context):
    def required(pattern):
        matches = list(re.finditer(pattern, text))
        if len(matches) != 1:
            raise RuntimeError('Notification assertion missing/ambiguous: ' + pattern)
        return matches[0]

    required(r'source[=-]horse\s+handlers')
    # A primary counter starts a field; never borrow "pattern callbacks=0".
    callbacks = int(required(r'(?:^|;)\s*callbacks[=-](\d+);').group(1))
    canter = tuple(map(int, required(r'Canter press/release[=-](\d+)/(\d+);').groups()))
    gallop = tuple(map(int, required(r'Gallop press/release[=-](\d+)/(\d+);').groups()))
    mismatches = int(required(r'query mismatches[=-](\d+);').group(1))
    context = required(r'last[=-]([A-Za-z0-9_\s]+)/').group(1)
    if callbacks <= 0 or not canter[0] or not gallop[0]:
        raise RuntimeError('No useful Canter/Gallop callback evidence')
    if canter[0] != canter[1] or gallop[0] != gallop[1]:
        raise RuntimeError('Unbalanced native press/release edges')
    if callbacks != sum(canter) + sum(gallop) or mismatches != 0:
        raise RuntimeError('Callback totals or native action queries disagree')
    # Calibrated hold + double-hold fixture: balanced duplicates must also fail.
    if callbacks != 10 or canter != (3, 3) or gallop != (2, 2):
        raise RuntimeError('Unexpected callback multiplicity for calibrated gestures')
    normalize_context = lambda value: re.sub(r'[\s_]', '', value)
    if normalize_context(context) != normalize_context(expected_context):
        raise RuntimeError('Wrong riding callback context: ' + context)
    return dict(scope='native_callback_and_query_only', callbacks=callbacks,
                canter_edges=canter, gallop_edges=gallop, query_mismatches=mismatches,
                last_context=expected_context, observed_context=context, gameplay_release_verified=False)


def read_ocr(path):
    environment = dict(os.environ)
    environment['PSModulePath'] = str(Path(os.environ['SystemRoot']) / 'System32/WindowsPowerShell/v1.0/Modules')
    result = subprocess.run(['powershell.exe', '-NoProfile', '-ExecutionPolicy', 'Bypass',
                             '-File', str(Path(__file__).with_name('ocr.ps1')),
                             '-ImagePath', str(path)], capture_output=True, text=True, encoding='utf-8',
                            timeout=30, creationflags=subprocess.CREATE_NO_WINDOW, env=environment)
    if result.returncode:
        raise RuntimeError('Windows OCR failed: ' + result.stderr)
    try:
        raw = json.loads(result.stdout.lstrip('\ufeff'))
    except json.JSONDecodeError as error:
        Path(path).with_suffix('.ocr-invalid.txt').write_text(result.stdout, encoding='utf-8')
        raise RuntimeError('Invalid OCR JSON; raw response retained') from error
    return raw


def parse_fallback(text):
    # Windows OCR confuses this font's equals sign with a hyphen; values stay exact.
    if not re.search(r'CC fallback:\s*valid[=-]1/0;\s*invalid[=-]1/0;\s*restored[=-]yes(?:\s|$)', text):
        raise RuntimeError('Preset fallback/restoration assertion failed')
    return dict(scope='preset_fallback_state_machine', last_valid_retained=True, original_restored=True)


def check_screenshot(path, expected_context):
    raw = read_ocr(path)
    return parse_ride(raw['Text'], expected_context), raw


def parse_foot(text, scheme):
    if scheme not in ('Vanilla', 'DarkSoul', 'DarkSoulAlt1'):
        raise RuntimeError('Unsupported foot scheme')
    match = re.findall(r'CC foot:\s*press/release[=-]([0-9lI]+)/([0-9lI]+)\s*;\s*mismatch[=-](\d+);\s*foreign[=-](\d+);\s*last[=-]([A-Za-z0-9_\s]+)', text)
    if len(match) != 1:
        raise RuntimeError('Notification assertion missing/ambiguous: foot counters')
    press, release, mismatch, foreign, raw = match[0]
    # This UI font's unit digit is read as l/I; normalize only edge-count fields.
    press = press.translate(str.maketrans({'l': '1', 'I': '1'}))
    release = release.translate(str.maketrans({'l': '1', 'I': '1'}))
    context = re.sub(r'[\s_]', '', raw)
    # Only the known Alt1 suffix permits the same unit-digit glyph ambiguity.
    context = re.sub(r'DarkSoulAlt[lI](?=Combat$|Exploration$)', 'DarkSoulAlt1', context)
    bank = 'DarkSoul' if scheme == 'DarkSoulAlt1' else scheme
    valid = [re.sub('_', '', f'CC_SCHEME_{label}_{kind}') for label in {scheme, bank} for kind in ('Exploration', 'Combat')]
    if tuple(map(int, (press, release, mismatch, foreign))) != (1, 1, 0, 0) or context not in valid:
        raise RuntimeError('On-foot native callback counts, queries or context disagree')
    return dict(scope='native_light_attack_dispatch_and_query_only', press=1, release=1,
                mismatches=0, foreign=0, context=raw.strip(), animation_verified=False)


def parse_primitives(text, expected):
    if len(re.findall(r'CC primitives:', text, re.I)) != 1:
        raise RuntimeError('Notification assertion missing/ambiguous: primitive source')
    number = lambda value: int(value.translate(str.maketrans({'O': '0', 'o': '0', 'I': '1', 'l': '1', 'i': '1'})))
    counters = []
    for label in ('P', 'D3', 'D5'):
        matches = re.findall(r'(?:^|;)\s*' + label + r'[=-]([0-9OoIli]+)/([0-9OoIli]+)', text.split(':', 1)[-1], re.I)
        if len(matches) != 1:
            raise RuntimeError('Notification assertion missing/ambiguous: primitive ' + label)
        counters.append([number(value) for value in matches[0]])
    for label, required in (('mismatch', 0), ('keys', 3), ('context', 1)):
        matches = re.findall(r';\s*' + label + r'[=-]([0-9OoIli]+)', text, re.I)
        if len(matches) != 1:
            raise RuntimeError('Notification assertion missing/ambiguous: primitive ' + label)
        if number(matches[0]) != required:
            raise RuntimeError('Primitive query/key/context mismatch: ' + label)
    if counters != expected:
        raise RuntimeError('Unexpected primitive callback counts: ' + str(counters))
    return {'press': counters[0], 'duration_0_3': counters[1], 'duration_0_5': counters[2],
            'query_mismatches': 0, 'keys': 3, 'context_verified': True}
