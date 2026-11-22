#!/usr/bin/env bash
# select.sh PATH... -> comma list of suites the resolver selects (source-store libs), plus UNRESOLVED lines on stderr
L=/home/benjamin/.config/nvim/agent-system/extensions/core/scripts/lib
for l in verification-scope-lib.sh suite-selection-lib.sh suite-resolver-lib.sh unmapped-fallback-lib.sh; do . "$L/$l"; done
cd /home/benjamin/.config/nvim
suite_resolver_resolve "$(pwd)" "$@" | awk '/^SELECT /{if(!s[$2]++)print $2} /^UNRESOLVED /{print > "/dev/stderr"}' | paste -sd, -
