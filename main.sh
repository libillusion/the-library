#!/bin/bash
echo "Benchmarking with 500 entries..."
source libijson.sh
time ijson_parse_to bench <./benchmarking_data.json
echo "Memory usage"
grep 'VmRSS\|VmSize' /proc/self/status
echo "\$ bench.get 40"
bench.get 40
