# haystacker
A tool for finding log entries in Google Cloud Logging. Provide a query for the log entries you seek, and Haystacker will iteratively call the Logging API to find all matching entries across an arbitrarily long timespan.

## How it works
Haystacker follows a three-step process:
```sh
./haystacker.sh --mode=plan <options>
./haystacker.sh --mode=query <options>
./haystacker.sh --mode=aggregate
```
1. **Plan**: break the query down into numerous small `gcloud` commands
2. **Query**: loop across and individually execute those commands. (This step may be interrupted and re-started as needed.)
3. **Aggregate**: stitch the results of all the query invocations into one output file

## How to use
You must be on a linux machine with `gcloud` installed, and be running under a gcloud configuration which has sufficient credentials to query logs for the project you're interested in.

### 1. Plan
This step creates several files in `queries_to_run`, each of which contains one segment of the overall query scope. Several parameters are required[1]:
* `mode`: set this to 'plan'
* `query`:  # the Cloud Logging query to run; enclose in *single quotes*. **Do not include restrictions here**
* `interval_in_hours` (default=24): how much time should be included in each query command. Larger values require fewer API calls; smaller values may cause individual results outputs to be problematically large. Experiment until you find a good balance.
* `start_date`: the date to begin querying, in 'YYYY-MM-DD' format. Dates are understood to be UTC.
* `end_date`: the date to end querying (inclusive).

Example:
```sh
./haystacker.sh --mode=plan \
    --start_date="2021-03-01" \
    --end_date="2021-03-31" \
    --query='"gk3-autopilot-cluster-1-nap-1rsk2zoy-e7036ee3-r4rg" AND severity=WARNING'
```

### 2. Query
To execute the queries, only one parameter is needed:
* `threads` (default=4): the number of threads to use. Each thread spawns a separate query segment in parallel. As each query completes, its output is written to a file in `matches` and the file in `queries_to_run` is deleted.Due to the large amount of time spent waiting for API calls to return, you should be able to set this value pretty high, even on a machine with few cores, without crashing. Experiment until you find a good balance.

**This command will take, by far, the longest to execute.** You can watch its progress by seeing files being created in the `matches` folder and deleted from the `queries_to_run` folder. If this command gets interrupted, you can re-start it. It will re-start any segments that were running when it was interrupted (and overwrite the `matches` output for those segments), then carry on with the remaining segments.

Example:
```sh
./haystacker.sh --mode=query --threads=16
```

### 3. Aggregate
This step collects all the individual outputs from `matches` and concatenates them into a single results file, while deleting the individual result files. It takes no parameters. It creates a file named `merged_results_<timestamp>.txt`

Example:
```sh
./haystacker.sh --mode=aggregate
```



[1] TODO: remove default values and error on unspecified inputs