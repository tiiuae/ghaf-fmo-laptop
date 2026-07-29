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

    targets=$(nix eval --raw .#packages.x86_64-linux --apply \
      'p: builtins.concatStringsSep " " (builtins.filter (n: builtins.match ".*-installer" n != null) (builtins.attrNames p))')

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
