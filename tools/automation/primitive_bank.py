"""Stage a bounded native input experiment; live installation is separate."""
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path

from full_schemes import Record, SchemeError, parse

CONTEXT = 'CC_PRIMITIVE_Horse'
SOURCE = 'CC_SCHEME_DarkSoulAlt1_Horse'
ACTIONS = ('CCP_X_PRESS', 'CCP_X_D3', 'CCP_X_D5')


def swapped_horse(rows):
    """Explicitly relocate both occupied Xbox button banks; never drop actions."""
    x, l3 = 'IK_Pad_X_SQUARE', 'IK_Pad_LeftThumb'
    expected = Counter(Record(key, value, 0).signature for key, value in (
        (x, '(Action=VehicleCastSign)'),
        (l3, '(Action=Follow)'), (l3, '(Action=Canter)'),
        (l3, '(Action=Gallop,State=Duration,IdleTime=0.3)'),
        (l3, '(Action=EnablePhotoMode_Step1)')))
    if Counter(r.signature for r in rows if r.key in (x, l3)) != expected:
        raise SchemeError('Occupied X/L3 bank differs; explicit reconciliation required')
    result = []
    for row in rows:
        key = l3 if row.key == x else x if row.key == l3 else row.key
        value = row.value
        if row.key == l3 and dict(row.signature[1]).get('Action') == 'Gallop':
            # Parameters were validated above; preserve every other parameter.
            tokens = value[1:-1].split(',')
            value = '(' + ','.join('IdleTime=0.5' if token.strip().startswith('IdleTime=') else token for token in tokens) + ')'
        result.append(Record(key, value, row.line))
    return result


def bank(text, mode='observer'):
    if mode not in ('observer', 'horse-swap'):
        raise SchemeError('Unsupported primitive bank mode')
    sections = parse(text)
    if CONTEXT in sections or any(row.value.find('Action=CCP_') >= 0 for rows in sections.values() for row in rows):
        raise SchemeError('Primitive bank already present')
    if SOURCE not in sections or any(r.key == 'DERIVED_FROM' for r in sections[SOURCE]):
        raise SchemeError('Expected a flat, owned Alt1 horse context')
    if len(sections) + 1 > 128:
        raise SchemeError('Primitive bank exceeds native context capacity')
    additions = ['IK_Pad_X_SQUARE=(Action=CCP_X_PRESS)',
                 'IK_Pad_X_SQUARE=(Action=CCP_X_D3,State=Duration,IdleTime=0.3)',
                 'IK_Pad_X_SQUARE=(Action=CCP_X_D5,State=Duration,IdleTime=0.5)']
    if mode == 'horse-swap':
        additions.append('IK_Pad_LeftThumb=(Action=CCP_SWAP_SIGN)')
    block = '\r\n[' + CONTEXT + ']\r\n'
    rows = swapped_horse(sections[SOURCE]) if mode == 'horse-swap' else sections[SOURCE]
    block += ''.join(r.key + '=' + r.value + '\r\n' for r in rows)
    block += '\r\n'.join(additions) + '\r\n'
    result = text + block
    parsed = parse(result)
    assert all(Counter(r.signature for r in parsed[c]) == Counter(r.signature for r in rows)
               for c, rows in sections.items())
    return result, {'context': CONTEXT, 'source_context': SOURCE, 'actions': list(ACTIONS) + (['CCP_SWAP_SIGN'] if mode == 'horse-swap' else []),
                    'contexts_before': len(sections), 'contexts_after': len(parsed),
                    'mode': mode, 'gameplay_remapping': mode == 'horse-swap', 'runtime_verified': False,
                    'relocations': {'X': 'L3', 'L3': 'X'} if mode == 'horse-swap' else {},
                    'gallop_duration_seconds': 0.5 if mode == 'horse-swap' else None}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--input', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--mode', choices=('observer', 'horse-swap'), default='observer')
    args = parser.parse_args()
    raw = args.input.read_bytes()
    text, receipt = bank(raw.decode('utf-8-sig'), args.mode)
    payload = (b'\xef\xbb\xbf' if raw.startswith(b'\xef\xbb\xbf') else b'') + text.encode('utf-8')
    receipt['input_path'] = str(args.input.resolve())
    receipt['input_before_sha256'] = hashlib.sha256(raw).hexdigest()
    receipt['input_after_sha256'] = hashlib.sha256(payload).hexdigest()
    args.output.mkdir(parents=True, exist_ok=False)
    (args.output / 'input.settings').write_bytes(payload)
    (args.output / 'bank.json').write_text(json.dumps(receipt, indent=2) + '\n', encoding='utf-8')
    print('PASS: one primitive context staged; live files untouched')


if __name__ == '__main__':
    main()
