<!--
    Copyright 2023 TII (SSRC) and the Ghaf contributors
    SPDX-License-Identifier: CC-BY-SA-4.0
-->

## Description of changes

<!--
Summary of the proposed changes in the PR description in your own words. For dependency updates, please link to the changelog.
-->

## Checklist for things done

<!-- Please check, [X], to all that applies. Leave [ ] if an item does not apply but you have considered the check list item. Note that all of these are not hard requirements. They serve information to reviewers. When you fill the checklist, you indicate to reviewers you appreciate their work. -->

- [ ] Summary of the proposed changes in the PR description
- [ ] More detailed description in the commit message(s)
- [ ] Commits are squashed into relevant entities - avoid a lot of minimal dev time commits in the PR
- [ ] PR linked to architecture documentation and requirement(s) (ticket id)
- [ ] Test procedure described (or includes tests). Select one or more:
  - [ ] Tested on Laptop`x86_64`
- [ ] Author has run `nix flake check` and it passes
- [ ] All automatic Github Action checks pass - see [actions](https://github.com/tiiuae/ghaf-fmo-laptop/actions)
- [ ] Author has added reviewers and removed PR draft status
- [ ] Change requires full re-installation
- [ ] Change can be updated with `nixos-rebuild ... switch`

<!-- Additional description of omitted [ ] items if not obvious. -->

## Instructions for Testing

- [ ] List all targets that this applies to:
  - [ ] x86_64
- [ ] Is this a new feature
  - [ ] List the test steps to verify:
- [ ] If it is an improvement how does it impact existing functionality?
