#!/bin/bash

check_command() {
	command -v "$1" >/dev/null 2>&1
}

if ! check_command jq; then
	echo "jq not found, please install it, https://stedolan.github.io/jq/download/"
	exit 1
fi

JSON_OUTPUT=$(cat pana_output.json)
if [ -z "$JSON_OUTPUT" ]; then
    echo "pana_output.json not found, please run pana first"
    exit 1
fi

echo "JSON_OUTPUT=$JSON_OUTPUT"

SECTIONS=$(echo "$JSON_OUTPUT" | jq -c '.report.sections | map({id: .id, points: .grantedPoints, maxPoints: .maxPoints})')
SCORES=$(echo "$JSON_OUTPUT" | jq -c '.scores')

TOTAL=$(echo "$SECTIONS" | jq -c 'map(.grantedPoints)')
TOTAL_MAX=$(echo "$SECTIONS" | jq -c 'map(.maxPoints)')

CONVENTION=$(echo "$SECTIONS" | jq '.[] | select(.id == "convention") | .points')
CONVENTION_MAX=$(echo "$SECTIONS" | jq '.[] | select(.id == "convention") | .maxPoints')

DOCUMENTATION=$(echo "$SECTIONS" | jq '.[] | select(.id == "documentation") | .points')
DOCUMENTATION_MAX=$(echo "$SECTIONS" | jq '.[] | select(.id == "documentation") | .maxPoints')

PLATFORMS=$(echo "$SECTIONS" | jq '.[] | select(.id == "platform") | .points')
PLATFORMS_MAX=$(echo "$SECTIONS" | jq '.[] | select(.id == "platform") | .maxPoints')

ANALYSIS=$(echo "$SECTIONS" | jq '.[] | select(.id == "analysis") | .points')
ANALYSIS_MAX=$(echo "$SECTIONS" | jq '.[] | select(.id == "analysis") | .maxPoints')

DEPENDENCIES=$(echo "$SECTIONS" | jq '.[] | select(.id == "dependencies") | .points')
DEPENDENCIES_MAX=$(echo "$SECTIONS" | jq '.[] | select(.id == "dependencies") | .maxPoints')

{
    echo "JSON_OUTPUT=$JSON_OUTPUT" | tr '\n' ' '
    echo "TOTAL=$TOTAL"
    echo "TOTAL_MAX=$TOTAL_MAX"
    echo "CONVENTION=$CONVENTION"
    echo "CONVENTION_MAX=$CONVENTION_MAX"
    echo "DOCUMENTATION=$DOCUMENTATION"
    echo "DOCUMENTATION_MAX=$DOCUMENTATION_MAX"
    echo "PLATFORMS=$PLATFORMS"
    echo "PLATFORMS_MAX=$PLATFORMS_MAX"
    echo "ANALYSIS=$ANALYSIS"
    echo "ANALYSIS_MAX=$ANALYSIS_MAX"
    echo "DEPENDENCIES=$DEPENDENCIES"
    echo "DEPENDENCIES_MAX=$DEPENDENCIES_MAX"
} >> $GITHUB_OUTPUT

exit 0
