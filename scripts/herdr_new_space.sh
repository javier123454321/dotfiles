#!/usr/bin/env bash
set -euo pipefail

# Create a new herdr workspace and open a lazygit tab inside it.
#
# Usage: herdr_new_space.sh [label]
#   label   optional workspace name (default: "scratch")

if [[ "${HERDR_ENV:-}" != "1" ]]; then
  echo "Not running inside herdr; the herdr CLI cannot reach the session." >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required to parse herdr responses." >&2
  exit 1
fi

label="${1:-scratch}"

# Create the workspace, then parse the workspace and root pane IDs from the JSON response.
ws_json="$(herdr workspace create --label "$label" --focus 2>/dev/null)"
ws_id="$(printf '%s' "$ws_json" | jq -er '.result.workspace.workspace_id')"

# Create a dedicated tab for lazygit inside the new workspace.
tab_json="$(herdr tab create --workspace "$ws_id" --label "git" --focus 2>/dev/null)"
tab_id="$(printf '%s' "$tab_json" | jq -er '.result.tab.tab_id')"
pane_id="$(printf '%s' "$tab_json" | jq -er '.result.root_pane.pane_id')"

# Launch lazygit in the new tab's pane.
herdr pane run "$pane_id" "lazygit"

printf 'herdr workspace %s (%s) created with lazygit tab %s\n' "$ws_id" "$label" "$tab_id"
