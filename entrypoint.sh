#!/usr/bin/env bash
# Score a protocol-bench submission and enforce thresholds.
#   exit 0 = thresholds met
#   exit 1 = thresholds not met
#   exit 3 = misconfigured (no input file) — never silently "pass" on nothing
set -euo pipefail

# Install only if it is not already importable, so the action works in a prepared runner too.
#
# Installed from GitHub, not PyPI. `pip install protocol-bench` 404s — neither it nor its
# `minicheck` dependency is published yet — so a bare name here made this action fail for
# everyone except a workflow that had already installed it by hand. The pin is `@main`, which
# is what the repository publishes; pin a tag instead if you need the version frozen.
python -c "import protocol_bench" 2>/dev/null || \
  python -m pip install --quiet --disable-pip-version-check \
    "protocol-bench @ git+https://github.com/nickharris808/protocol-bench@main"

if [[ -n "${PB_COMPLETIONS:-}" ]]; then
  [[ -f "$PB_COMPLETIONS" ]] || { echo "::error::completions file not found: $PB_COMPLETIONS"; exit 3; }
  protocol-bench score-completions "$PB_COMPLETIONS" --json > /tmp/pb_result.json
else
  [[ -f "${PB_SUBMISSION:-}" ]] || { echo "::error::submission file not found: ${PB_SUBMISSION:-<unset>}"; exit 3; }
  protocol-bench score "$PB_SUBMISSION" --json > /tmp/pb_result.json
fi

read -r BA CEX CLAIMED <<<"$(python - <<'PY'
import json
r = json.load(open("/tmp/pb_result.json"))
print(r["balanced_accuracy"], r["valid_counterexamples"], r["detections_claimed"])
PY
)"

echo "balanced-accuracy=$BA"      >> "$GITHUB_OUTPUT"
echo "valid-counterexamples=$CEX" >> "$GITHUB_OUTPUT"

{
  echo "### protocol-bench"
  echo ""
  echo "| metric | value |"
  echo "|---|---|"
  echo "| balanced accuracy | \`$BA\` |"
  echo "| detections claimed | \`$CLAIMED\` |"
  echo "| valid counterexamples | \`$CEX\` |"
} >> "${GITHUB_STEP_SUMMARY:-/dev/null}"

FAIL=0
python -c "import sys; sys.exit(0 if float('$BA') >= float('${PB_MIN_BA:-0}') else 1)" || {
  echo "::error::balanced accuracy $BA is below the required ${PB_MIN_BA}"; FAIL=1; }
python -c "import sys; sys.exit(0 if int('$CEX') >= int('${PB_MIN_CEX:-0}') else 1)" || {
  echo "::error::only $CEX counterexamples replayed; ${PB_MIN_CEX} required"; FAIL=1; }

exit $FAIL
