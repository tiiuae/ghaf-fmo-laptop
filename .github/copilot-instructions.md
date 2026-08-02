<!--
    Copyright 2022-2025 TII (SSRC) and the Ghaf contributors
    SPDX-License-Identifier: CC-BY-SA-4.0
-->

# ghaf-fmo-laptop — Copilot instructions

Read [`AGENTS.md`](../AGENTS.md) in the repository root first. It is the shared instruction
file for every agent working here: the `just`/`.netrc` build requirement, repository layout,
conventions, the everyday commands, and the mistakes that are easy to make.

Keep shared guidance in `AGENTS.md`. This file holds only what is specific to Copilot.

## Tool initialization

### Serena (code intelligence)

Activate the project before navigating code:

```
#serena activate project
```

The `#serena` prefix is required to reach the MCP tools. Serena gives semantic search and
symbol-level navigation, which beats grepping — though note that this tree is small and most
of what runs on a device comes from the `ghaf` flake input, which Serena is not indexing.
For anything upstream, resolve the pinned revision first:

```bash
nix flake metadata --json | jq -r '.locks.nodes.ghaf.locked.rev'
```

### Context7 (documentation)

Use Context7 for current library documentation rather than recalling it. Useful IDs here:

- `/NixOS/nixos`, `/NixOS/nixpkgs`, `/NixOS/nix`
- `/hercules-ci/flake-parts` — this repo is a flake-parts flake throughout
- `/numtide/treefmt-nix`

Resolve library IDs first unless you already know the exact Context7-compatible ID.

## Skills

There is no `.github/skills/` directory in this repo, so Copilot CLI's `/skills list` will be
empty — that is expected, not a misconfiguration.

The skills that exist are `.claude/skills/fmo-*/SKILL.md`: the target contract, build,
deploy, connect and logs. They are written for Claude Code, which triggers them
automatically. Copilot does not, so read the relevant `SKILL.md` as documentation when a
task matches; the commands and reasoning in them are tool-neutral.

Device facts — addresses, drives, serial nodes, target names — are in `.claude/config.yaml`
plus the gitignored `.claude/config.local.yaml`. Read them with
`.claude/scripts/fmo-config.py`, which merges the two, rather than parsing either by hand.
