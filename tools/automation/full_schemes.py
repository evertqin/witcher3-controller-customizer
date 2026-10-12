"""Fingerprint-checked full scheme inventory; no live installation or input writes."""
import argparse
from collections import Counter
from dataclasses import dataclass
from decimal import Decimal, InvalidOperation
import hashlib
import json
from pathlib import Path
import re


class SchemeError(ValueError):
    pass


@dataclass(frozen=True)
class Record:
    key: str
    value: str
    line: int

    @property
    def controller(self):
        return self.key.startswith(("IK_Pad_", "IK_PS4_", "IK_Pattern_"))

    @property
    def signature(self):
        # Native serialization changes numeric formatting and parameter order.
        # Duplicate record counts remain significant; no INI dictionary is used.
        if not self.value.startswith("(") or not self.value.endswith(")"):
            return self.key, self.value
        parameters = []
        for token in self.value[1:-1].split(","):
            name, separator, value = token.strip().partition("=")
            if separator:
                try:
                    number = Decimal(value)
                    if number.is_finite():
                        value = format(number.normalize(), "f")
                except InvalidOperation:
                    pass
                parameters.append((name, value))
            else:
                parameters.append((name, None))
        return self.key, tuple(sorted(parameters))


def parse(text):
    sections = {}
    current = None
    for line_number, raw in enumerate(text.lstrip("\ufeff").splitlines(), 1):
        line = raw.strip()
        if not line or line.startswith((";", "#", "//")):
            continue
        match = re.fullmatch(r"\[([A-Za-z0-9_]+)\]", line)
        if match:
            current = match[1]
            if current in sections:
                raise SchemeError(f"Duplicate context: {current}")
            sections[current] = []
        elif current is None or "=" not in line:
            raise SchemeError(f"Unrecognized input at line {line_number}")
        else:
            key, value = line.split("=", 1)
            sections[current].append(Record(key.strip(), value.strip(), line_number))
    if not sections:
        raise SchemeError("No input contexts")
    return sections


def expand_lineage(sections):
    """Expand inherited record lineage without guessing engine override precedence.

    Parent branches and repeated records are retained in declared order. This
    inspection model is not authorization to install a flattened native profile.
    """
    cache = {}

    def visit(context, trail):
        if context in trail:
            raise SchemeError("Context inheritance cycle: " + " -> ".join((*trail, context)))
        if context not in sections:
            raise SchemeError(f"Missing inherited context: {context}")
        if context not in cache:
            rows = []
            for row in sections[context]:
                if row.key == "DERIVED_FROM":
                    rows.extend(visit(row.value, (*trail, context)))
            rows.extend(row for row in sections[context] if row.key != "DERIVED_FROM")
            cache[context] = tuple(rows)
        return cache[context]

    for context in sections:
        visit(context, ())
    return cache


def migrate_selection(legacy_preset=None, scheme=None):
    if scheme is not None:
        if scheme not in ("vanilla", "darksoul", "darksoul-alt1"):
            raise SchemeError("Invalid versioned scheme; retain the previous working selection")
        return scheme
    if legacy_preset is None:
        return "darksoul-alt1"
    if type(legacy_preset) not in (int, str) or str(legacy_preset) not in ("0", "1"):
        raise SchemeError("Unknown legacy selection; do not reinterpret it as vanilla")
    return {"0": "darksoul", "1": "darksoul-alt1"}[str(legacy_preset)]


def checked_source(path, expected):
    data = path.read_bytes()
    digest = hashlib.sha256(data).hexdigest()
    if digest != expected:
        raise SchemeError(f"Input fingerprint changed: {path.name}")
    return parse(data.decode("utf-8-sig"))


