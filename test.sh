#!/bin/bash
set -euo pipefail

REMOVE="one,
two,
three"

echo "$REMOVE" | while IFS= read -r r; do
  echo "var: ${r//,/}"
done

data-${{ inputs.repository }}-${{ inputs.target }}-bitnami-pg-0
