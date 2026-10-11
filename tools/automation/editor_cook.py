"""Cook the known REDkit project through native controls and freeze fresh evidence."""
import argparse
from datetime import datetime, timezone
import json
from pathlib import Path
import subprocess
import sys
import time
import uuid
from types import SimpleNamespace

from loop import fingerprint
from windows_ui import Desktop


def fresh_log(directory, before):
    matches = [p for p in directory.glob('publish *.log') if p.name not in before]
    if len(matches) > 1:
        raise RuntimeError('Concurrent publish logs; cook ownership ambiguous')
    return matches[0] if matches else None


def wait_for(action, timeout):
    deadline = time.monotonic() + timeout
    last = None
    while time.monotonic() < deadline:
        try:
            result = action()
            if result:
                return result
        except RuntimeError as error:
            last = error
        time.sleep(0.25)
    raise RuntimeError(f'Timed out waiting for editor state: {last}')


def cook(config, output, editor_pid=None):
    desktop = Desktop()
    exe = Path(config['editor_exe']).resolve()
    project = Path(config['project_file']).resolve()
    project_root = project.parent
    source_roots = [str(Path(config['repo']) / 'src/scripts'),
                    str(project_root / 'workspace/scripts')]
    sources = fingerprint(source_roots)
    if not sources or not project.is_file():
        raise RuntimeError('Project or sources missing')
    if desktop.windows(exe) and editor_pid is None:
        raise RuntimeError('Close existing REDkit windows; automation opens its own editor')
    if editor_pid is not None and not any(
            w['title'].startswith(project.stem + ' - ')
            for w in desktop.windows(exe, editor_pid)):
        raise RuntimeError('Explicit editor PID must have this project open')
    logs = project_root / 'logs'
    before = {p.name for p in logs.glob('publish *.log')}
    run = output.resolve() / (datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ')
                              + '-' + uuid.uuid4().hex[:8])
    run.mkdir(parents=True)
    report = {'status': 'running', 'gameplay_verified': False, 'sources': sources,
              'started_utc': datetime.now(timezone.utc).isoformat(), 'steps': []}
    process = None
    script = Path(__file__).with_name('uia.ps1')

    def window(title=None):
        return desktop.target(exe, process.pid, title)

    def click(name, automation_id, title=None, timeout=30):
        def invoke():
            target = window(title)
            desktop.uia_click(target, name, script, automation_id, native=True)
            return True
        wait_for(invoke, timeout)
        report['steps'].append(name)

    try:
        if editor_pid is None:
            if desktop.windows(exe):
                raise RuntimeError('Editor already open; supply its explicit --editor-pid or close it')
            process = subprocess.Popen([str(exe)], cwd=str(exe.parent))
        else:
            process = SimpleNamespace(pid=editor_pid, poll=lambda: None if
                                      desktop.executable(editor_pid) == str(exe) else 1)
            report['attached_to_explicit_editor_pid'] = True
        report['editor_pid'] = process.pid
        if editor_pid is None:
            click('Browse', '-30896')
            dialog = wait_for(lambda: window('Select a file'), 30)
            desktop.native_value(dialog, '1148', str(project), script)
            click('Open', '1', 'Select a file')
        main = wait_for(lambda: next((w for w in desktop.windows(exe, process.pid)
                                     if w['title'].startswith(project.stem + ' - ')), None),
                        config.get('load_timeout', 180))
        desktop.menu_invoke(main, 'Publish/Save and publish mod project')
        click('Next', '6002', '', config.get('load_timeout', 300))
        click('Start cooking', '6009', '')
        report['steps'].append('local cook; no storefront publication')

        def completed():
            if process.poll() is not None:
                raise RuntimeError('Editor exited during cooking')
            log = fresh_log(logs, before)
            if not log:
                return None
            body = log.read_text(encoding='utf-8-sig', errors='replace')
            if 'Step CreateMetadataStores has finished!' in body:
                return log
            return None

        log = wait_for(completed, config.get('cook_timeout', 240))
        if sources != fingerprint(source_roots):
            raise RuntimeError('Sources changed during cook')
        screenshot = run / 'cook-completion.png'
        desktop.screenshot(window(''), screenshot, config['ffmpeg'])
        command = [sys.executable, str(Path(__file__).with_name('snapshot_cook.py'))]
        for name, value in {'repo': config['repo'], 'editor': project_root,
                            'sdk': config['sdk'], 'game': config['game'], 'log': log,
                            'output': output / 'cooks',
                            'completion-screenshot': screenshot}.items():
            command.extend(['--' + name, str(value)])
        frozen = subprocess.run(command, capture_output=True, text=True, timeout=60)
        (run / 'snapshot.log').write_text(frozen.stdout + frozen.stderr, encoding='utf-8')
        if frozen.returncode:
            raise RuntimeError('Cook receipt validation failed; see snapshot.log')
        report.update(status='script_compilation_verified', snapshot=json.loads(frozen.stdout))
        completed_wizard = window('')
        desktop.identity_guard(completed_wizard)
        if not desktop.user.PostMessageW(completed_wizard['hwnd'], 0x10, 0, 0):
            raise RuntimeError('Completed cook wizard did not accept close request')
        report['completed_wizard_close_requested'] = True
    except Exception as error:
        report.update(status='failed', error=str(error))
    finally:
        # Leave owned editor available for inspection; never kill a user's editor.
        report['editor_left_open'] = process is not None and process.poll() is None
        report['finished_utc'] = datetime.now(timezone.utc).isoformat()
        (run / 'result.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
    print(str(run / 'result.json'))
    return report['status'] == 'script_compilation_verified'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('config', type=Path)
    parser.add_argument('--output', type=Path, default=Path(__file__).parent / 'evidence/editor')
    parser.add_argument('--editor-pid', type=int, help='Explicitly use an already loaded project')
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    lock = args.output / '.cook.lock'
    with lock.open('x') as stream:
        stream.write(str(__import__('os').getpid()))
    try:
        return 0 if cook(json.loads(args.config.read_text()), args.output, args.editor_pid) else 1
    finally:
        lock.unlink()


if __name__ == '__main__':
    sys.exit(main())
