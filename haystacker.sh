#!/bin/bash
set -euo pipefail

# parse command-line options
OPTS=`getopt -o m: --long mode: -n 'parse-options' -- "$@"`

if [ $? != 0 ] ; then echo "Failed parsing options." >&2 ; exit 1 ; fi

eval set -- "$OPTS"

# default option values
MODE="(UNSPECIFIED)"

# parse options into values
while true; do
    case "$1" in
        -m | --mode ) MODE="$2"; shift; shift ;;
        -- ) shift; break ;;
        * ) break ;;
    esac
done

function utc_time () {
    echo $(date +"%Y-%m-%dT%H:%M:%SZ" -d $1)
}

function query () {
    # TODO: parse these variables from arguments
    DATE_START="2021-04-27"
    DATE_END="2021-04-27"
    INCREMENT_IN_HOURS=6
    INCREMENT_IN_SECONDS=$((INCREMENT_IN_HOURS*3600))

    # DEV ONLY
    rm -rf matches/*
    mkdir -p matches

    # convert dates to timestamps
    TIMESTAMP_START=$(date -d "${DATE_START}T00:00:00Z" "+%s")
    TIMESTAMP_END=$(date -d "${DATE_END}T00:00:00Z + 1 day - 1 second" "+%s")

    # from TIMESTAMP_START to TIMESTAMP_END, query one increment at a time
    TIMESTAMP_QUERY_START=$TIMESTAMP_START
    while [[ $TIMESTAMP_QUERY_START -le $TIMESTAMP_END ]]; do
        TIMESTAMP_QUERY_END=$((TIMESTAMP_QUERY_START+INCREMENT_IN_SECONDS))
        QUERY_END_MINUS_ONE=$((TIMESTAMP_QUERY_END-1))
        QUERY_START_UTC=$(utc_time @${TIMESTAMP_QUERY_START})
        QUERY_END_UTC=$(utc_time @${QUERY_END_MINUS_ONE})

        echo "querying: ${QUERY_START_UTC} to ${QUERY_END_UTC}"

        matches=$(gcloud logging read "timestamp >= \"${QUERY_START_UTC}\" AND timestamp < \"${QUERY_END_UTC}\" AND \"gk3-autopilot-cluster-1-nap-1rsk2zoy-e7036ee3-r4rg\" AND severity=WARNING")

        if [ "${matches}" != "" ]; then
            echo "${matches}" > matches/$(date -d "@${TIMESTAMP_QUERY_START}" "+%Y%m%d%H%M%S").txt
        fi

        TIMESTAMP_QUERY_START=$TIMESTAMP_QUERY_END
    done
}

function aggregate () {
    # DEV ONLY
    rm -rf matches/merged_*

    echo "aggregating results to file: matches/merged_results.txt"
    cat matches/*.txt > matches/merged_results.txt
}

if [[ "$MODE" == "query" ]]; then
    query
elif [[ "$MODE" == "aggregate" ]]; then
    aggregate
else
    echo "unknown mode specified: $MODE"
    exit 1
fi