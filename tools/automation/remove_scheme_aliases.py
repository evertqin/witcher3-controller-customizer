"""Remove verified full-scheme aliases while preserving unrelated personal edits."""
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import re

from full_schemes import SchemeError, observed_serialization, parse


def remove_aliases(text, appendix, aliases):
    names = {a['alias'] for a in aliases}
    contexts = {a['canonical'] for a in aliases}
    prefixes = {'vanilla': 'Vanilla', 'darksoul': 'DarkSoul', 'darksoul-alt1': 'DarkSoulAlt1'}
    if len(names) not in (60, 84) or len(aliases) != 84 or len(contexts) != 28:
        raise SchemeError('Invalid owned full-scheme inventory')
    if {(a['scheme'], a['canonical']) for a in aliases} != {(s, c) for s in prefixes for c in contexts}:
        raise SchemeError('Incomplete three-scheme inventory')
    for a in aliases:
        expected_name = f"CC_SCHEME_{prefixes[a['scheme']]}_{a['canonical']}"
        shared_name = f"CC_SCHEME_DarkSoul_{a['canonical']}"
        shared = (len(names) == 60 and a['scheme'] == 'darksoul-alt1' and
                  a['canonical'] not in ('BASE_INTERACTIONS_HORSE', 'Horse', 'Horse_Replacer_Ciri', 'ScriptedAction') and a['alias'] == shared_name)
        if a['alias'] != expected_name and not shared:
            raise SchemeError('Alias identity changed')
    expected, current = parse(appendix), parse(text)
    if set(expected) != names:
        raise SchemeError('Appendix inventory changed')
    if {c for c in current if c.startswith('CC_SCHEME_')} != names:
        raise SchemeError('Missing or independently added full-scheme context')
    remove_lines = set()
    for name in names:
        source = Counter(r.signature for r in expected[name])
        actual = Counter(r.signature for r in current[name])
        if actual != source and actual != observed_serialization(source, name):
            raise SchemeError('Owned alias bindings changed: ' + name)
        remove_lines.update(r.line for r in current[name])
    output = []
    for number, line in enumerate(text.splitlines(keepends=True), 1):
        header = re.fullmatch(r'\s*\[([A-Za-z0-9_]+)\]\s*', line.rstrip('\r\n').lstrip('\ufeff'))
        if number in remove_lines or (header and header[1] in names):
            continue
        if line.strip() in ('; Controller Customizer full schemes BEGIN', '; Controller Customizer full schemes END'):
            continue
        output.append(line)
    result = ''.join(output)
    remaining = parse(result)
    for name in set(current) - names:
        if Counter(r.signature for r in remaining[name]) != Counter(r.signature for r in current[name]):
            raise SchemeError('Unrelated personal context changed during removal')
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--candidate', type=Path, required=True)
    parser.add_argument('--personal-input', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    receipt = json.loads((args.candidate / 'candidate.json').read_text(encoding='utf-8'))
    appendix = (args.candidate / 'full-scheme-appendix.ini').read_bytes()
    if hashlib.sha256(appendix).hexdigest() != receipt['files']['full-scheme-appendix.ini']:
        raise SchemeError('Candidate appendix changed')
    if 'registered_aliases_sha256' in receipt:
        appendix = (args.candidate / 'registered-aliases.ini').read_bytes()
        if hashlib.sha256(appendix).hexdigest() != receipt['registered_aliases_sha256']:
            raise SchemeError('Registered alias ownership evidence changed')
    original = args.personal_input.read_bytes()
    result = remove_aliases(original.decode('utf-8-sig'), appendix.decode('utf-8'), receipt['aliases'])
    payload = (b'\xef\xbb\xbf' if original.startswith(b'\xef\xbb\xbf') else b'') + result.encode('utf-8')
    with args.output.open('xb') as stream:
        stream.write(payload)
    print('PASS: verified 84 aliases removed from candidate output; personal file untouched')


if __name__ == '__main__':
    main()
