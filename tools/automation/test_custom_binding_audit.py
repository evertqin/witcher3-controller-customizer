from copy import deepcopy
import unittest

from custom_binding_audit import audit
from custom_bindings import CustomDraft, from_scheme
from full_schemes import expand_lineage, parse
from unittest.mock import patch


CATALOG = {
    'Contexts': [{'Id': 'horse', 'NativeName': 'Horse'}],
    'Actions': [{'Id': 'canter', 'NativeName': 'Canter'}],
    'Bindings': [{'Id': 'horse.canter', 'ContextId': 'horse', 'ActionId': 'canter',
                  'SharedSequence': True}], 'DiagramGroups': []}
PERSONAL = '''[Base]
IK_Pad_A_CROSS=(Action=Canter)
IK_Pad_RightThumb=(Action=TrackQuest)
IK_Pad_RightThumb=(Action=CameraLock)
IK_Pattern_HorseAcceleration=(Action=Canter)
IK_W=(Action=Canter)
[Horse]
DERIVED_FROM=Base
IK_Pad_RightAxisX=(Action=CameraX)
'''


class CustomBindingAuditTests(unittest.TestCase):
    def setUp(self):
        self.profile = expand_lineage(parse(PERSONAL))
        self.config = {'schema_version': 1, 'bindings': [
            {'id': 'horse.canter', 'button': 'r3', 'gesture': 'press', 'seconds': None}]}

    def test_inherited_unowned_actions_and_patterns_are_reported(self):
        original = deepcopy(self.profile)
        report = audit(self.config, CATALOG, self.profile, PERSONAL)
        self.assertEqual({r['record'] for r in report['conflicts']},
                         {'(Action=TrackQuest)', '(Action=CameraLock)'})
        self.assertEqual(len(report['pattern_dependencies_to_trace']), 1)
        self.assertFalse(report['runtime_apply_available'])
        self.assertEqual(self.profile, original)

    def test_later_personal_addition_and_duplicate_are_not_discarded(self):
        baseline = expand_lineage(parse('[Horse]\nIK_Pad_A_CROSS=(Action=Canter)\n'))
        report = audit(self.config, CATALOG, baseline, PERSONAL)
        self.assertEqual(len(report['conflicts']), 2)
        self.assertEqual({r['source'] for r in report['conflicts']}, {'personal'})
        duplicate = PERSONAL.replace('IK_Pad_RightThumb=(Action=TrackQuest)',
                                     'IK_Pad_RightThumb=(Action=TrackQuest)\nIK_Pad_RightThumb=(Action=TrackQuest)')
        report = audit(self.config, CATALOG, self.profile, duplicate)
        self.assertEqual(len(report['conflicts']), 3)

    def test_unchanged_and_free_button_are_not_runtime_claims(self):
        self.config['bindings'][0]['button'] = 'a'
        report = audit(self.config, CATALOG, self.profile, PERSONAL)
        self.assertEqual(report['changed_bindings'], [])
        self.config['bindings'][0]['button'] = 'dpad-left'
        report = audit(self.config, CATALOG, self.profile, PERSONAL)
        self.assertEqual(report['conflicts'], [])
        self.assertTrue(report['pattern_dependencies_to_trace'])
        self.assertFalse(report['runtime_verified'])

    def test_three_scheme_projection_reads_native_duration(self):
        for scheme, key in [('vanilla', 'IK_Pad_A_CROSS'), ('darksoul', 'IK_Pad_A_CROSS'),
                            ('darksoul-alt1', 'IK_Pad_LeftThumb')]:
            profile = expand_lineage(parse(f'[Horse]\n{key}=(Action=Canter,State=Duration,IdleTime=0.5)\n'))
            with patch('custom_bindings.scheme_profile', return_value=profile):
                config = from_scheme(CATALOG, None, None, scheme)
            self.assertEqual(config['bindings'][0]['button'], 'l3' if scheme.endswith('alt1') else 'a')
            self.assertEqual(config['bindings'][0]['seconds'], 0.5)

    def test_restore_scheme_stages_without_changing_active_and_cancel_restores(self):
        editor = CustomDraft(CATALOG, self.config)
        with patch('custom_bindings.scheme_profile', return_value=self.profile):
            editor.restore_scheme(None, None, 'vanilla')
        self.assertEqual(editor.pending['bindings'][0]['button'], 'a')
        self.assertEqual(editor.active, self.config)
        editor.cancel()
        self.assertEqual(editor.pending, self.config)


if __name__ == '__main__':
    unittest.main()