def inventory(repo, native_input):
    manifest = json.loads((repo / "data/schemes/manifest.json").read_text(encoding="utf-8-sig"))
    if manifest["schema_version"] != 1 or manifest["selection_schema_version"] != 2:
        raise SchemeError("Unsupported full-scheme manifest")
    schemes = manifest["schemes"]
    if [s["id"] for s in schemes] != ["vanilla", "darksoul", "darksoul-alt1"]:
        raise SchemeError("Unexpected full-scheme inventory")
    native = checked_source(native_input, schemes[0]["source_sha256"])
    lineage = expand_lineage(native)
    profiles = {}
    sources = {}
    for scheme in schemes:
        if scheme["id"] == "vanilla":
            records = lineage
            sources[scheme["id"]] = native
        else:
            fixture = (repo / scheme["fixture"]).resolve()
            if not fixture.is_relative_to((repo / "fixtures/legacy").resolve()):
                raise SchemeError("Fixture escaped owned legacy directory")
            sources[scheme["id"]] = checked_source(fixture, scheme["source_sha256"])
            records = expand_lineage(sources[scheme["id"]])
        profiles[scheme["id"]] = {
            context: [row for row in rows if row.controller]
            for context, rows in records.items() if any(row.controller for row in rows)
        }
    if set(sources["darksoul"]) != set(sources["darksoul-alt1"]) or set(native) != set(sources["darksoul"]):
        raise SchemeError("Native and legacy context inventories differ")
    comparisons = []
    for left, right in (("vanilla", "darksoul"), ("darksoul", "darksoul-alt1")):
        changed = []
        for context in sorted(set(profiles[left]) | set(profiles[right])):
            before = Counter(r.signature for r in profiles[left].get(context, []))
            after = Counter(r.signature for r in profiles[right].get(context, []))
            removed, added = before - after, after - before
            if removed or added:
                changed.append({"context": context, "removed": sum(removed.values()), "added": sum(added.values())})
        comparisons.append({"from": left, "to": right, "changed_contexts": changed})
    return {
        "schema_version": 1, "selection_schema_version": 2,
        "engine_override_precedence_verified": False,
        "scope": "Full controller/pattern record lineage; includes menu and analog records for audit, not blanket remapping",
        "native_sha256": schemes[0]["source_sha256"],
        "context_count": len(native),
        "schemes": [{"id": s["id"], "display_name": s["display_name"],
                     "source_sha256": s["source_sha256"], "controller_contexts": len(profiles[s["id"]]),
                     "controller_record_count": sum(map(len, profiles[s["id"]].values()))}
                    for s in schemes],
        "comparisons": comparisons,
        "native_inheritance": {name: [r.value for r in rows if r.key == "DERIVED_FROM"]
                               for name, rows in native.items()},
    }


def digital_pad(row):
    return row.key.startswith("IK_Pad_") and not re.search(r"Axis[XY]$", row.key)



def observed_serialization(counter, alias):
    """Exact observed ownership variant; never an assertion of gameplay parity."""
    report = json.loads((Path(__file__).resolve().parents[2] /
                         'data/schemes/observed-serialization.json').read_text(encoding='utf-8'))
    result = counter.copy()
    for change in report['changes']:
        if change['alias'] != alias:
            continue
        for signature, count in change['removed']:
            key, parameters = signature
            signature = key, tuple(tuple(p) for p in parameters)
            if result[signature] < count:
                return None  # Do not reinterpret a different source or registered bank.
            result[signature] -= count
            if result[signature] == 0:
                del result[signature]
        for signature, count in change['added']:
            key, parameters = signature
            result[key, tuple(tuple(p) for p in parameters)] += count
    return result


