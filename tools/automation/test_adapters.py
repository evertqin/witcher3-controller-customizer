import json
from pathlib import Path
import tempfile
import unittest
import os

from editor_cook import fresh_log
from probe_session import validate_steps, verify_journal
from assertions import parse_ride, parse_fallback, parse_console_prompt
from menu_session import require_labels, preset_index, selected_preset
from game_test import matches_fixture, load_fixture
from save_fixture import make_fixture


class AdapterTests(unittest.TestCase):
    def test_generated_fixture_pins_exact_date_and_rejects_other_save_types(self):
        with tempfile.TemporaryDirectory(dir=os.environ.get('W3_TEST_TMP')) as scratch:
            root = Path(scratch)
            save = root / 'ManualSave_fixture.sav'
            save.write_bytes(b'pinned save')
            fixture = make_fixture(save, 'Fixture quest', ['Gameplay label'])
            from datetime import datetime
            stamp = datetime.fromisoformat(fixture['timestamp_local'])
            text = f'Fixture quest - {stamp:%A, %B} {stamp.day}, {stamp.year} {stamp.hour % 12 or 12}:{stamp:%M:%S %p} Manual Save Slot'
            self.assertTrue(matches_fixture(text, fixture))
            self.assertFalse(matches_fixture(text.replace('Manual Save Slot', 'Autosave Slot'), fixture))
            autosave = root / 'AutoSave_fixture.sav'
            autosave.write_bytes(b'other')
            with self.assertRaises(ValueError):
                make_fixture(autosave, 'Fixture quest', ['Gameplay label'])
            fixture_path = root / 'fixture.json'
            fixture_path.write_text(json.dumps(dict(fixture, hud_labels=[])), encoding='utf-8')
            with self.assertRaises(ValueError):
                load_fixture(fixture_path)

    def test_console_prompt_requires_exact_command(self):
        parse_console_prompt('> ccProbeRideReset()', 'ccProbeRideReset()')
        for text in ['', '> ccProbeRideStatus()', '> ccProbeRideRese()',
                     '> ccProbeRideReset() previous command']:
            with self.assertRaises(RuntimeError):
                parse_console_prompt(text, 'ccProbeRideReset()')

    def test_preset_caption_handles_only_known_glyph_ambiguity(self):
        self.assertEqual(selected_preset('Altl: L3 to ride, A to interact'), 'Alt1')
        for text in ['Alt2: L3', 'Alt11: L3', 'Current: A Alt1: L3', 'No selection']:
            with self.assertRaises(RuntimeError):
                selected_preset(text)

    def test_fallback_requires_both_last_valid_cases_and_restoration(self):
        parse_fallback('CC fallback: valid=1/0; invalid=1/0; restored=yes')
        parse_fallback('CC fallback: valid=1/0; invalid=1/0; restored-yes')
        for text in ['CC fallback: valid=1/0; invalid=0/0; restored=yes',
                     'CC fallback: valid=1/0; invalid=1/0; restored=no',
                     'CC fallback: valid=1/0; invalid=1/0; restored=yesterday']:
            with self.assertRaises(RuntimeError):
                parse_fallback(text)

    def test_preset_navigation_refuses_ambiguous_or_unknown_order(self):
        self.assertEqual(preset_index(['SETTINGS', 'SOUND', 'GAMEPLAY', 'CONTROLLER CUSTOMIZER', 'BACK']), 2)
        self.assertEqual(preset_index(['4}', 'SETTINGS', 'SOUND', 'GAMEPLAY', 'CONTROLLER CUSTOMIZER', 'BACK']), 2)
        for lines in [['SOUND', 'BACK'], ['SOUND', 'Unknown', 'CONTROLLER CUSTOMIZER', 'BACK'],
                      ['SOUND', 'CONTROLLER CUSTOMIZER', 'CONTROLLER CUSTOMIZER', 'BACK'],
                      ['SETTINGS', 'SETTINGS', 'SOUND', 'CONTROLLER CUSTOMIZER', 'BACK']]:
            with self.assertRaises(RuntimeError):
                preset_index(lines)

    def test_exact_fixture_rejects_other_dates_times_and_autosaves(self):
        text = 'An Invitation from Keira Metz - Sunday, October 1 1, 2026 7:10:06 AM Manual Save Slot'
        self.assertTrue(matches_fixture(text))
        for wrong in [text.replace('7:10:06', '7:33:37'), text.replace('2026', '2025'),
                      text.replace('Manual Save', 'Autosave'), text.replace('AM', 'PM')]:
            self.assertFalse(matches_fixture(wrong))

    def test_new_mounted_fixture_retains_exact_timestamp_guard(self):
        fixture = json.loads(Path(__file__).with_name('mounted-clear-111554.json').read_text(encoding='utf-8'))
        text = 'An Invitation from Keira Metz - Sunday, October 11, 2026 11:15:54 AM Manual Save Slot'
        self.assertTrue(matches_fixture(text, fixture))
        self.assertTrue(matches_fixture(text.replace('11:15:54', '1 1:15:54'), fixture))
        for wrong in [text.replace('2026', '2025'), text.replace('11:15:54', '7:10:06'),
                      text.replace('Manual Save', 'Autosave'), text.replace('AM', 'PM')]:
            self.assertFalse(matches_fixture(wrong, fixture))

    def test_menu_boundary_refuses_gameplay_and_partial_menus(self):
        labels = ['Resume', 'Save Game', 'Load Game', 'Settings']
        require_labels('RESUME\nSAVE GAME\nLOAD GAME\nSETTINGS', labels)
        for text in ['Horse Stamina An Invitation from Keira Metz', 'Resume Load Game Settings']:
            with self.assertRaisesRegex(RuntimeError, 'not recognized'):
                require_labels(text, labels)

    def setUp(self):
        base = Path(os.environ.get('W3_TEST_TMP', tempfile.gettempdir()))
        base.mkdir(parents=True, exist_ok=True)
        self.temp = tempfile.TemporaryDirectory(dir=base)
        self.root = Path(self.temp.name)

    def tearDown(self):
        self.temp.cleanup()

    def test_old_and_concurrent_cooks_cannot_supply_fresh_evidence(self):
        old = self.root / 'publish old.log'
        old.write_text('completed')
        self.assertIsNone(fresh_log(self.root, {old.name}))
        (self.root / 'publish new.log').write_text('fresh')
        self.assertEqual(fresh_log(self.root, {old.name}).name, 'publish new.log')
        (self.root / 'publish another.log').write_text('concurrent')
        with self.assertRaises(RuntimeError):
            fresh_log(self.root, {old.name})

    def test_changed_installation_refuses_probe_input(self):
        artifact = self.root / 'blob'
        artifact.write_bytes(b'changed')
        journal = self.root / 'journal.json'
        journal.write_text(json.dumps(dict(Restored=False, InstallationComplete=True,
                         GamePath=str(self.root), Items=[dict(RelativePath='blob', InstalledSha256='0'*64)])))
        with self.assertRaisesRegex(RuntimeError, 'Owned file changed'):
            verify_journal(journal)

    def test_journal_cannot_read_outside_game(self):
        journal = self.root / 'journal.json'
        journal.write_text(json.dumps(dict(Restored=False, InstallationComplete=True,
                         GamePath=str(self.root), Items=[dict(RelativePath='../other', InstalledSha256='0'*64)])))
        with self.assertRaisesRegex(RuntimeError, 'escapes'):
            verify_journal(journal)

    def test_unexpected_console_commands_refused_before_delivery(self):
        with self.assertRaises(ValueError):
            validate_steps([dict(kind='console', command='savegame()')])
        validate_steps([dict(kind='settings_cycle')])
        with self.assertRaises(ValueError):
            validate_steps([dict(kind='settings_cycle', keys=['DELETE'])])

    def test_baseline_or_missing_release_cannot_pass_routed_assertion(self):
        text = ('source=horse handlers; callbacks=10; Canter press/release=3/3; '
                'Gallop press/release=2/2; query mismatches=0; '
                'last=CC_PROBE_Alt1_Horse/Canter/None')
        self.assertEqual(parse_ride(text, 'CC_PROBE_Alt1_Horse')['callbacks'], 10)
        self.assertEqual(parse_ride(text.replace('source=horse', 'source-horse'), 'CC_PROBE_Alt1_Horse')['callbacks'], 10)
        self.assertEqual(parse_ride(text.replace('callbacks=10', 'callbacks-10'), 'CC_PROBE_Alt1_Horse')['callbacks'], 10)
        for broken in [text.replace('callbacks=10;', 'pattern callbacks=10;'),
                       text + '; callbacks=10;']:
            with self.assertRaises(RuntimeError):
                parse_ride(broken, 'CC_PROBE_Alt1_Horse')
        for broken in [text.replace('CC_PROBE_Alt1_Horse', 'Horse'),
                       text.replace('3/3', '3/2'), text.replace('mismatches=0', 'mismatches=1'),
                       text.replace('callbacks=10', 'callbacks=0'),
                       text.replace('callbacks=10', 'callbacks=20').replace('3/3', '6/6').replace('2/2', '4/4')]:
            with self.assertRaises(RuntimeError):
                parse_ride(broken, 'CC_PROBE_Alt1_Horse')


if __name__ == '__main__':
    unittest.main()
