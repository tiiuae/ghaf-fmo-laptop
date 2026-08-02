NETRC_FILE := "$HOME/.netrc"

show:
    nix flake show

# Convenience wrapper for building targets
# because of the dependency on the .netrc file
# we do no currently support remote builds
build target +rest:
    install -m 644 {{NETRC_FILE}} /tmp/.netrc
    nix build {{target}} --option builders '' --option extra-sandbox-paths "/tmp/.netrc" {{rest}}
    rm -f /tmp/.netrc

rebuild ip target +rest:
    install -m 644 {{NETRC_FILE}} /tmp/.netrc
    ghaf-build-helper {{ip}} {{target}} --option builders '' --option extra-sandbox-paths "/tmp/.netrc" {{rest}}
    rm -f /tmp/.netrc

# Build every installer ISO, and with them every disk image
build-all *rest:
    #!/usr/bin/env bash
    set -euo pipefail

    # An installer takes its target's image as an input, so building the
    # installers covers the disk images too - there is nothing extra to do.
    # Each target gets its own result-<target> link so they do not overwrite
    # one another. Extra arguments are passed through to nix build.

    # 644 in /tmp, same as `build` above, and not by accident: the sandbox
    # builder runs as a different user, so it needs both a traversable
    # directory and a readable file. A private mktemp dir (0700) or mode 0600
    # fails at sandbox setup with "getting attributes of path ...: Permission
    # denied".
    #
    # The trap is the part worth adding: `build` removes the file on its last
    # line, so any failure leaves the credentials behind. Over a seven-target
    # run that matters.
    install -m 644 {{NETRC_FILE}} /tmp/.netrc
    trap 'rm -f /tmp/.netrc' EXIT

    # The netboot installers are deliberately excluded: they carry no image, so
    # building them would not cover the disk images the way the ISOs do, and
    # they need none of the netrc machinery above. `just build-netboot`.
    targets=$(nix eval --raw .#packages.x86_64-linux --apply \
      'p: builtins.concatStringsSep " " (builtins.filter (n: builtins.match ".*-installer" n != null && builtins.match ".*-netboot-installer" n == null) (builtins.attrNames p))')

    failed=()
    for t in $targets; do
      echo "==> $t"
      nix build ".#$t" --out-link "result-$t" \
        --option builders '' \
        --option extra-sandbox-paths "/tmp/.netrc" \
        {{rest}} || failed+=("$t")
    done

    if [ ${#failed[@]} -ne 0 ]; then
      printf 'FAILED: %s\n' "${failed[@]}" >&2
      exit 1
    fi
    echo "all installers built"

# Build every netboot installer (the boot environment only - see the note on images)
build-netboot *rest:
    #!/usr/bin/env bash
    set -euo pipefail

    # THIS DOES NOT BUILD ANY IMAGE, and on its own is not enough to install
    # anything. A netboot installer is the installer environment - kernel,
    # initrd, and an iPXE script - and the disk image is fetched over HTTP at
    # install time instead of being baked in. `ghaf-netboot -g <dir>` still
    # needs a real image, which comes from `just build .#fmo-<machine>-debug ""`
    # and does need the netrc like everything else.
    #
    # Which is why this recipe has no netrc, unlike every other one here:
    # verified with `nix-store -q --requisites` on the two derivations, the ISO
    # installer's build graph reaches the image plus six private-Go-dep store
    # paths, and the netboot installer's reaches neither. There is nothing here
    # for the credentials to unlock.
    #
    # `--option builders ''` is kept anyway, purely for consistency with the
    # rest of this file. Nothing here needs to be local - drop it if you want
    # the work delegated.
    #
    # Only the first target costs anything. The kernel and initrd are
    # target-independent and shared, so the rest are symlinks over a closure
    # that is already built.
    targets=$(nix eval --raw .#packages.x86_64-linux --apply \
      'p: builtins.concatStringsSep " " (builtins.filter (n: builtins.match ".*-netboot-installer" n != null) (builtins.attrNames p))')

    failed=()
    for t in $targets; do
      echo "==> $t"
      nix build ".#$t" --out-link "result-$t" \
        --option builders '' \
        {{rest}} || failed+=("$t")
    done

    if [ ${#failed[@]} -ne 0 ]; then
      printf 'FAILED: %s\n' "${failed[@]}" >&2
      exit 1
    fi
    echo "all netboot installers built (boot environment only - no images)"
    echo "to install, you also need an image: just build .#fmo-<machine>-debug \"\""
