"""Prepare schema-2 standalone transactions; PowerShell owns atomic live writes."""
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path

from full_schemes import SchemeError, parse
from remove_scheme_aliases import remove_aliases
from scheme_runtime import prepare

CONTENT = 'mods/modCustomizeControllerScheme/content/'
MENU = 'bin/config/r4game/user_config_matrix/pc/modControllerCustomizer.xml'
PAYLOADS = ('precompiled.rsblob', 'info.json', 'metadata.store')


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest() if path.is_file() else None


def read_json(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def confined(root, relative):
    path = (root / relative).resolve()
    if not path.is_relative_to(root.resolve()):
        raise SchemeError('Receipt path escaped root')
    return path


def validate_cook(repo, snapshot, game=None):
    cook = read_json(snapshot / 'cook.json')
    toolchain = read_json(repo / 'tools/compiler-toolchain.json')
    if (cook.get('SchemaVersion') != 2 or cook.get('EvidenceKind') != 'RedkitEditorCook'
            or cook.get('ScriptCompilationVerified') is not True
            or cook.get('SourceTextEquivalenceVerified') is not True
            or cook.get('UseLooseScripts') is not False
            or cook.get('ScriptCompilationErrors') != []
            or cook.get('CompilerSha256') != toolchain['CompilerSha256']
            or str(cook.get('ObservedBlobRelativePath', '')).replace('\\', '/').lower() != (CONTENT + 'precompiled.rsblob').lower()
            or digest(snapshot / 'cook.log') != cook.get('CookLogSha256')):
        raise SchemeError('Unverified editor cook')
    hooks = toolchain['BaseScriptSha256']
    if cook.get('BaseHookSha256') != hooks:
        raise SchemeError('Cooked hook inventory changed')
    if game:
        for relative, expected in hooks.items():
            if digest(confined(game / 'content/content0/scripts', relative)) != expected:
                raise SchemeError('Native hook changed')
    sources = cook['CanonicalSourceSha256']
    actual = {p.relative_to(repo / 'src/scripts').as_posix(): digest(p)
              for p in (repo / 'src/scripts').rglob('*.ws')}
    if len(sources) != 8 or sources != actual:
        raise SchemeError('Cook does not match current eight runtime sources')
    for name in PAYLOADS:
        path = snapshot / ('packed/' + CONTENT + name)
        if digest(path) != cook['FileSha256'][name]:
            raise SchemeError('Cooked payload changed')
    blob = snapshot / ('packed/' + CONTENT + PAYLOADS[0])
    if blob.stat().st_size != cook['BlobLength'] or cook['BlobLength'] <= 0:
        raise SchemeError('Invalid compiled blob length')
    return cook


def ownership_text(stage):
    receipt = read_json(stage / 'candidate.json')
    name = 'registered-aliases.ini' if 'registered_aliases_sha256' in receipt else 'full-scheme-appendix.ini'
    expected = receipt.get('registered_aliases_sha256') or receipt['files'][name]
    path = stage / name
    if digest(path) != expected:
        raise SchemeError('Alias ownership evidence changed')
    return receipt, path.read_bytes().decode('utf-8-sig')


def owned_input(path, stage):
    receipt, appendix = ownership_text(stage)
    raw = path.read_bytes()
    stripped = remove_aliases(raw.decode('utf-8-sig'), appendix, receipt['aliases'])
    return (b'\xef\xbb\xbf' if raw.startswith(b'\xef\xbb\xbf') else b'') + stripped.encode('utf-8')


def load_install(path):
    state = read_json(path)
    if (state.get('Purpose') != 'ControllerCustomizerPhase11Standalone'
            or not state.get('InstallationComplete') or state.get('Restored') or state.get('RolledBack')
            or state.get('SelectionSchemaVersion') != 2):
        raise SchemeError('Invalid standalone installation journal')
    game, input_path = Path(state['GamePath']), Path(state['InputPath'])
    allowed = {str((game / (CONTENT + n)).resolve()) for n in PAYLOADS}
    allowed.update((str((game / MENU).resolve()), str(input_path.resolve())))
    items = state['Items']
    if len(items) != 5 or {str(Path(i['Target']).resolve()) for i in items} != allowed:
        raise SchemeError('Unexpected standalone ownership inventory')
    for index, item in enumerate(items):
        backup = path.parent / 'backups' / str(index)
        if Path(item['Backup']).resolve() != backup.resolve() or digest(backup) != item['OriginalSha256']:
            raise SchemeError('Original standalone backup changed')
        if Path(item['Target']).resolve() != input_path.resolve() and digest(Path(item['Target'])) != item['InstalledSha256']:
            raise SchemeError('Owned game file changed')
    return state


def write_plan(output, entries, metadata):
    output.mkdir(parents=True, exist_ok=False)
    plan = []
    for index, (target, before, data) in enumerate(entries):
        payload = None
        if data is not None:
            path = output / ('payload-' + str(index))
            path.write_bytes(data)
            payload = str(path.resolve())
        plan.append({'Target': str(target.resolve()), 'BeforeSha256': before, 'Payload': payload})
    (output / 'transaction.json').write_text(json.dumps({'Entries': plan, 'Metadata': metadata}, indent=2), encoding='utf-8')


def install(repo, game, input_path, snapshot, output):
    validate_cook(repo, snapshot, game)
    mod = game / 'mods/modCustomizeControllerScheme'
    if (mod.exists() and any(p.is_file() for p in mod.rglob('*'))) or (game / MENU).exists():
        raise SchemeError('Existing mod requires its ownership journal')
    legacy = game / 'mods/modDarkSoulsControllerScheme'
    if legacy.exists() and any(p.is_file() for p in legacy.rglob('*')):
        raise SchemeError('Conflicting legacy mod must be isolated using its existing guarded workflow')
    raw = input_path.read_bytes()
    outputs, receipt = prepare(repo, game / 'bin/config/r4game/legacy/base/input_qwerty.ini', raw.decode('utf-8-sig'))
    for relative, text in outputs.items():
        if relative.startswith('src/') and (repo / relative).read_bytes() != text.encode('utf-8'):
            raise SchemeError('Prepared runtime differs from current compiled sources')
    receipt['personal_input_sha256'] = hashlib.sha256(raw).hexdigest()
    entries = [(game / (CONTENT + name), None, (snapshot / ('packed/' + CONTENT + name)).read_bytes()) for name in PAYLOADS]
    entries += [(game / MENU, None, outputs['src/menu/modControllerCustomizer.xml'].encode('utf-8')),
                (input_path, digest(input_path), raw + outputs['full-scheme-appendix.ini'].encode('utf-8'))]
    metadata = {'Purpose': 'ControllerCustomizerPhase11Standalone', 'SelectionSchemaVersion': 2,
                'GamePath': str(game.resolve()), 'InputPath': str(input_path.resolve()),
                'CandidateDirectory': str((output / 'candidate').resolve()), 'CookSnapshot': str(snapshot.resolve()),
                'RuntimeLoadVerified': False, 'NativeParityVerified': False, 'ReleaseVerified': False}
    write_plan(output, entries, metadata)
    stage = output / 'candidate'
    stage.mkdir()
    (stage / 'full-scheme-appendix.ini').write_bytes(outputs['full-scheme-appendix.ini'].encode('utf-8'))
    (stage / 'candidate.json').write_text(json.dumps(receipt, indent=2), encoding='utf-8')


def change(repo, journal, snapshot, output, restore=False):
    state = load_install(journal)
    input_path = Path(state['InputPath'])
    # Ownership is semantic after engine numeric formatting; unrelated edits survive.
    stripped = owned_input(input_path, Path(state['CandidateDirectory']))
    entries = []
    if restore:
        for item in state['Items']:
            target = Path(item['Target'])
            if target.resolve() == input_path.resolve():
                data = Path(item['Backup']).read_bytes() if digest(target) == item['InstalledSha256'] else stripped
            else:
                data = Path(item['Backup']).read_bytes() if item['OriginalSha256'] is not None else None
            entries.append((target, digest(target), data))
        state['Restored'] = True
    else:
        cook = validate_cook(repo, snapshot, Path(state['GamePath']))
        for item in state['Items']:
            target = Path(item['Target'])
            name = target.name
            if name in PAYLOADS:
                data = (snapshot / ('packed/' + CONTENT + name)).read_bytes()
            elif target.resolve() == input_path.resolve():
                continue  # Never rewrite personal input during artifact-only updates.
            else:
                data = (repo / 'src/menu/modControllerCustomizer.xml').read_bytes()
                if digest(target) != hashlib.sha256(data).hexdigest():
                    raise SchemeError('Menu/alias schema changes require explicit migration')
            entries.append((target, digest(target), data))
            item['InstalledSha256'] = hashlib.sha256(data).hexdigest()
        state['CookSnapshot'] = str(snapshot.resolve())
        state['RuntimeLoadVerified'] = False
    entries.append((journal, digest(journal), json.dumps(state, indent=2).encode('utf-8')))
    write_plan(output, entries, {'Purpose': 'ControllerCustomizerPhase11StandaloneRestore' if restore else 'ControllerCustomizerPhase11StandaloneUpdate',
                                 'InstallJournal': str(journal.resolve())})


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=('install', 'update', 'restore'))
    parser.add_argument('--repo', type=Path, required=True)
    parser.add_argument('--game', type=Path)
    parser.add_argument('--input', type=Path)
    parser.add_argument('--cook', type=Path)
    parser.add_argument('--journal', type=Path)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    if args.action == 'install':
        if not all((args.game, args.input, args.cook)):
            parser.error('install requires --game, --input and --cook')
        install(args.repo.resolve(), args.game.resolve(), args.input.resolve(), args.cook.resolve(), args.output.resolve())
    else:
        if not args.journal or (args.action == 'update' and not args.cook):
            parser.error('update requires --journal/--cook; restore requires --journal')
        change(args.repo.resolve(), args.journal.resolve(), args.cook.resolve() if args.cook else None,
               args.output.resolve(), args.action == 'restore')
    print('PASS: standalone transaction prepared; live files untouched')


if __name__ == '__main__':
    main()
