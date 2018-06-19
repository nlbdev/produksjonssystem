#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$DIR"

./test_system.sh && \
./test_xspec.sh && \
./test_unit.sh
