import unittest

from assertions import parse_primitives
from temporary_primitive import restored_input
from full_schemes import SchemeError


class PrimitiveAssertionTests(unittest.TestCase):
    def test_exact_counts_query_keys_context_required(self):
        text = 'CC primitives: P=1/1; D3=1/1; D5=0/0; mismatch=0; keys=3; context=1'
        self.assertEqual(parse_primitives(text, [[1, 1], [1, 1], [0, 0]])['keys'], 3)
        for bad in (text.replace('mismatch=0', 'mismatch=1'), text.replace('context=1', 'context=0'),
                    text.replace('keys=3', 'keys=2'), text.replace('D5=0/0', 'D5=1/1')):
            with self.subTest(text=bad), self.assertRaises(RuntimeError):
                parse_primitives(bad, [[1, 1], [1, 1], [0, 0]])

    def test_observed_numeric_glyphs_are_scoped_to_fields(self):
        text = '2 Cat CC primitives: P=l/l; D3=O/O; D5=O/O; mismatch=0; keys=3; context-I'
        self.assertEqual(parse_primitives(text, [[1, 1], [0, 0], [0, 0]])['press'], [1, 1])
        for bad in (text.replace('P=l/l', 'P=l/O'), text + '; P=l/l',
                    text.replace('CC primitives:', 'Other notification:')):
            with self.subTest(text=bad), self.assertRaises(RuntimeError):
                parse_primitives(bad, [[1, 1], [0, 0], [0, 0]])

    def test_restore_retains_personal_edit_and_refuses_owned_drift(self):
        original = b'[Horse]\nIK_W=(Action=Canter)\n'
        installed = original + b'[CC_PRIMITIVE_Horse]\nIK_Pad_X_SQUARE=(Action=CCP_X_D5,State=Duration,IdleTime=0.5)\n'
        self.assertEqual(restored_input(installed, installed, original), original)
        changed = installed.replace(b'IK_W=(Action=Canter)', b'IK_W=(Action=Canter)\nIK_F3=(Action=MyShortcut)')
        self.assertIn(b'IK_F3=(Action=MyShortcut)', restored_input(changed, installed, original))
        with self.assertRaises(SchemeError):
            restored_input(installed.replace(b'IdleTime=0.5', b'IdleTime=0.8'), installed, original)
