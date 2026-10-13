from collections import Counter
import unittest

from full_schemes import SchemeError, parse
from primitive_bank import bank, CONTEXT, SOURCE


class PrimitiveBankTests(unittest.TestCase):
    def test_preserves_every_original_and_duplicate_record(self):
        text = f'[{SOURCE}]\nIK_W=(Action=Canter)\nIK_W=(Action=Canter)\nIK_Pad_LeftThumb=(Action=Canter)\n'
        result, receipt = bank(text)
        self.assertTrue(result.startswith(text))
        parsed = parse(result)
        self.assertEqual(Counter(r.signature for r in parsed[SOURCE]),
                         Counter(r.signature for r in parse(text)[SOURCE]))
        self.assertEqual(len(parsed[CONTEXT]), 6)
        self.assertEqual(receipt['contexts_after'], 2)
        self.assertFalse(receipt['gameplay_remapping'])
        with self.assertRaises(SchemeError):
            bank(result)

    def test_refuses_capacity_inheritance_and_existing_action(self):
        base = f'[{SOURCE}]\nIK_X=(Action=Stop)\n'
        for text in (base + ''.join(f'[Extra{i}]\nIK_W=(Action=Move)\n' for i in range(127)),
                     base + 'DERIVED_FROM=Other\n',
                     base + 'IK_Pad_X_SQUARE=(Action=CCP_X_PRESS)\n'):
            with self.subTest(text=text[:80]), self.assertRaises(SchemeError):
                bank(text)
