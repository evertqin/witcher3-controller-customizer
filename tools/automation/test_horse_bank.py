from collections import Counter
import unittest

from assertions import parse_horse_bank
from full_schemes import SchemeError, parse
from primitive_bank import bank, CONTEXT, SOURCE
from probe_session import validate_steps
from temporary_primitive import restored_input


class HorseBankTests(unittest.TestCase):
    def fixture(self):
        return f"[{SOURCE}]\n" + "\n".join((
            "IK_Pad_X_SQUARE=(Action=VehicleCastSign)",
            "IK_Pad_LeftThumb=(Action=EnablePhotoMode_Step1)",
            "IK_Pad_LeftThumb=(Action=Gallop,IdleTime=0.300000,State=Duration)",
            "IK_Pad_LeftThumb=(Action=Canter)", "IK_Pad_LeftThumb=(Action=Follow)",
            "IK_LShift=(Action=Gallop,State=Duration,IdleTime=0.3)",
            "IK_LShift=(Action=Canter)", "IK_Pattern_HorseAcceleration=(Action=Canter)",
            "IK_Pattern_HorseAcceleration=(Action=Gallop,State=Duration,IdleTime=0.3)",
            "IK_Pad_DigitUp=(Action=DrinkPotion1)", "IK_Pad_DigitUp=(Action=DrinkPotion1)")) + "\n"

    def test_relocates_every_occupied_record_preserving_originals(self):
        original = self.fixture()
        staged, receipt = bank(original, 'horse-swap')
        self.assertTrue(staged.startswith(original))
        source, target = parse(staged)[SOURCE], parse(staged)[CONTEXT]
        untouched = lambda rows: Counter(r.signature for r in rows if r.key not in
            ('IK_Pad_X_SQUARE', 'IK_Pad_LeftThumb') and 'Action=CCP_' not in r.value)
        self.assertEqual(untouched(source), untouched(target))
        keys = lambda action: [(r.key, dict(r.signature[1])) for r in target
                              if dict(r.signature[1]).get('Action') == action]
        self.assertEqual(keys('VehicleCastSign')[0][0], 'IK_Pad_LeftThumb')
        self.assertEqual(keys('EnablePhotoMode_Step1')[0][0], 'IK_Pad_X_SQUARE')
        gallop = [params for key, params in keys('Gallop') if key == 'IK_Pad_X_SQUARE']
        self.assertEqual(gallop, [{'Action': 'Gallop', 'IdleTime': '0.5', 'State': 'Duration'}])
        self.assertTrue(receipt['gameplay_remapping'])
        self.assertFalse(receipt['runtime_verified'])
        self.assertEqual(restored_input(staged.encode(), staged.encode(), original.encode()), original.encode())

    def test_unknown_or_changed_occupants_refuse(self):
        original = self.fixture()
        for changed in (original + 'IK_Pad_X_SQUARE=(Action=PersonalShortcut)\n',
                        original + 'IK_Pad_LeftThumb=(Action=Canter)\n',
                        original.replace('0.300000', '0.4'),
                        original.replace('Action=VehicleCastSign', 'Action=Use')):
            with self.subTest(changed=changed), self.assertRaises(SchemeError):
                bank(changed, 'horse-swap')
        with self.assertRaises(SchemeError):
            bank(original, 'unknown')

    def test_positive_negative_and_keyboard_counts_stay_exact(self):
        template = 'CC horsebank: Canter={}; Gallop={}; mismatch=0; foreign=0; keys=3; context=1'
        for canter, gallop, expected in (('1/1', '0/0', [[1,1],[0,0]]),
                                       ('1/1', '1/1', [[1,1],[1,1]]),
                                       ('O/O', 'O/O', [[0,0],[0,0]])):
            text = template.format(canter, gallop)
            self.assertEqual(parse_horse_bank(text, expected)['canter'], expected[0])
            for bad in (text.replace('keys=3', 'keys=2'), text.replace('foreign=0', 'foreign=1'),
                        text.replace('mismatch=0', 'mismatch=1'), text.replace('context=1', 'context=0'),
                        text + '; Canter=0/0;', text.replace('CC horsebank:', 'Other:')):
                with self.subTest(bad=bad), self.assertRaises(RuntimeError):
                    parse_horse_bank(bad, expected)
        with self.assertRaises(RuntimeError):
            parse_horse_bank(template.format('2/2', '1/1'), [[1,1],[1,1]])

    def test_scenario_validation_refuses_uncalibrated_or_ambiguous_assertions(self):
        validate_steps([{'kind':'keyboard_ride','seconds':0.4},
                        {'kind':'console','command':'ccHorseBankStatus()', 'expected_horse_bank':[[0,0],[0,0]]}])
        for bad in ({'kind':'keyboard_ride','seconds':True}, {'kind':'keyboard_ride','seconds':2},
                    {'kind':'console','command':'ccPrimitiveStatus()', 'expected_horse_bank':[[0,0],[0,0]]},
                    {'kind':'console','command':'ccHorseBankStatus()', 'expected_horse_bank':[[True,0],[0,0]]}):
            with self.subTest(bad=bad), self.assertRaises(ValueError):
                validate_steps([bad])


if __name__ == '__main__':
    unittest.main()
