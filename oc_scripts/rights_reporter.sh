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
declare -A ENV_COUNTS
declare -A TEAM_COUNTS
declare -A TEAM_ADMIN_COUNTS
declare -A TEAM_EDIT_COUNTS
declare -A TEAM_VIEW_COUNTS
declare -A PROJECT_DETAILS

# Initialize role counts to 0
for role in ${ROLES}; do
  ROLE_COUNTS[$role]=0
done

# Initialize environment counts
ENV_COUNTS["dev"]=0
ENV_COUNTS["test"]=0
ENV_COUNTS["prod"]=0
ENV_COUNTS["tools"]=0

# Risk indicators
PROJECTS_NO_EDIT=0
PROJECTS_NO_VIEW=0
PROJECTS_MANY_ADMIN=0

# Loop through the projects and report on rights
for p in $(echo "${PROJECTS}" | awk '{print $1}'); do
  PROJECT_COUNT=$((PROJECT_COUNT + 1))
  echo -e "\n---\n\nProject: $p"
  echo -e "Name: $(echo "${PROJECTS}" | grep -w "$p" | awk -F" - " '{print $2}')"

  # Extract team prefix and environment
  TEAM_PREFIX=$(echo "$p" | cut -d'-' -f1)
  ENVIRONMENT=$(echo "$p" | cut -d'-' -f2)
  
  # Count teams and environments
  TEAM_COUNTS["$TEAM_PREFIX"]=1
  if [ -n "${ENV_COUNTS[$ENVIRONMENT]:-}" ]; then
    ENV_COUNTS["$ENVIRONMENT"]=$((ENV_COUNTS["$ENVIRONMENT"] + 1))
  fi
  
  # Initialize team role counts if not set
  if [ -z "${TEAM_ADMIN_COUNTS[$TEAM_PREFIX]:-}" ]; then
    TEAM_ADMIN_COUNTS["$TEAM_PREFIX"]=0
    TEAM_EDIT_COUNTS["$TEAM_PREFIX"]=0
    TEAM_VIEW_COUNTS["$TEAM_PREFIX"]=0
  fi

  # Report on requested roles, where possible
  if oc get rolebindings -n "$p" &> /dev/null; then
    PROJECT_ADMIN_COUNT=0
    PROJECT_EDIT_COUNT=0
    PROJECT_VIEW_COUNT=0
    
    for role in ${ROLES}; do
      echo -e "\n${role}:"
      USERS_IN_PROJECT=$(oc get rolebindings -n "$p" -o json \
        | jq -r ".items[] | select(.roleRef.name==\"${role}\") | .subjects[] | select(.kind==\"User\") | .name" \
        | grep -E ".+@.+" | sort | uniq 2>/dev/null || true)
      
      if [ -n "$USERS_IN_PROJECT" ]; then
        echo "$USERS_IN_PROJECT" | sed "s/^/  /g"
        USER_COUNT=$(echo "$USERS_IN_PROJECT" | wc -l)
        ROLE_COUNTS[$role]=$((ROLE_COUNTS[$role] + USER_COUNT))
        
        # Track counts for risk analysis
        case "$role" in
          "admin") 
            PROJECT_ADMIN_COUNT=$USER_COUNT
            TEAM_ADMIN_COUNTS["$TEAM_PREFIX"]=$((TEAM_ADMIN_COUNTS["$TEAM_PREFIX"] + USER_COUNT))
            ;;
          "edit") 
            PROJECT_EDIT_COUNT=$USER_COUNT
            TEAM_EDIT_COUNTS["$TEAM_PREFIX"]=$((TEAM_EDIT_COUNTS["$TEAM_PREFIX"] + USER_COUNT))
            ;;
          "view") 
            PROJECT_VIEW_COUNT=$USER_COUNT
            TEAM_VIEW_COUNTS["$TEAM_PREFIX"]=$((TEAM_VIEW_COUNTS["$TEAM_PREFIX"] + USER_COUNT))
            ;;
        esac
      else
        echo "  (none found)"
      fi
    done
    
    # Risk analysis
    if [ $PROJECT_EDIT_COUNT -eq 0 ]; then
      PROJECTS_NO_EDIT=$((PROJECTS_NO_EDIT + 1))
    fi
    if [ $PROJECT_VIEW_COUNT -eq 0 ]; then
      PROJECTS_NO_VIEW=$((PROJECTS_NO_VIEW + 1))
    fi
    if [ $PROJECT_ADMIN_COUNT -gt 5 ]; then
      PROJECTS_MANY_ADMIN=$((PROJECTS_MANY_ADMIN + 1))
    fi
    
    # Store project details for team analysis
    PROJECT_DETAILS["$p"]="$PROJECT_ADMIN_COUNT:$PROJECT_EDIT_COUNT:$PROJECT_VIEW_COUNT"
  else
    echo -e "\nInsufficient rights"
  fi
