#!/usr/bin/env bash
# Runs the xdm-persistence tests with Saxon.
# Set SAXON_JAR to the path of a Saxon jar (Home Edition or above, XSLT 3.0 support required).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -z "${SAXON_JAR:-}" ]; then
  echo "Set SAXON_JAR to the path of your Saxon jar, e.g.:" >&2
  echo "  SAXON_JAR=/path/to/saxon-he-12.jar tests/run.sh" >&2
  exit 1
fi

status=0
for test in "$SCRIPT_DIR"/test-*.xsl; do
  echo "== $(basename "$test") =="
  if ! java -jar "$SAXON_JAR" -xsl:"$test" -it; then
    status=1
  fi
done

exit $status
