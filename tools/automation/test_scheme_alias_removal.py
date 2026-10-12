import unittest

from full_schemes import SchemeError
from remove_scheme_aliases import remove_aliases


class RemovalTests(unittest.TestCase):
    def setUp(self):
        self.aliases = [{'scheme': scheme, 'canonical': f'Context{i}',
                         'alias': f'CC_SCHEME_{label}_Context{i}'}
                        for scheme, label in [('vanilla', 'Vanilla'), ('darksoul', 'DarkSoul'), ('darksoul-alt1', 'DarkSoulAlt1')]
                        for i in range(28)]
        self.appendix = ''.join(f"[{a['alias']}]\r\nIK_Pad_A_CROSS=(Action=Canter)\r\nIK_Pad_A_CROSS=(Action=Gallop,IdleTime=0.3)\r\n"
                                for a in self.aliases)

    def test_engine_serialization_and_unrelated_later_edits_survive(self):
        personal = '; personal header\r\n[Horse]\r\nIK_F2=(Action=MyShortcut)\r\nIK_F2=(Action=MyShortcut)\r\n'
        serialized = self.appendix.replace('(Action=Gallop,IdleTime=0.3)', '(IdleTime=0.300000,Action=Gallop)')
        extra = '; later note\r\n[NewContext]\r\nIK_F1=(Action=LaterShortcut)\r\n'
        self.assertEqual(remove_aliases(personal + serialized + extra, self.appendix, self.aliases), personal + extra)

    def test_shared_bank_removal_preserves_personal_changes(self):
        contexts = ['BASE_INTERACTIONS_HORSE', 'Horse', 'Horse_Replacer_Ciri', 'ScriptedAction'] + [f'Context{i}' for i in range(24)]
        aliases = [{'scheme': scheme, 'canonical': c,
                    'alias': f"CC_SCHEME_{'DarkSoul' if scheme == 'darksoul-alt1' and c.startswith('Context') else label}_{c}"}
                   for scheme, label in [('vanilla', 'Vanilla'), ('darksoul', 'DarkSoul'), ('darksoul-alt1', 'DarkSoulAlt1')]
                   for c in contexts]
        names = {a['alias'] for a in aliases}
        self.assertEqual(len(names), 60)
        appendix = ''.join(f"[{name}]\nIK_Pad_A_CROSS=(Action=Canter)\n" for name in sorted(names))
        personal = '[Personal]\nIK_F2=(Action=LaterShortcut)\n'
        self.assertEqual(remove_aliases(personal + appendix, appendix, aliases), personal)

    def test_changed_missing_and_foreign_owned_sections_refuse(self):
        prefix = '[Horse]\nIK_F1=(Action=Shortcut)\n'
        for text in [self.appendix.replace('Action=Canter', 'Action=Use', 1),
                     self.appendix.replace('[CC_SCHEME_Vanilla_Context0]', '[ForeignContext]', 1),
                     self.appendix + '[CC_SCHEME_Foreign_Context]\nIK_F2=(Action=Use)\n']:
            with self.assertRaises(SchemeError):
                remove_aliases(prefix + text, self.appendix, self.aliases)


if __name__ == '__main__':
    unittest.main()
