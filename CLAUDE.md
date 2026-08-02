<!--
    Copyright 2022-2025 TII (SSRC) and the Ghaf contributors
    SPDX-License-Identifier: CC-BY-SA-4.0
-->

# ghaf-fmo-laptop

@AGENTS.md

The skills in `.claude/skills/` load on demand when a task matches their description:
`fmo-target`, `fmo-connect`, `fmo-logs`, `fmo-build`, `fmo-deploy`. The `fmo-log-triage`
agent in `.claude/agents/` reads a log snapshot in its own context and returns ranked
findings, which is the right way to handle journals from a full fleet of VMs.

These are the FMO counterparts of ghaf's `ghaf-*` skills, renamed because they contradict
them: upstream builds with a bare `nix build` and flashes a raw image, whereas here builds
go through `just` and the first install is an ISO plus `ghaf-installer`. Follow these, not
the upstream ones, for anything in this repo.
