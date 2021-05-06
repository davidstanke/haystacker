#!/bin/bash
set -euo pipefail

# parse command-line options
OPTS=`getopt -o "m:q:t:i:s:e:" --long "mode:,query:,threads:,interval_in_hours:,start_date:,end_date:" -n 'parse-options' -- "$@"`

if [ $? != 0 ] ; then echo "Failed parsing options." >&2 ; exit 1 ; fi

eval set -- "$OPTS"

# default option values
MODE='(UNSPECIFIED)'
DATE_START='(UNSPECIFIED)'
DATE_END='(UNSPECIFIED)'
INCREMENT_IN_HOURS=24
THREADS=4
QUERY_STRING='(UNSPECIFIED)'

# parse options into values
while true; do
	case "$1" in
		-m | --mode ) MODE="$2"; shift; shift ;;
		-q | --query ) QUERY_STRING="$2"; shift; shift ;;
		-t | --threads ) THREADS="$2"; shift; shift ;;
		-i | --interval_in_hours ) INCREMENT_IN_HOURS="$2"; shift; shift ;;
		-s | --start_date ) DATE_START="$2"; shift; shift ;;
		-e | --end_date ) DATE_END="$2"; shift; shift ;;
		-- ) shift; break ;;
		* ) break ;;
	esac
done

INCREMENT_IN_SECONDS=$((INCREMENT_IN_HOURS*3600))

function utc_time () {
	echo $(date +"%Y-%m-%dT%H:%M:%SZ" -d $1)
}

function plan () {

	date_mask="^20[0-9][0-9]-[0-9][0-9]-[0-9][0-9]$"

	if [[ $DATE_START == '(UNSPECIFIED)' || $DATE_END == '(UNSPECIFIED)' || $QUERY_STRING == '(UNSPECIFIED)' ]]; then
		echo "Missing required parameters; please specify 'start_date', 'end_date', and 'query'."
		exit 1
	elif [[ ! ($DATE_START =~ $date_mask && $DATE_END =~ $date_mask) ]]; then
		echo "Invalid date format. Please specify start_date and end_date in format YYYY-MM-DD"
		exit 1
	fi

	rm -rf matches/*
	rm -rf queries_to_run/*

	mkdir -p matches
	mkdir -p queries_to_run

	# convert dates to timestamps
	TIMESTAMP_START=$(date -d "${DATE_START}T00:00:00Z" "+%s")
	TIMESTAMP_END=$(date -d "${DATE_END}T00:00:00Z + 1 day - 1 second" "+%s")

	# from TIMESTAMP_START to TIMESTAMP_END, query one increment at a time
	TIMESTAMP_QUERY_START=$TIMESTAMP_START

	# write the gcloud commands to be run into a file
	while [[ $TIMESTAMP_QUERY_START -le $TIMESTAMP_END ]]; do
		TIMESTAMP_QUERY_END=$((TIMESTAMP_QUERY_START+INCREMENT_IN_SECONDS))
		QUERY_END_MINUS_ONE=$((TIMESTAMP_QUERY_END-1))
		QUERY_START_UTC=$(utc_time @${TIMESTAMP_QUERY_START})
		QUERY_END_UTC=$(utc_time @${QUERY_END_MINUS_ONE})

		this_query="gcloud logging read 'timestamp >= \"${QUERY_START_UTC}\" AND timestamp < \"${QUERY_END_UTC}\" AND ${QUERY_STRING}' > matches/${TIMESTAMP_QUERY_START}.txt && rm queries_to_run/${TIMESTAMP_QUERY_START}.txt"
		echo $this_query > queries_to_run/${TIMESTAMP_QUERY_START}.txt

		TIMESTAMP_QUERY_START=$TIMESTAMP_QUERY_END
	done

	# write metadata to a file (so it can be prepended to the results)
	cat <<-EOF > matches/_metadata.txt
	# Google Cloud Logs search
	# Query date range: $DATE_START to $DATE_END (UTC)
	# Query search string: '$QUERY_STRING'
	EOF
}

function query () {
	# parallelize execution of the gcloud commands
	queries=$(find queries_to_run -name '*.txt')
	if [[ $queries ]]; then
		cat $queries | xargs -L 1 -P ${THREADS} --delimiter='\n' bash -c
	else
		echo "There are no queries to run. Exiting."
		exit 1
	fi
}

function aggregate () {
	if [[ $(find queries_to_run -name '*.txt') ]]; then
		echo "there are queries remaining to be executed"
		echo "please run \"./haystacker.sh --mode=query --threads={threads}\""
		exit 1
	elif [[ $(find matches -name '*.txt') ]]; then
		echo "aggregating results to file: merged_results_$(date '+%s').txt"
		cat $(find matches -name '*.txt') > merged_results_$(date '+%s').txt
		rm matches/*.txt
	else
		echo "The 'matches' directory is empty; nothing to aggregate. Exiting."
		exit 1
	fi
}

if [[ "$MODE" == "plan" ]]; then
	plan
elif [[ "$MODE" == "query" ]]; then
	query
elif [[ "$MODE" == "aggregate" ]]; then
	aggregate
else
	echo "unknown mode specified: $MODE"
	exit 1
fi