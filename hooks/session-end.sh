#!/usr/bin/env bash
#
# interlearn SessionEnd hook
#
# Detects if the session was in the Interverse monorepo and refreshes
# the cross-repo solution doc index in the background.
#
# Input: JSON on stdin with session metadata (including cwd)
# Output: none (fire-and-forget)
# Exit: always 0 (fail-open)

set -u

# Fail-open: any error → exit 0
trap 'exit 0' ERR

# Guard: require jq
command -v jq &>/dev/null || exit 0

# Read stdin once
INPUT="$(cat)"
CWD="$(echo "$INPUT" | jq -r '.cwd // empty')"
[ -n "$CWD" ] || exit 0

# Detect Interverse root: walk up from CWD checking 3 markers
# (.beads/ + plugins/ + hub/ must all exist)
find_interverse_root() {
    local dir="$1"
    # Fast-path: check known location first
    if [ -d "/root/projects/Interverse/.beads" ] && \
       [ -d "/root/projects/Interverse/plugins" ] && \
       [ -d "/root/projects/Interverse/hub" ]; then
        # Verify CWD is under it
        case "$dir" in
            /root/projects/Interverse|/root/projects/Interverse/*)
                echo "/root/projects/Interverse"
                return 0
                ;;
        esac
    fi

    # General walk-up
    while [ "$dir" != "/" ]; do
        if [ -d "$dir/.beads" ] && [ -d "$dir/plugins" ] && [ -d "$dir/hub" ]; then
            echo "$dir"
            return 0
        fi
        dir="$(dirname "$dir")"
    done
    return 1
}

INTERVERSE_ROOT="$(find_interverse_root "$CWD")" || exit 0

# Locate the indexer script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INDEXER="$SCRIPT_DIR/scripts/index-solutions.sh"
[ -x "$INDEXER" ] || exit 0

# Run indexer in background, detached from session teardown
bash "$INDEXER" "$INTERVERSE_ROOT" </dev/null >/dev/null 2>&1 &

exit 0
