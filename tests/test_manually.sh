#!/bin/bash
set -e

DIR="/tmp/produksjonssystem"
mkdir -p "$DIR"

export DIR_IN="$DIR/nordic-in"
export DIR_OUT_VALID="$DIR/epub-master"
export DIR_OUT_INVALID="$DIR/epub-master.invalid"
export DIR_OUT_REPORT="$DIR/epub-master.report"
mkdir -p "$DIR_IN" "$DIR_OUT_VALID" "$DIR_OUT_INVALID" "$DIR_OUT_REPORT"
./produksjonssystem/incoming-nordic.py &

export DIR_IN="$DIR/epub-master"
export DIR_OUT_VALID="$DIR/dtbook"
export DIR_OUT_REPORT="$DIR/dtbook.report"
mkdir -p "$DIR_IN" "$DIR_OUT_VALID" "$DIR_OUT_REPORT"
./produksjonssystem/epub-to-dtbook.py &

# wait for all forks to complete
for job in `jobs -p` ; do
    wait $job || echo "failed to stop process #$job"
done

rm "$DIR" -rf

