#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$DIR"

./test_system.sh "$@" && \
./test_xspec.sh "$@" && \
./test_unit.sh "$@"
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
