#!/bin/bash
# Data extraction: Free disk space per storj node
# Usage: ./data/8-nodespace.sh
# Output: colon-separated values: free0:free1:free2
echo -n $(docker logs --since 2m storagenode3 2>&1 | grep "Available Space" | tail -n 1 | sed "s/.*{/{/" | jq ".[\"Available Space\"]"):
echo -n $(docker logs --since 2m storagenode1 2>&1 | grep "Available Space" | tail -n 1 | sed "s/.*{/{/" | jq ".[\"Available Space\"]"):
echo -n $(docker logs --since 2m storagenode2 2>&1 | grep "Available Space" | tail -n 1 | sed "s/.*{/{/" | jq ".[\"Available Space\"]")
