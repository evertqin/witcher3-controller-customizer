"""Phase 2 candidate settings model; applying requires an explicit runtime backend."""
from copy import deepcopy
import argparse
import json
import math
from pathlib import Path


class BindingError(ValueError):
    pass


BUTTON_KEYS = {
    'a': 'IK_Pad_A_CROSS', 'b': 'IK_Pad_B_CIRCLE',
    'x': 'IK_Pad_X_SQUARE', 'y': 'IK_Pad_Y_TRIANGLE',
    'lb': 'IK_Pad_LeftShoulder', 'rb': 'IK_Pad_RightShoulder',
    'lt': 'IK_Pad_LeftTrigger', 'rt': 'IK_Pad_RightTrigger',
    'l3': 'IK_Pad_LeftThumb', 'r3': 'IK_Pad_RightThumb',
    'dpad-up': 'IK_Pad_DigitUp', 'dpad-down': 'IK_Pad_DigitDown',
    'dpad-left': 'IK_Pad_DigitLeft', 'dpad-right': 'IK_Pad_DigitRight',
}
BUTTONS = frozenset(BUTTON_KEYS)
# Native press/duration primitives are candidates. Horse double-tap is handled
# separately by the original horse state, not encoded as a fabricated input event.
GESTURES = frozenset(("press", "duration"))


def validate(config, catalog):
    if not isinstance(config, dict) or set(config) != {"schema_version", "bindings"}:
        raise BindingError("Expected schema_version and bindings")
    if type(config["schema_version"]) is not int or config["schema_version"] != 1:
        raise BindingError("Unsupported custom settings version")
    if not isinstance(config["bindings"], list) or not config["bindings"]:
        raise BindingError("Bindings must be a nonempty ordered list")
    slots = {row["Id"]: row for row in catalog["Bindings"]}
    expected = set(slots)
    actual = set()
    occupied = {}
    for binding in config["bindings"]:
        if not isinstance(binding, dict) or set(binding) != {"id", "button", "gesture", "seconds"}:
            raise BindingError("Unexpected binding fields")
        ident = binding["id"]
        if not isinstance(ident, str) or ident not in slots or ident in actual:
            raise BindingError("Unknown or duplicate binding ID")
        actual.add(ident)
        button, gesture, seconds = binding["button"], binding["gesture"], binding["seconds"]
        if not isinstance(button, str) or button not in BUTTONS:
            raise BindingError("Unsupported button; axes and menu buttons are reserved")
        if not isinstance(gesture, str) or gesture not in GESTURES:
            raise BindingError("Unsupported primitive gesture")
        if gesture == "press":
            if seconds is not None:
                raise BindingError("Press has no duration")
        elif type(seconds) not in (int, float) or not math.isfinite(seconds) or not 0.05 <= seconds <= 1:
            raise BindingError("Duration must be finite and between 0.05 and 1 second")
        row = slots[ident]
        key = (row["ContextId"], button)
        sequence = row.get("SharedSequence", False)
        # Only explicitly catalogued native sequences may share a physical key.
        # SharedSequence names are groups, not permission for any two actions.
        action = row["ActionId"]
        group = "horse-speed" if sequence and action in {"follow", "canter", "gallop"} else None
        if action in {"container", "gather-herbs", "fast-travel", "use"} and any(
            ident in item["BindingIds"] and item["Kind"] == "interaction"
            for item in catalog["DiagramGroups"]
        ):
            group = "mounted-interactions"
        previous = occupied.get(key)
        if previous is not None and (group is None or previous != group):
            raise BindingError("Conflicting actions on one contextual button")
        occupied[key] = group or ident
    if actual != expected:
        raise BindingError("Custom settings must cover every catalogued binding")
    return deepcopy(config)


def from_preset(catalog, preset):
    buttons = {row["BindingId"]: row["ButtonId"] for row in preset["Bindings"]}
    bindings = []
    for row in catalog["Bindings"]:
        duration = row["GestureId"] == "native-duration-0.3"
        bindings.append({"id": row["Id"], "button": buttons[row["Id"]],
                         "gesture": "duration" if duration else "press",
                         "seconds": 0.3 if duration else None})
    return validate({"schema_version": 1, "bindings": bindings}, catalog)