def build_appendix(repo, native_input, personal_text):
    """Prepare owned full-scheme aliases; never replace original personal sections."""
    inventory(repo, native_input)  # Validate all pins and the inheritance graph first.
    manifest = json.loads((repo / "data/schemes/manifest.json").read_text(encoding="utf-8-sig"))
    profiles = {}
    for scheme in manifest["schemes"]:
        source = native_input if scheme["id"] == "vanilla" else repo / scheme["fixture"]
        profiles[scheme["id"]] = expand_lineage(checked_source(source, scheme["source_sha256"]))
    personal = parse(personal_text)
    if any(name.startswith("CC_SCHEME_") for name in personal):
        raise SchemeError("Full-scheme aliases already exist")
    contexts = []
    for context in sorted(profiles["vanilla"]):
        signatures = [Counter(r.signature for r in profiles[s][context] if digital_pad(r))
                      for s in profiles]
        if all(signatures[0] == value for value in signatures[1:]):
            continue
        if context not in personal:
            raise SchemeError(f"Missing personal context: {context}")
        if any(r.key == "DERIVED_FROM" for r in personal[context]):
            raise SchemeError(f"Personal context is not flat: {context}")
        current = Counter(r.signature for r in personal[context] if digital_pad(r))
        serialized_native = observed_serialization(signatures[0], f"CC_SCHEME_Vanilla_{context}")
        if current not in signatures and current != serialized_native:
            raise SchemeError(f"Independent controller edits in {context}; explicit reconciliation required")
        # Patterns/device-menu/analog entries are preserved from the person, so
        # source schemes must not rely on a difference in those entries.
        protected = [Counter(r.signature for r in profiles[s][context]
                             if r.controller and not digital_pad(r)) for s in profiles]
        if any(protected[0] != value for value in protected[1:]):
            raise SchemeError(f"Non-digital controller delta requires separate handling: {context}")
        contexts.append(context)
    raw_sections = {}
    active = None
    for line in personal_text.lstrip("\ufeff").splitlines(keepends=True):
        match = re.fullmatch(r"\s*\[([A-Za-z0-9_]+)\]\s*", line.rstrip("\r\n"))
        if match:
            active = match[1]
            raw_sections[active] = []
        if active is not None:
            raw_sections[active].append(line)
    aliases = []
    parts = ["\r\n; Controller Customizer full schemes BEGIN\r\n"]
    labels = {"vanilla": "Vanilla", "darksoul": "DarkSoul", "darksoul-alt1": "DarkSoulAlt1"}
    for scheme in profiles:
        for context in contexts:
            alias = f"CC_SCHEME_{labels[scheme]}_{context}"
            # Alt1 differs from DarkSoul only in four riding contexts. Share
            # identical banks to keep native context-map capacity below 128.
            shared = (scheme == "darksoul-alt1" and
                      Counter(r.signature for r in profiles[scheme][context] if digital_pad(r)) ==
                      Counter(r.signature for r in profiles["darksoul"][context] if digital_pad(r)))
            if shared:
                alias = f"CC_SCHEME_DarkSoul_{context}"
            aliases.append({"scheme": scheme, "canonical": context, "alias": alias})
            if shared:
                continue
            parts.append(f"[{alias}]\r\n")
            for line in raw_sections[context][1:]:
                match = re.match(r"\s*([^;#=\s][^=]*)=(.*)", line.rstrip("\r\n"))
                if match and digital_pad(Record(match[1].strip(), match[2].strip(), 0)):
                    continue
                parts.append(line)
            if not parts[-1].endswith(("\r", "\n")):
                parts.append("\r\n")
            for record in profiles[scheme][context]:
                if digital_pad(record):
                    parts.append(f"{record.key}={record.value}\r\n")
    parts.append("; Controller Customizer full schemes END\r\n")
    if len(personal) + len({a["alias"] for a in aliases}) > 128:
        raise SchemeError("Context bank exceeds native capacity; reconcile unrelated contexts first")
    appendix = "".join(parts)
    generated = parse(appendix)
    for alias in aliases:
        source = profiles[alias["scheme"]][alias["canonical"]]
        expected = Counter(r.signature for r in source if digital_pad(r))
        actual = Counter(r.signature for r in generated[alias["alias"]] if digital_pad(r))
        if actual != expected:
            raise SchemeError("Generated full-scheme controller records disagree")
        before = Counter(r.signature for r in personal[alias["canonical"]] if not digital_pad(r))
        after = Counter(r.signature for r in generated[alias["alias"]] if not digital_pad(r))
        if before != after:
            raise SchemeError("Generated alias changed protected personal records")
    return appendix, aliases


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", type=Path, default=Path(__file__).resolve().parents[2])
    parser.add_argument("--native-input", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--personal-input", type=Path, help="Prepare an appendix only; never install it")
    args = parser.parse_args()
    if args.personal_input:
        if args.check:
            parser.error("--check applies to inventory reports only")
        appendix, aliases = build_appendix(args.repo.resolve(), args.native_input,
                                           args.personal_input.read_bytes().decode("utf-8-sig"))
        with args.output.open("x", encoding="utf-8", newline="") as stream:
            stream.write(appendix)
        print(f"PASS: prepared {len(aliases)} full-scheme aliases; original personal input untouched")
        return
    result = inventory(args.repo.resolve(), args.native_input)
    text = json.dumps(result, indent=2, allow_nan=False) + "\n"
    if args.check:
        if args.output.read_text(encoding="utf-8") != text:
            raise SchemeError("Full-scheme inventory is stale")
    else:
        # Explicit evidence output only; refuse replacing profiles or old receipts.
        with args.output.open("x", encoding="utf-8") as stream:
            stream.write(text)
    print(f"PASS: three pinned schemes; {result['context_count']} contexts; native inheritance audited")


if __name__ == "__main__":
    main()
