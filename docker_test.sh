#! /usr/bin/env bash

set -e

function message() {
    echo
    echo -----------------------------------
    echo "$@"
    echo -----------------------------------
    echo
}

message BUILDING DOCKER IMAGE
docker build -t makerdao/dss-exigency-test .

message RUNNING TESTS
# 2022/08/10 Repo re-write is in backlog, disable CI testing
# docker run --rm -it -e ETH_RPC_URL=${ETH_RPC_URL} makerdao/dss-exigency-test
