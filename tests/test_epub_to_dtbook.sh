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
export DIR_OUT_REPORT="$TEMPDIR/out-report"
mkdir -p "$DIR_IN" "$DIR_OUT_VALID" "$DIR_OUT_REPORT"

trap 'kill $(jobs -p)' EXIT

function copy_test_book() {
    sleep 3
    unzip "$DIR/tests/C00000.epub" -d "$DIR_IN/C00000"
    chmod -R 777 "$DIR_IN/C00000"
    find "$DIR_IN/C00000" -type f | grep -v " " | xargs chmod 666
}

copy_test_book &
STOP_AFTER_FIRST_JOB=1 timeout 30 ./produksjonssystem/epub-to-dtbook.py


# wait for all forks to complete
for job in `jobs -p` ; do
    wait $job || echo "failed to stop process #$job"
done

find $TEMPDIR
#rm "$TEMPDIR" -rf

