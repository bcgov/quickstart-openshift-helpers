#!/bin/bash

# Database Table Count Comparison Script for OpenShift
# Usage:
#   ./db_compare.sh <source-deployment> <target-deployment>
#
# This script compares PostgreSQL table row counts between two OpenShift deployments
# to validate database transfers or check data consistency between environments.
#
# Requirements:
# - Both deployments must have running PostgreSQL pods
# - Environment variables POSTGRES_USER and POSTGRES_DB must be set
# - The oc CLI must be authenticated to the OpenShift cluster
#
# Notes:
# - Uses pg_stat_user_tables to get live row counts
# - Reports differences in table names or row counts between environments
# - Returns exit code 0 if counts match, 1 if differences found

# Strict mode: exit on error, unset vars, or failed pipes
set -euo pipefail

# Usage
if [[ $# -lt 2 ]]; then
  grep -v '^#!' "$0" | awk '/^#/ { sub(/^# ?/, ""); print; next } NF==0 { exit }'
  exit 1
fi

# Set these to your actual deployment names
SOURCE_DEPLOYMENT="source-db"
TARGET_DEPLOYMENT="target-db"

# Query to get table names and row counts
COUNT_QUERY="
SELECT schemaname || '.' || relname AS table_name, n_live_tup AS row_count
FROM pg_stat_user_tables
ORDER BY table_name;
"

# Run the query on source
echo "Collecting table counts from source..."
SOURCE_COUNTS=$(oc exec deployment/${SOURCE_DEPLOYMENT} -- \
  psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Atc "$COUNT_QUERY")

# Run the query on target
echo "Collecting table counts from target..."
TARGET_COUNTS=$(oc exec deployment/${TARGET_DEPLOYMENT} -- \
  psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Atc "$COUNT_QUERY")

# Save to temp files
echo "$SOURCE_COUNTS" > /tmp/source_counts.txt
echo "$TARGET_COUNTS" > /tmp/target_counts.txt

# Diff the outputs
echo
echo "Comparing source and target table counts..."
DIFF_OUTPUT=$(diff -u /tmp/source_counts.txt /tmp/target_counts.txt)

if [ -z "$DIFF_OUTPUT" ]; then
  echo "✅ Backup and restore validation passed: all tables and row counts match."
else
  echo "❌ Differences detected:"
  echo "$DIFF_OUTPUT"
fi
