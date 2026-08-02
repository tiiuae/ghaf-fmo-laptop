#!/usr/bin/env python3
# Copyright 2022-2025 TII (SSRC) and the Ghaf contributors
# SPDX-License-Identifier: Apache-2.0
"""Read merged device facts for the fmo-* skills.

Every skill and script that needs to know a device's address, drive node or
target name goes through here, so the merge between the tracked config and the
gitignored local one is implemented once.

That merge is the reason this exists. Ghaf's equivalents inline a small Python
heredoc in each shell script that reads only the shared file; the local
override lives in a separate CLI those scripts never call, so every desk-local
field silently reads as null. Doing it in one place also means the resolution
order is written down somewhere a reader can find it:

    config.local.yaml devices.<name>
      > config.yaml   devices.<name>
      > config.yaml   defaults

A null in the local file is a no-op, not a blank: the point of the local file
is to add what the shared one cannot know, never to remove what it does.

Usage:
    fmo-config.py --list
    fmo-config.py --device dell-7330
    fmo-config.py --device dell-7330 --field host_ip

Exit status:
    0  fine, including a field that resolves to null (prints an empty line)
    2  no such device
    3  PyYAML is missing - you are outside the devshell
"""

import argparse
import os
import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    # A bare ImportError traceback reads like a broken script rather than a
    # missing shell, and the fix is one command away.
    print(
        "error: PyYAML not found. Run this inside 'nix develop'.",
        file=sys.stderr,
    )
    sys.exit(3)


def repo_root() -> Path:
    """Locate the repo root so the script works from any subdirectory."""
    here = Path(__file__).resolve()
    # .claude/scripts/fmo-config.py -> repo root
    root = here.parent.parent.parent
    if (root / "flake.nix").exists():
        return root
    return Path.cwd()


def load(path: Path) -> dict:
    if not path.exists():
        return {}
    with path.open(encoding="utf-8") as handle:
        return yaml.safe_load(handle) or {}


def merged(shared: dict, local: dict, device: str) -> dict:
    """Resolve one device's fields, local winning over shared over defaults."""
    fields = dict(shared.get("defaults") or {})
    fields.update(
        {k: v for k, v in (shared.get("devices", {}).get(device) or {}).items()}
    )
    for key, value in (local.get("devices", {}).get(device) or {}).items():
        # The whole point of the null rule: an unset key in the local file must
        # not erase a value the shared file took the trouble to record.
        if value is not None:
            fields[key] = value
    return fields


def known_devices(shared: dict, local: dict) -> list[str]:
    """Union of both files - a device may exist only locally."""
    names = set(shared.get("devices") or {})
    names |= set(local.get("devices") or {})
    return sorted(names)


def main() -> int:
    root = repo_root()
    parser = argparse.ArgumentParser(
        description="Read merged device facts for the fmo-* skills.",
    )
    parser.add_argument("--list", action="store_true", help="list device names")
    parser.add_argument("--device", help="device name, e.g. dell-7330")
    parser.add_argument("--field", help="print one field instead of all of them")
    parser.add_argument(
        "--config",
        default=os.environ.get("FMO_CONFIG", str(root / ".claude/config.yaml")),
        help="path to the shared config (env: FMO_CONFIG)",
    )
    parser.add_argument(
        "--local-config",
        default=os.environ.get(
            "FMO_LOCAL_CONFIG", str(root / ".claude/config.local.yaml")
        ),
        help="path to the local config (env: FMO_LOCAL_CONFIG)",
    )
    args = parser.parse_args()

    shared = load(Path(args.config))
    local = load(Path(args.local_config))

    if not shared and not local:
        print(f"error: no config found at {args.config}", file=sys.stderr)
        return 2

    names = known_devices(shared, local)

    if args.list:
        for name in names:
            print(name)
        return 0

    if not args.device:
        parser.print_usage(sys.stderr)
        print("error: --list or --device is required", file=sys.stderr)
        return 2

    if args.device not in names:
        print(f"error: unknown device '{args.device}'", file=sys.stderr)
        print(f"known devices: {', '.join(names)}", file=sys.stderr)
        return 2

    fields = merged(shared, local, args.device)

    if args.field:
        value = fields.get(args.field)
        # An empty line with exit 0 lets a caller write
        # `v=$(fmo-config.py ...)` and test `[ -n "$v" ]`, rather than having to
        # distinguish "not set" from "the tool failed".
        print("" if value is None else value)
        return 0

    for key in sorted(fields):
        value = fields[key]
        print(f"{key}={'' if value is None else value}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
