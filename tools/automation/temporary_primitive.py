"""Prepare reversible development-only primitive experiment transactions."""
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import re

from full_scheme_delivery import CONTENT, PAYLOADS, digest, validate_cook, write_plan
from full_schemes import SchemeError, parse
from primitive_bank import CONTEXT, bank as prepare_bank
from probe_session import verify_journal


def restored_input(current, installed, original):
    actual = parse(current.decode('utf-8-sig'))
    expected = parse(installed.decode('utf-8-sig'))
    before = parse(original.decode('utf-8-sig'))
    if CONTEXT not in actual or CONTEXT not in expected or CONTEXT in before:
        raise SchemeError('Unexpected primitive context inventory')
    if Counter(r.signature for r in actual[CONTEXT]) != Counter(r.signature for r in expected[CONTEXT]):
        raise SchemeError('Owned primitive context changed')
    excluded = {r.line for r in actual[CONTEXT]}
    text = current.decode('utf-8-sig')
    remaining = ''.join(line for number, line in enumerate(text.splitlines(keepends=True), 1)
                        if number not in excluded and not re.fullmatch(r'\s*\[' + CONTEXT + r'\]\s*', line.strip()))
    parsed = parse(remaining)
    if (set(parsed) == set(before) and all(Counter(r.signature for r in parsed[c]) ==
                                          Counter(r.signature for r in before[c]) for c in before)):
        return original
    # Preserve later unrelated edits rather than replacing the entire input file.
    return (b'\xef\xbb\xbf' if current.startswith(b'\xef\xbb\xbf') else b'') + remaining.encode('utf-8')


def install(repo, runtime_path, snapshot, bank_dir, output):
    runtime = verify_journal(runtime_path)
    if runtime.get('Purpose') != 'Phase0LoadProbe' or 'Phase11Candidate' not in runtime:
        raise SchemeError('Experiment requires the existing schema-2 development installation')
    game = Path(runtime['GamePath'])
    validate_cook(repo, snapshot, game)
    bank = json.loads((bank_dir / 'bank.json').read_text(encoding='utf-8'))
    input_path = Path(runtime['Phase11Candidate']['InputPath'])
    data = (bank_dir / 'input.settings').read_bytes()
    if (Path(bank['input_path']).resolve() != input_path.resolve() or
            digest(input_path) != bank['input_before_sha256'] or
            hashlib.sha256(data).hexdigest() != bank['input_after_sha256']):
        raise SchemeError('Primitive input preparation changed')
    # Reconstruct the declared bank; metadata cannot authorize arbitrary input edits.
    mode = bank.get('mode', 'observer')
    expected_text, expected_bank = prepare_bank(input_path.read_bytes().decode('utf-8-sig'), mode)
    if (data.decode('utf-8-sig') != expected_text or
            bank.get('gameplay_remapping') != expected_bank['gameplay_remapping']):
        raise SchemeError('Primitive bank payload or declared mode disagrees')
    migration_path = Path(runtime['Phase11Candidate']['TransactionDirectory']) / 'files.json'
    migration = json.loads(migration_path.read_text(encoding='utf-8-sig'))
    if (migration.get('Purpose') != 'ControllerCustomizerPhase11DevelopmentMigration' or
            not migration.get('InstallationComplete') or migration.get('Restored') or
            migration.get('RolledBack') or Path(migration['PreviousRuntimeJournal']).resolve() != runtime_path.resolve()):
        raise SchemeError('Invalid original migration journal')
    expected = {str((game / (CONTENT + name)).resolve()) for name in PAYLOADS}
    expected.update((str(input_path.resolve()), str(runtime_path.resolve()),
                     str((game / 'bin/config/r4game/user_config_matrix/pc/modControllerCustomizer.xml').resolve())))
    if (len(migration['Items']) != 6 or
            {str(Path(item['Target']).resolve()) for item in migration['Items']} != expected):
        raise SchemeError('Unexpected original migration ownership')
    entries = []
    replacement = {}
    for name in PAYLOADS:
        target = game / (CONTENT + name)
        payload = (snapshot / ('packed/' + CONTENT + name)).read_bytes()
        replacement[str(target.resolve())] = hashlib.sha256(payload).hexdigest()
        entries.append((target, digest(target), payload))
        item = next(i for i in runtime['Items'] if Path(i['RelativePath']).name == name)
        item['InstalledSha256'] = replacement[str(target.resolve())]
    runtime['CookSnapshot'] = str(snapshot.resolve())
    runtime['RuntimeLoadVerified'] = False
    runtime['PrimitiveExperiment'] = {'Context': CONTEXT, 'GameplayRemapping': expected_bank['gameplay_remapping'], 'Mode': mode}
    runtime_data = (json.dumps(runtime, indent=2) + '\n').encode('utf-8')
    replacement[str(runtime_path.resolve())] = hashlib.sha256(runtime_data).hexdigest()
    replacement[str(input_path.resolve())] = hashlib.sha256(data).hexdigest()
    for item in migration['Items']:
        if str(Path(item['Target']).resolve()) in replacement:
            item['InstalledSha256'] = replacement[str(Path(item['Target']).resolve())]
    migration['CookSnapshot'] = str(snapshot.resolve())
    entries.extend(((input_path, digest(input_path), data),
                    (runtime_path, digest(runtime_path), runtime_data),
                    (migration_path, digest(migration_path), (json.dumps(migration, indent=2) + '\n').encode('utf-8'))))
    write_plan(output, entries, {'Purpose': 'ControllerCustomizerPrimitiveExperiment',
                                'InputPath': str(input_path.resolve()), 'RuntimeJournal': str(runtime_path.resolve()),
                                'GamePath': str(game.resolve()), 'MigrationJournal': str(migration_path.resolve()),
                                'GameplayRemapping': expected_bank['gameplay_remapping'], 'Mode': mode, 'CookSnapshot': str(snapshot.resolve())})


