#!/bin/sh

set -eu

# Move to this script's directory (scripts/)
cd "$(dirname "$0")"

SCENARIO_NAME="${1:-}"
ENV_NAME="${2:-api}"

if [ -z "$SCENARIO_NAME" ]; then
  echo "Usage: $0 <scenario-name|path> [environment]" >&2
  echo "Examples:" >&2
  echo "  $0 rates api" >&2
  echo "  $0 scenarios/stress-test.yaml api" >&2
  echo "" >&2
  echo "Available scenarios:" >&2
  ls -1 ../perf/scenarios/*.yaml 2>/dev/null | sed 's/.*\///g' | sed 's/\.yaml$//g' | sed 's/^/  - /g' >&2 || echo "  No scenarios found in ../perf/scenarios/ directory" >&2
  exit 2
fi

# Resolve scenario file
if [ -f "$SCENARIO_NAME" ]; then
  SCENARIO_FILE="$SCENARIO_NAME"
elif [ -f "../perf/scenarios/$SCENARIO_NAME.yaml" ]; then
  SCENARIO_FILE="scenarios/$SCENARIO_NAME.yaml"
elif [ -f "../perf/scenarios/$SCENARIO_NAME" ]; then
  SCENARIO_FILE="scenarios/$SCENARIO_NAME"
else
  echo "Scenario file not found for '$SCENARIO_NAME' (looked in ./, ../perf/scenarios/)." >&2
  echo "" >&2
  echo "Available scenarios:" >&2
  ls -1 ../perf/scenarios/*.yaml 2>/dev/null | sed 's/.*\///g' | sed 's/\.yaml$//g' | sed 's/^/  - /g' >&2 || echo "  No scenarios found in ../perf/scenarios/ directory" >&2
  exit 1
fi

echo "Running Artillery: $SCENARIO_FILE (env=$ENV_NAME)"
echo "Target: http://localhost:5555"
echo "Starting in 3 seconds... (Ctrl+C to cancel)"
sleep 3

# Change to perf directory to run npm
cd ../perf
npm run artillery -- run "$SCENARIO_FILE" -e "$ENV_NAME"
