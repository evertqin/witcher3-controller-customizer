"""Package current schema-2 sources and a matching frozen cook; no native scripts."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import zipfile

from full_scheme_delivery import PAYLOADS, CONTENT, digest, validate_cook


def package(repo, snapshot, output):
    cook = validate_cook(repo, snapshot)
    output.mkdir(parents=True, exist_ok=False)
    stage = output / 'package'
    stage.mkdir()
    for relative in ('data', 'fixtures/legacy', 'src/scripts', 'src/menu', 'src/generated'):
        shutil.copytree(repo / relative, stage / relative)
    tools = ('FileTransaction.psm1', 'FullScheme-Mod.ps1', 'compiler-toolchain.json')
    automation = ('full_schemes.py', 'scheme_runtime.py', 'remove_scheme_aliases.py', 'full_scheme_delivery.py')
    for relative in [*(f'tools/{n}' for n in tools), *(f'tools/automation/{n}' for n in automation)]:
        destination = stage / relative
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(repo / relative, destination)
    for name in PAYLOADS:
        relative = 'packed/' + CONTENT + name
        destination = stage / relative
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(snapshot / relative, destination)
    for name in ('cook.json', 'cook.log'):
        shutil.copyfile(snapshot / name, stage / name)
    shutil.copyfile(repo / 'docs/phase11-delivery.md', stage / 'README.md')
    manifest = {'SchemaVersion': 2, 'SelectionSchemaVersion': 2, 'ReleaseVerified': False,
                'NativeParityVerified': False, 'CompilerSha256': cook['CompilerSha256'],
                'SourceSha256': cook['CanonicalSourceSha256'],
                'Files': {p.relative_to(stage).as_posix(): digest(p) for p in sorted(stage.rglob('*')) if p.is_file()}}
    (stage / 'package.json').write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')
    archive = output / 'controller-customizer-phase11-candidate.zip'
    with zipfile.ZipFile(archive, 'x', compression=zipfile.ZIP_DEFLATED) as stream:
        for path in sorted(stage.rglob('*')):
            if path.is_file():
                info = zipfile.ZipInfo(path.relative_to(stage).as_posix(), (2000, 1, 1, 0, 0, 0))
                info.compress_type = zipfile.ZIP_DEFLATED
                stream.writestr(info, path.read_bytes())
    print(f'Candidate package: {archive}\nSHA256: {digest(archive)}')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--repo', type=Path, default=Path(__file__).resolve().parents[2])
    parser.add_argument('--cook', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    package(args.repo.resolve(), args.cook.resolve(), args.output.resolve())