def restore(journal_path, output):
    state = json.loads(journal_path.read_text(encoding='utf-8-sig'))
    if (state.get('Purpose') != 'ControllerCustomizerPrimitiveExperiment' or
            not state.get('InstallationComplete') or state.get('Restored') or state.get('RolledBack')
            or len(state['Items']) != 6):
        raise SchemeError('Invalid primitive experiment journal')
    expected = {str((Path(state['GamePath']) / (CONTENT + name)).resolve()) for name in PAYLOADS}
    expected.update(str(Path(state[key]).resolve()) for key in ('InputPath', 'RuntimeJournal', 'MigrationJournal'))
    if {str(Path(item['Target']).resolve()) for item in state['Items']} != expected:
        raise SchemeError('Unexpected experiment ownership inventory')
    entries = []
    for index, item in enumerate(state['Items']):
        target, backup, payload = map(Path, (item['Target'], item['Backup'], item['Payload']))
        if (backup.resolve() != (journal_path.parent / 'backups' / str(index)).resolve() or
                payload.resolve() != (journal_path.parent / 'payload' / str(index)).resolve()):
            raise SchemeError('Experiment backup escaped its journal')
        if digest(backup) != item['OriginalSha256'] or digest(payload) != item['InstalledSha256']:
            raise SchemeError('Experiment backup or payload changed')
        if target.resolve() == Path(state['InputPath']).resolve():
            data = restored_input(target.read_bytes(), payload.read_bytes(), backup.read_bytes())
        else:
            if digest(target) != item['InstalledSha256']:
                raise SchemeError('Owned experiment file changed')
            data = backup.read_bytes()
        entries.append((target, digest(target), data))
    state['Restored'] = True
    entries.append((journal_path, digest(journal_path), (json.dumps(state, indent=2) + '\n').encode('utf-8')))
    write_plan(output, entries, {'Purpose': 'ControllerCustomizerPrimitiveExperimentRestore',
                                'ExperimentJournal': str(journal_path.resolve())})


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=('install', 'restore'))
    parser.add_argument('--repo', type=Path, default=Path(__file__).resolve().parents[2])
    parser.add_argument('--journal', type=Path, required=True)
    parser.add_argument('--cook', type=Path)
    parser.add_argument('--bank', type=Path)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    if args.action == 'restore':
        restore(args.journal, args.output)
    else:
        if args.cook is None or args.bank is None:
            parser.error('install requires --cook and --bank')
        install(args.repo, args.journal, args.cook, args.bank, args.output)
    print('PASS: experiment transaction prepared; live files untouched')


if __name__ == '__main__':
    main()
