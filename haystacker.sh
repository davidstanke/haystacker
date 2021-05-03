#!/bin/bash
set -euo pipefail

function utc_time () {
    echo $(date +"%Y-%m-%dT%H:%M:%SZ" -d $1)
}

startDate="2021-01-29"
endDate="2021-05-02"

startTime=$(date -d "${startDate}T00:00:00Z" "+%s")
endTime=$(date -d "${endDate}T00:00:00Z" "+%s")

echo "startTime: $startTime"
echo "endTime: $endTime"

# from startTime to endTime, query one hour at a time
queryTime=$startTime
while [[ $queryTime -le $endTime ]]; do
    queryEnd=$((queryTime+3600))
    echo "querying: $queryTime to $queryEnd"

    # gcloud logging read "timestamp >= \"$(utc_time ${queryTime})\" AND timestamp < \"$(utc_time ${queryEnd})\" AND labels.\"k8s-pod/app\"=\"currencyservice\"" \
    # > matches/$(date -d "$queryTime" "+%Y%m%d%H%M%S").txt

    utcStart=$(utc_time ${queryTime})
    utcEnd=$(utc_time ${queryEnd})
    echo "utcStart: $utcStart"
    echo "utcEnd: $utcEnd"

    # echo "gcloud logging read timestamp >= \"$(utc_time ${queryTime})\" AND timestamp < \"$(utc_time ${queryEnd})\" AND labels.\"k8s-pod/app\"=\"currencyservice\""

    queryTime=$queryEnd
done

echo "final querytime: $queryTime"