done

# Calculate team count
TEAM_COUNT=${#TEAM_COUNTS[@]}

# Calculate ratios
if [ ${ROLE_COUNTS["edit"]} -gt 0 ]; then
  ADMIN_EDIT_RATIO=$(echo "scale=1; ${ROLE_COUNTS["admin"]} / ${ROLE_COUNTS["edit"]}" | bc 2>/dev/null || echo "N/A")
else
  ADMIN_EDIT_RATIO="∞"
fi

if [ ${ROLE_COUNTS["view"]} -gt 0 ]; then
  ADMIN_VIEW_RATIO=$(echo "scale=1; ${ROLE_COUNTS["admin"]} / ${ROLE_COUNTS["view"]}" | bc 2>/dev/null || echo "N/A")
else
  ADMIN_VIEW_RATIO="∞"
fi

# Summary stats
echo -e "\n---\n"
echo -e "Summary:"
echo -e "  Projects analyzed: $PROJECT_COUNT"
echo -e "  Teams analyzed: $TEAM_COUNT"
echo -e "  Total users with 'admin' role: ${ROLE_COUNTS["admin"]}"
echo -e "  Total users with 'edit' role: ${ROLE_COUNTS["edit"]}"
echo -e "  Total users with 'view' role: ${ROLE_COUNTS["view"]}"

echo -e "\nEnvironment Breakdown:"
echo -e "  Development projects: ${ENV_COUNTS["dev"]}"
echo -e "  Testing projects: ${ENV_COUNTS["test"]}"
echo -e "  Production projects: ${ENV_COUNTS["prod"]}"
echo -e "  Tools projects: ${ENV_COUNTS["tools"]}"

echo -e "\nRisk Indicators:"
echo -e "  Projects with 0 edit users: $PROJECTS_NO_EDIT"
echo -e "  Projects with 0 view users: $PROJECTS_NO_VIEW"
echo -e "  Projects with >5 admin users: $PROJECTS_MANY_ADMIN"
echo -e "  Admin-to-edit ratio: $ADMIN_EDIT_RATIO"
echo -e "  Admin-to-view ratio: $ADMIN_VIEW_RATIO"

# Team comparison table
if [ $TEAM_COUNT -gt 1 ]; then
  echo -e "\nTeam Comparison:"
  echo -e "Team     | Admin | Edit | View | Risk Level"
  echo -e "---------|-------|------|------|-----------"
  for team in "${!TEAM_COUNTS[@]}"; do
    ADMIN_COUNT=${TEAM_ADMIN_COUNTS[$team]:-0}
    EDIT_COUNT=${TEAM_EDIT_COUNTS[$team]:-0}
    VIEW_COUNT=${TEAM_VIEW_COUNTS[$team]:-0}
    
    # Determine risk level
    if [ $EDIT_COUNT -eq 0 ] && [ $VIEW_COUNT -eq 0 ]; then
      RISK_LEVEL="HIGH"
    elif [ $ADMIN_COUNT -gt $((EDIT_COUNT + VIEW_COUNT)) ]; then
      RISK_LEVEL="MEDIUM"
    else
      RISK_LEVEL="LOW"
    fi
    
    printf "%-8s | %5d | %4d | %4d | %s\n" "$team" "$ADMIN_COUNT" "$EDIT_COUNT" "$VIEW_COUNT" "$RISK_LEVEL"
  done
fi

echo -e "\n---\n"
