#!/bin/bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/.."
DIR="`realpath "$DIR"`"
cd "$DIR"

TEMPDIR="`tempfile`"
rm $TEMPDIR
mkdir $TEMPDIR

export DIR_IN="$TEMPDIR/in"
export DIR_OUT_VALID="$TEMPDIR/out-valid"
export DIR_OUT_INVALID="$TEMPDIR/out-invalid"
export DIR_OUT_REPORT="$TEMPDIR/out-report"
mkdir -p "$DIR_IN" "$DIR_OUT_VALID" "$DIR_OUT_INVALID" "$DIR_OUT_REPORT"



function copy_test_book() {
    sleep 3
    cp "$DIR/tests/C00000.epub" "$DIR_IN/"
}

copy_test_book &
STOP_AFTER_FIRST_JOB=1 timeout 30 ./produksjonssystem/incoming-nordic.py


# wait for all forks to complete
for job in `jobs -p` ; do
    wait $job || echo "failed to stop process #$job"
done

rm "$TEMPDIR" -rf

