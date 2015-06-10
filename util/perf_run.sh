#!/bin/bash
for i in $(seq 1 $1)
do
  ./bin/chearch -nl $i --log_level=2 >> perf_run.txt
done
