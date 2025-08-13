#!/bin/bash
set -euo pipefail

# This script reports on rights in OpenShift projects
# Usage: ./rights_reporter.sh [roles]
# Example: ./rights_reporter.sh "admin edit view basic-user"
echo -e "OpenShift users for projects accessible to $(oc whoami)"

# Projects available to the current user
PROJECTS=$(oc projects | sed "s/\*/ /g" | grep -E "^ +.*-.*(.*)$")

# Roles to report on, can be overridden with a quoted parameter
ROLES=${1:-"admin edit view"}

# Initialize counters
PROJECT_COUNT=0
declare -A ROLE_COUNTS

# Initialize role counts to 0
for role in ${ROLES}; do
  ROLE_COUNTS[$role]=0
done

# Loop through the projects and report on rights
for p in $(echo "${PROJECTS}" | awk '{print $1}'); do
  PROJECT_COUNT=$((PROJECT_COUNT + 1))
  echo -e "\n---\n\nProject: $p"
  echo -e "Name: $(echo "${PROJECTS}" | grep -w "$p" | awk -F" - " '{print $2}')"

  # Report on requested roles, where possible
  if oc get rolebindings -n "$p" &> /dev/null; then
    for role in ${ROLES}; do
      echo -e "\n${role}:"
      USERS_IN_PROJECT=$(oc get rolebindings -n "$p" -o json \
        | jq -r ".items[] | select(.roleRef.name==\"${role}\") | .subjects[] | select(.kind==\"User\") | .name" \
        | grep -E ".+@.+" | sort | uniq 2>/dev/null || true)
      
      if [ -n "$USERS_IN_PROJECT" ]; then
        echo "$USERS_IN_PROJECT" | sed "s/^/  /g"
        USER_COUNT=$(echo "$USERS_IN_PROJECT" | wc -l)
        ROLE_COUNTS[$role]=$((ROLE_COUNTS[$role] + USER_COUNT))
      else
        echo "  (none found)"
      fi
    done
  else
    echo -e "\nInsufficient rights"
  fi
done

# Summary stats
echo -e "\n---\n"
echo -e "Summary:"
echo -e "  Projects analyzed: $PROJECT_COUNT"
for role in ${ROLES}; do
  echo -e "  Total users with '$role' role: ${ROLE_COUNTS[$role]}"
done
echo -e "\n---\n"
