"""Read-only Phase 2 conflict audit; never installs or proves runtime bindings."""
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path

from custom_bindings import BUTTON_KEYS, from_scheme, scheme_profile, validate
from full_schemes import digital_pad, expand_lineage, parse


def action_name(record):
    parameters = record.signature[1]
    return dict(parameters).get('Action') if isinstance(parameters, tuple) else None


def audit(config, catalog, profile, personal_text):
    candidate = validate(config, catalog)
    personal = expand_lineage(parse(personal_text))
    contexts = {row['Id']: row['NativeName'] for row in catalog['Contexts']}
    actions = {row['Id']: row['NativeName'] for row in catalog['Actions']}
    slots = {row['Id']: row for row in catalog['Bindings']}
    editable = {}
    for row in slots.values():
        editable.setdefault(contexts[row['ContextId']], set()).add(actions[row['ActionId']])
    conflicts, patterns, changed = [], [], []
    for binding in candidate['bindings']:
        slot = slots[binding['id']]
        context = contexts[slot['ContextId']]
        if context not in personal or context not in profile:
            raise ValueError(f'Missing gameplay context: {context}')
        action = actions[slot['ActionId']]
        key = BUTTON_KEYS[binding['button']]
        original = [row for row in profile[context] if digital_pad(row) and action_name(row) == action]
        if len(original) != 1:
            raise ValueError(f'Ambiguous source for {binding["id"]}')
        parameters = dict(original[0].signature[1])
        original_seconds = float(parameters['IdleTime']) if parameters.get('State') == 'Duration' else None
        original_gesture = 'duration' if original_seconds is not None else 'press'
        if (original[0].key, original_gesture, original_seconds) == (key, binding['gesture'], binding['seconds']):
            continue
        changed.append(binding['id'])
        # Selected immutable scheme supplies digital records; personal patterns,
        # axes and keyboard records remain untouched by the existing backend.
        for row in profile[context]:
            if digital_pad(row) and row.key == key and action_name(row) not in editable[context]:
                conflicts.append({'binding': binding['id'], 'context': context,
                                  'key': key, 'record': row.value, 'source': 'scheme'})
        # Do not discard personal digital additions merely because a preset
        # provides the base bank. Report only additions beyond its multiset.
        remaining = Counter(row.signature for row in profile[context] if digital_pad(row))
        for row in personal[context]:
            if digital_pad(row):
                if remaining[row.signature]:
                    remaining[row.signature] -= 1
                elif row.key == key and action_name(row) not in editable[context]:
                    conflicts.append({'binding': binding['id'], 'context': context,
                                      'key': key, 'record': row.value, 'source': 'personal'})
            elif row.key.startswith('IK_Pattern_'):
                patterns.append({'binding': binding['id'], 'context': context,
                                 'key': row.key, 'record': row.value})
    # Pattern definitions live outside this catalog. Their physical dependencies
    # and query/listener/release behavior still require native tracing.
    return {'schema_version': 1, 'changed_bindings': changed, 'conflicts': conflicts,
            'pattern_dependencies_to_trace': patterns,
            'personal_context_count': len(personal),
            'runtime_apply_available': False, 'runtime_verified': False,
            'personal_input_sha256': hashlib.sha256(personal_text.encode('utf-8')).hexdigest()}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--repo', type=Path, default=Path(__file__).resolve().parents[2])
    parser.add_argument('--native', type=Path, required=True)
    parser.add_argument('--scheme', choices=('vanilla', 'darksoul', 'darksoul-alt1'), required=True)
    parser.add_argument('--personal', type=Path, required=True)
    parser.add_argument('--config', type=Path)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    catalog = json.loads((args.repo / 'data/actions.json').read_text(encoding='utf-8-sig'))
    config = (json.loads(args.config.read_text(encoding='utf-8-sig')) if args.config
              else from_scheme(catalog, args.repo, args.native, args.scheme))
    result = audit(config, catalog, scheme_profile(args.repo, args.native, args.scheme),
                   args.personal.read_text(encoding='utf-8-sig'))
    result['scheme'] = args.scheme
    # Preserve byte-level evidence, including a possible BOM and native newlines.
    result['personal_input_sha256'] = hashlib.sha256(args.personal.read_bytes()).hexdigest()
    with args.output.open('x', encoding='utf-8', newline='\n') as output:
        output.write(json.dumps(result, indent=2, allow_nan=False) + '\n')
    print(f'Audit only: {len(result["conflicts"])} conflicts; runtime apply remains disabled.')


if __name__ == '__main__':
    main()
