import hashlib
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from full_scheme_delivery import (CONTENT, MENU, PAYLOADS, change, digest, install,
                                  validate_cook)
from full_schemes import Record, SchemeError, observed_serialization, parse
from remove_scheme_aliases import remove_aliases


def write(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data)


class DeliveryTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.repo, self.game, self.cook = [self.root / n for n in ('repo', 'game', 'cook')]
        self.input = self.root / 'profile/input.settings'
        write(self.input, b'[Horse]\nIK_F2=(Action=Personal)\n')
        self.outputs = {f'src/scripts/local/controllerCustomizer/{i}.ws': f'source-{i}' for i in range(8)}
        self.outputs['src/menu/modControllerCustomizer.xml'] = '<menu />'
        self.aliases = [{'scheme': s, 'canonical': f'Context{i}', 'alias': f'CC_SCHEME_{label}_Context{i}'}
                        for s, label in [('vanilla', 'Vanilla'), ('darksoul', 'DarkSoul'), ('darksoul-alt1', 'DarkSoulAlt1')]
                        for i in range(28)]
        self.outputs['full-scheme-appendix.ini'] = ''.join(f"[{a['alias']}]\nIK_Pad_A_CROSS=(Action=Canter)\n" for a in self.aliases)
        for relative, body in self.outputs.items():
            write(self.repo / relative, body.encode())
        hooks = {}
        for i in range(7):
            path = self.game / f'content/content0/scripts/hook{i}.ws'
            write(path, f'hook-{i}'.encode())
            hooks[f'hook{i}.ws'] = digest(path)
        write(self.repo / 'tools/compiler-toolchain.json', json.dumps({'CompilerSha256': 'compiler', 'BaseScriptSha256': hooks}).encode())
        write(self.cook / 'cook.log', b'Script phase passed; outer diagnostics retained')
        payloads = {}
        for name in PAYLOADS:
            path = self.cook / ('packed/' + CONTENT + name)
            write(path, name.encode())
            payloads[name] = digest(path)
        receipt = {'SchemaVersion': 2, 'EvidenceKind': 'RedkitEditorCook', 'ScriptCompilationVerified': True,
                   'SourceTextEquivalenceVerified': True, 'UseLooseScripts': False, 'ScriptCompilationErrors': [],
                   'CompilerSha256': 'compiler', 'ObservedBlobRelativePath': CONTENT + PAYLOADS[0],
                   'CookLogSha256': digest(self.cook / 'cook.log'), 'BaseHookSha256': hooks,
                   'CanonicalSourceSha256': {k.removeprefix('src/scripts/'): digest(self.repo / k)
                                             for k in self.outputs if k.startswith('src/scripts/')},
                   'FileSha256': payloads, 'BlobLength': len(PAYLOADS[0])}
        write(self.cook / 'cook.json', json.dumps(receipt).encode())

    def prepare_install(self, name='install-prepared'):
        receipt = {'aliases': self.aliases, 'files': {'full-scheme-appendix.ini':
                   hashlib.sha256(self.outputs['full-scheme-appendix.ini'].encode()).hexdigest()}}
        with patch('full_scheme_delivery.prepare', return_value=(self.outputs, receipt)):
            output = self.root / name
            install(self.repo, self.game, self.input, self.cook, output)
        return output

    def apply_fixture(self, prepared, directory):
        plan = json.loads((prepared / 'transaction.json').read_text())
        directory.mkdir()
        items = []
        for i, entry in enumerate(plan['Entries']):
            path = Path(entry['Target'])
            self.assertEqual(digest(path), entry['BeforeSha256'])
            backup = directory / f'backups/{i}'
            if path.exists():
                write(backup, path.read_bytes())
            data = Path(entry['Payload']).read_bytes() if entry['Payload'] else None
            if data is None:
                path.unlink()
            else:
                write(path, data)
            items.append({'Target': str(path), 'Backup': str(backup), 'OriginalSha256': entry['BeforeSha256'], 'InstalledSha256': digest(path)})
        journal = directory / 'files.json'
        write(journal, json.dumps({**plan['Metadata'], 'InstallationComplete': True, 'RolledBack': False,
                                  'Restored': False, 'Items': items}).encode())
        return journal

    def test_install_update_restore_preserves_backups_and_later_personal_edits(self):
        original = self.input.read_bytes()
        prepared = self.prepare_install()
        self.assertEqual(self.input.read_bytes(), original)  # Preparation has no live writes.
        journal = self.apply_fixture(prepared, self.root / 'installation')
        first = json.loads(journal.read_text())
        self.input.write_bytes(self.input.read_bytes() + b'[Later]\nIK_F3=(Action=Shortcut)\n')
        before = self.input.read_bytes()
        update = self.root / 'update-prepared'
        change(self.repo, journal, self.cook, update)
        self.assertEqual(self.input.read_bytes(), before)
        self.assertFalse(any(Path(e['Target']) == self.input for e in json.loads((update / 'transaction.json').read_text())['Entries']))
        self.apply_fixture(update, self.root / 'update')
        self.assertEqual(json.loads(journal.read_text())['Items'], first['Items'])
        restore = self.root / 'restore-prepared'
        change(self.repo, journal, None, restore, restore=True)
        self.apply_fixture(restore, self.root / 'restore')
        self.assertEqual(self.input.read_bytes(), original + b'[Later]\nIK_F3=(Action=Shortcut)\n')
        self.assertFalse((self.game / (CONTENT + PAYLOADS[0])).exists())
        self.assertTrue(json.loads(journal.read_text())['Restored'])

    def test_changed_owned_payload_or_alias_refuses_before_stage(self):
        journal = self.apply_fixture(self.prepare_install(), self.root / 'installation')
        target = self.game / (CONTENT + PAYLOADS[0])
        original = target.read_bytes()
        target.write_bytes(b'foreign')
        output = self.root / 'refused'
        with self.assertRaises(SchemeError):
            change(self.repo, journal, self.cook, output)
        self.assertFalse(output.exists())
        target.write_bytes(original)
        self.input.write_bytes(self.input.read_bytes().replace(b'Action=Canter', b'Action=Use', 1))
        with self.assertRaises(SchemeError):
            change(self.repo, journal, None, output, restore=True)
        self.assertFalse(output.exists())

    def test_cook_source_payload_and_hook_drift_refuse(self):
        validate_cook(self.repo, self.cook, self.game)
        for path in (self.repo / 'src/scripts/local/controllerCustomizer/0.ws',
                     self.cook / ('packed/' + CONTENT + PAYLOADS[0]),
                     self.game / 'content/content0/scripts/hook0.ws'):
            original = path.read_bytes()
            path.write_bytes(b'drift')
            with self.assertRaises(SchemeError):
                validate_cook(self.repo, self.cook, self.game)
            path.write_bytes(original)

    def test_existing_mod_and_legacy_mod_refuse_before_stage(self):
        for relative in ('mods/modCustomizeControllerScheme/foreign.ws', 'mods/modDarkSoulsControllerScheme/foreign.ws'):
            path = self.game / relative
            write(path, b'foreign')
            with self.assertRaises(SchemeError):
                self.prepare_install()
            self.assertFalse((self.root / 'install-prepared').exists())
            path.unlink()

    def test_only_exact_observed_focus_serialization_is_allowed(self):
        from collections import Counter
        expected = Counter([Record('IK_Pad_LeftTrigger', '(Action=Focus)', 1).signature])
        observed = observed_serialization(expected, 'CC_SCHEME_Vanilla_Horse')
        self.assertIsNone(observed)  # Horse also requires its exact source kick record.
        focus = observed_serialization(expected, 'CC_SCHEME_Vanilla_Exploration')
        self.assertEqual(focus, Counter([Record('IK_Pad_LeftTrigger', '(Action=Focus,Reprocess)', 1).signature]))
        self.assertEqual(observed_serialization(expected, 'CC_SCHEME_DarkSoul_Exploration'), expected)


if __name__ == '__main__':
    unittest.main()
