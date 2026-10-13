"""Stage one read-only native primitive bank; live installation is separate."""
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path

from full_schemes import SchemeError, parse

CONTEXT = 'CC_PRIMITIVE_Horse'
SOURCE = 'CC_SCHEME_DarkSoulAlt1_Horse'
ACTIONS = ('CCP_X_PRESS', 'CCP_X_D3', 'CCP_X_D5')


def bank(text):
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
    block = '\r\n[' + CONTEXT + ']\r\n'
    block += ''.join(r.key + '=' + r.value + '\r\n' for r in sections[SOURCE])
    block += '\r\n'.join(additions) + '\r\n'
    result = text + block
    parsed = parse(result)
    assert all(Counter(r.signature for r in parsed[c]) == Counter(r.signature for r in rows)
               for c, rows in sections.items())
    return result, {'context': CONTEXT, 'source_context': SOURCE, 'actions': list(ACTIONS),
                    'contexts_before': len(sections), 'contexts_after': len(parsed),
                    'gameplay_remapping': False, 'runtime_verified': False}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--input', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    raw = args.input.read_bytes()
    text, receipt = bank(raw.decode('utf-8-sig'))
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
