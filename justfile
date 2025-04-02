NETRC_FILE := "$HOME/.netrc"

show:
    nix flake show

# Convenience wrapper for building targets
# because of the dependency on the .netrc file
# we do no currently support remote builds
build target:
    cp {{NETRC_FILE}} /tmp/.netrc
    nix build {{target}} --option builders '' --option extra-sandbox-paths "/tmp/.netrc"
    rm -f /tmp/.netrc

rebuild ip target +rest:
    cp {{NETRC_FILE}} /tmp/.netrc
    fmo-build-helper {{ip}} {{target}} --option builders '' --option extra-sandbox-paths "/tmp/.netrc" {{rest}}
    rm -f /tmp/.netrc
