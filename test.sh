#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$DIR"

if [ "$1" = "debug" ]; then
    export DEBUG=1
else
    export DEBUG=0
fi

./test_system.sh && \
./test_xspec.sh && \
./test_unit.sh
RESULT="$?"

if [ "$RESULT" = "0" ]; then
  echo
  echo "All tests passed successfully."
  exit 0

else
  echo
  echo "There are test errors."
  exit 1
fi
