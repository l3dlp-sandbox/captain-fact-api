#!/usr/bin/env bash

cd -- "$(dirname $0)"
./run_command.sh iex -S mix credo $@
