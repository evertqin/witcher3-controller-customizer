"""Cook current REDkit sources, update owned probe files, and run a fresh game test."""
import argparse
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import subprocess
import sys
import uuid

from probe_session import verify_journal, scenario_timeout


def execute(argv, directory, name, timeout):
    environment = None
    if Path(argv[0]).name.casefold() == 'powershell.exe':
        environment = dict(os.environ)
        # PS 7's inherited module path can hide PS 5.1's Get-FileHash function.
        environment['PSModulePath'] = str(Path(os.environ['SystemRoot']) / 'System32/WindowsPowerShell/v1.0/Modules')
    completed = subprocess.run(argv, capture_output=True, text=True, timeout=timeout, env=environment)
    (directory / (name + '.log')).write_text(completed.stdout + completed.stderr, encoding='utf-8')
    if completed.returncode:
        raise RuntimeError(name + ' failed; see captured log')
    return completed.stdout.strip().splitlines()[-1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('config', type=Path)
    parser.add_argument('scenario', type=Path, nargs='?', default=Path(__file__).with_name('phase1-smoke.json'))
    parser.add_argument('--sync-sources', action='store_true', help='Back up and sync only owned editor scripts before cooking')
    parser.add_argument('--journal', type=Path, required=True)
    parser.add_argument('--save', type=Path, required=True)
    parser.add_argument('--fixture', type=Path)
    parser.add_argument('--editor-pid', type=int)
    parser.add_argument('--output', type=Path, default=Path(__file__).parent / 'evidence/development')
    args = parser.parse_args()
    config = json.loads(args.config.read_text(encoding='utf-8'))
    verify_journal(args.journal)
    args.output.mkdir(parents=True, exist_ok=True)
    lock = args.output / '.development.lock'
    with lock.open('x') as stream:
        stream.write(str(__import__('os').getpid()))
    directory = args.output.resolve() / (datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ') + '-' + uuid.uuid4().hex[:8])
    directory.mkdir()
    report = dict(status='running', gameplay_verified=False, scope='cook_install_native_callbacks')
    try:
        root = Path(__file__).parent
        if args.sync_sources:
            installed = verify_journal(args.journal)
            execute(['powershell.exe', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File',
                     str(Path(config['repo']) / 'tools/Sync-EditorSources.ps1'),
                     '-ConfigFile', str(args.config.resolve()), '-PreviousCookSnapshot', installed['CookSnapshot']],
                    directory, 'source-sync', 90)
        command = [sys.executable, str(root / 'editor_cook.py'), str(args.config.resolve()),
                   '--output', str(directory / 'editor')]
        if args.editor_pid:
            command.extend(['--editor-pid', str(args.editor_pid)])
        receipt = Path(execute(command, directory, 'cook', 660))
        cook = json.loads(receipt.read_text(encoding='utf-8'))
        report['cook_receipt'] = str(receipt)
        snapshot = cook['snapshot']['Snapshot']
        execute(['powershell.exe', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File',
                 str(Path(config['repo']) / 'tools/Update-RuntimeProbe.ps1'),
                 '-JournalFile', str(args.journal), '-CookSnapshot', snapshot], directory, 'install', 90)
        report['installed_snapshot'] = snapshot
        verify_journal(args.journal)
        exe = Path(config['game']) / 'bin/x64_dx12/witcher3.exe'
        game_command = [sys.executable, str(root / 'game_test.py'), str(args.scenario.resolve()),
                               '--journal', str(args.journal), '--exe', str(exe), '--save', str(args.save),
                               '--ffmpeg', config['ffmpeg'], '--output', str(directory / 'game')]
        if args.fixture:
            game_command.extend(['--fixture', str(args.fixture.resolve())])
        receipt = Path(execute(game_command,
                              directory, 'game-test', scenario_timeout(json.loads(args.scenario.read_text(encoding='utf-8'))['steps']) + 420))
        report['game_receipt'] = str(receipt)
        game = json.loads(receipt.read_text(encoding='utf-8'))
        probe = json.loads(Path(game['probe_receipt']).read_text(encoding='utf-8'))
        assertions = [step['assertion'] for step in probe['steps'] if 'assertion' in step]
        if not any(item.get('scope') == 'native_callback_and_query_only' for item in assertions):
            raise RuntimeError('Scenario collected evidence without callback assertions')
        report.update(status='native_callbacks_verified', assertions=assertions,
                      owned_game_closed=game['owned_game_closed'], save_unchanged=game['save_unchanged'])
    except Exception as error:
        report.update(status='failed', error=str(error))
    finally:
        (directory / 'result.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
        lock.unlink()
    print(directory / 'result.json')
    return 0 if report['status'] == 'native_callbacks_verified' else 1


if __name__ == '__main__':
    raise SystemExit(main())
