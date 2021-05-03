#!/bin/bash
set -euo pipefail

# TODO: parse these variables from arguments
DATE_START="2021-05-02"
DATE_END="2021-05-03"
INCREMENT_IN_HOURS=6

# DEV ONLY
rm -rf matches/*
mkdir -p matches

function utc_time () {
    echo $(date +"%Y-%m-%dT%H:%M:%SZ" -d $1)
}

# convert dates to timestamps
TIMESTAMP_START=$(date -d "${DATE_START}T00:00:00Z" "+%s")
TIMESTAMP_END=$(date -d "${DATE_END}T00:00:00Z" "+%s")

# from TIMESTAMP_START to TIMESTAMP_END, query one increment at a time
TIMESTAMP_QUERY_START=$TIMESTAMP_START
while [[ $TIMESTAMP_QUERY_START -le $TIMESTAMP_END ]]; do
    TIMESTAMP_QUERY_END=$((TIMESTAMP_QUERY_START+(INCREMENT_IN_HOURS*3600)))
    QUERY_START_UTC=$(utc_time @${TIMESTAMP_QUERY_START})
    QUERY_END_UTC=$(utc_time @${TIMESTAMP_QUERY_END})

    echo "querying: ${QUERY_START_UTC} to ${QUERY_END_UTC}"

    matches=$(gcloud logging read "timestamp >= \"${QUERY_START_UTC}\" AND timestamp < \"${QUERY_END_UTC}\" AND \"1w9t17kg1x0ixus\"")

    if [ "${matches}" != "" ]; then
        echo "${matches}" > matches/$(date -d "@${TIMESTAMP_QUERY_START}" "+%Y%m%d%H%M%S").txt
    fi

    TIMESTAMP_QUERY_START=$TIMESTAMP_QUERY_END
done