def scheme_profile(repo, native_input, scheme):
    """Resolve one pinned immutable Phase 1.1 scheme, retaining inherited rows."""
    from full_schemes import checked_source, expand_lineage, inventory
    inventory(repo, native_input)
    manifest = json.loads((repo / 'data/schemes/manifest.json').read_text(encoding='utf-8-sig'))
    selected = next((row for row in manifest['schemes'] if row['id'] == scheme), None)
    if selected is None:
        raise BindingError('Unknown Phase 1.1 scheme')
    source = native_input if scheme == 'vanilla' else repo / selected['fixture']
    return expand_lineage(checked_source(source, selected['source_sha256']))


def from_scheme(catalog, repo, native_input, scheme):
    """Project the twelve experimental slots; historical Current means DarkSoul."""
    from full_schemes import digital_pad
    profile = scheme_profile(repo, native_input, scheme)
    contexts = {row['Id']: row['NativeName'] for row in catalog['Contexts']}
    actions = {row['Id']: row['NativeName'] for row in catalog['Actions']}
    buttons = {key: ident for ident, key in BUTTON_KEYS.items()}
    bindings = []
    for slot in catalog['Bindings']:
        rows = [row for row in profile[contexts[slot['ContextId']]]
                if digital_pad(row) and dict(row.signature[1]).get('Action') == actions[slot['ActionId']]]
        if len(rows) != 1 or rows[0].key not in buttons:
            raise BindingError(f'Ambiguous or unsupported source binding: {slot["Id"]}')
        parameters = dict(rows[0].signature[1])
        if parameters.get('State') not in (None, 'Duration'):
            raise BindingError('Unsupported native source gesture')
        duration = parameters.get('State') == 'Duration'
        bindings.append({'id': slot['Id'], 'button': buttons[rows[0].key],
                         'gesture': 'duration' if duration else 'press',
                         'seconds': float(parameters['IdleTime']) if duration else None})
    return validate({'schema_version': 1, 'bindings': bindings}, catalog)


class CustomDraft:
    """Stage/cancel/restore without changing active settings or immutable presets.

    Backend.apply(candidate) must atomically commit or raise while retaining its
    prior mapping. A settings setter alone does not satisfy this backend contract.
    """

    def __init__(self, catalog, active):
        self._catalog = deepcopy(catalog)
        self._active = validate(active, self._catalog)
        self._pending = deepcopy(self._active)

    @property
    def active(self):
        return deepcopy(self._active)

    @property
    def pending(self):
        return deepcopy(self._pending)

    def stage(self, candidate):
        self._pending = validate(candidate, self._catalog)

    def cancel(self):
        self._pending = deepcopy(self._active)

    def restore_preset(self, preset):
        self._pending = from_preset(self._catalog, preset)

    def restore_scheme(self, repo, native_input, scheme):
        self._pending = from_scheme(self._catalog, repo, native_input, scheme)

    def apply(self, backend):
        candidate = validate(self._pending, self._catalog)
        if backend is None:
            raise BindingError("An atomic runtime backend is required")
        backend.apply(deepcopy(candidate))
        self._active = candidate
        return self.active


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--catalog", type=Path, required=True)
    source = parser.add_mutually_exclusive_group(required=True)
    source.add_argument("--preset", type=Path)
    source.add_argument("--config", type=Path)
    source.add_argument("--scheme", choices=("vanilla", "darksoul", "darksoul-alt1"))
    parser.add_argument("--native", type=Path)
    parser.add_argument("--repo", type=Path, default=Path(__file__).resolve().parents[2])
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    catalog = json.loads(args.catalog.read_text(encoding="utf-8-sig"))
    if args.scheme:
        if args.native is None:
            parser.error("--scheme requires --native")
        result = from_scheme(catalog, args.repo, args.native, args.scheme)
    elif args.preset:
        result = from_preset(catalog, json.loads(args.preset.read_text(encoding="utf-8-sig")))
    else:
        result = validate(json.loads(args.config.read_text(encoding="utf-8-sig")), catalog)
    text = json.dumps(result, indent=2, allow_nan=False) + "\n"
    if args.output:
        with args.output.open("x", encoding="utf-8") as output:
            output.write(text)
    else:
        print(text, end="")


if __name__ == "__main__":
    main()
