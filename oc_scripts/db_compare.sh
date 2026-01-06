#!/bin/bash
#
# Database Table Count Comparison Script for OpenShift
# Usage:
#   ./db_compare.sh <source-deployment-name> <target-deployment-name>
#
# This script compares PostgreSQL table row counts between two OpenShift deployments
# to validate database transfers or check data consistency between environments.
#
# Requirements:
# - Both deployments must have running pods managed by the given deployment names.
# - The oc CLI must be authenticated to the OpenShift cluster
# - Environment variables POSTGRES_USER and POSTGRES_DB must be set in the pods
#
# Notes:
# - Uses pg_stat_user_tables to get live row counts
# - Reports differences in table names or row counts between environments
# - Reports differences but always exits successfully (informational only)
#

# Strict mode: exit on error, unset vars, or failed pipes
set -euo pipefail

# Usage
if [[ $# -lt 2 ]]; then
  grep -v '^#!' "$0" | awk '/^#/ { sub(/^# ?/, ""); print; next } NF==0 { exit }'
  exit 1
fi

SOURCE_DEPLOYMENT="${1}"
TARGET_DEPLOYMENT="${2}"

# Fail fast if pods aren't found
if ! oc get po -l deployment="${SOURCE_DEPLOYMENT}" --no-headers -o name | grep -q .; then
  echo "No pods found for deployment '${SOURCE_DEPLOYMENT}'."
  exit 2
fi
if ! oc get po -l deployment="${TARGET_DEPLOYMENT}" --no-headers -o name | grep -q .; then
  echo "No pods found for deployment '${TARGET_DEPLOYMENT}'."
  exit 2
fi

# Query to get table names and row counts
COUNT_QUERY="
SELECT schemaname || '.' || relname AS table_name, n_live_tup AS row_count
FROM pg_stat_user_tables
ORDER BY table_name;
"

# Run the query on source
echo "Collecting table counts from source..."
if ! SOURCE_COUNTS=$(oc exec deployment/"${SOURCE_DEPLOYMENT}" -- \
  bash -c "psql -U \${POSTGRES_USER} -d \${POSTGRES_DB} -Atc \"${COUNT_QUERY}\"" 2>&1); then
  echo "Error: Failed to query source deployment '${SOURCE_DEPLOYMENT}'"
  echo "$SOURCE_COUNTS"
  exit 3
fi

# Run the query on target
echo "Collecting table counts from target..."
if ! TARGET_COUNTS=$(oc exec deployment/"${TARGET_DEPLOYMENT}" -- \
  bash -c "psql -U \${POSTGRES_USER} -d \${POSTGRES_DB} -Atc \"${COUNT_QUERY}\"" 2>&1); then
  echo "Error: Failed to query target deployment '${TARGET_DEPLOYMENT}'"
  echo "$TARGET_COUNTS"
  exit 4
fi

# Show table counts from each database
echo
echo "Comparing source and target table counts..."
echo
echo "Source (${SOURCE_DEPLOYMENT}):"
echo "$SOURCE_COUNTS" | head -20
SOURCE_TOTAL=$(echo "$SOURCE_COUNTS" | grep -c .)
echo "... ($SOURCE_TOTAL tables total)"

echo
echo "Target (${TARGET_DEPLOYMENT}):"
echo "$TARGET_COUNTS" | head -20
TARGET_TOTAL=$(echo "$TARGET_COUNTS" | grep -c .)
echo "... ($TARGET_TOTAL tables total)"

# Diff and summarize
DIFF_OUTPUT=$(diff -u --label "Source (${SOURCE_DEPLOYMENT})" <(echo "$SOURCE_COUNTS") \
                 --label "Target (${TARGET_DEPLOYMENT})" <(echo "$TARGET_COUNTS") || true)

echo
echo "--- Comparison Result ---"

if [ -z "$DIFF_OUTPUT" ]; then
  echo "✅ $SOURCE_TOTAL tables match $TARGET_TOTAL tables"
else
  echo "❌ Differences found:"
  # Show differences without context
  echo "Changed tables:"
  echo "$DIFF_OUTPUT" | grep '^[+-]' | grep -v '^+++\|^---'
fi
