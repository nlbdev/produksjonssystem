#!/bin/bash -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

prepare_xspec_environment() {
  # Find Saxon so that XSpec can find it
  if [ "$PIPELINE2_HOME" = "" ]; then
    PIPELINE2_HOME="/opt/daisy-pipeline2"
    if [ ! -d "$PIPELINE2_HOME" ]; then
      PIPELINE2_HOME="$HOME/Desktop/daisy-pipeline"
      if [ ! -d "$PIPELINE2_HOME" ]; then
        print "Could not find Pipeline 2 installation; unable to locate Saxon"
        exit 1
      fi
    fi
  fi
  export SAXON_CP="`find $PIPELINE2_HOME | grep "\.jar$" | grep "saxon-he" | head -n 1`"

  TARGET_DIR="$DIR/target/xspec"
  if [ -d "$TARGET_DIR" ]; then
    rm "$TARGET_DIR" -r
  fi
  mkdir -p "$TARGET_DIR"

  XSPEC="$DIR/tests/tools/xspec/bin/xspec.sh"
}

prepare_xspec_environment

cd "$DIR/xslt"

xspecFiles=($(find . -name '*.xspec'))

success=0

run_xspec_test() {
  local xspecFile="$1"

  # Declare local variables to avoid conflicts
  local fName
  local name
  local numLines
  local testStatus
  local nums
  local arr

  fName=$(basename "$xspecFile")
  name=$(echo "$fName" | cut -f 1 -d '.')

  #Runs xSpec tests. Log info to TARGET_DIR/stdXSpecTestName.log.
  $XSPEC -t "$xspecFile" >"$TARGET_DIR/$name.log" 2>&1

  #Third line from the bottom is the one containing test status
  numLines=`wc -l < "$TARGET_DIR/$name.log"`
  numLines=$((numLines-2))
  testStatus=`sed "${numLines}q;d" "$TARGET_DIR/$name.log"`

  #only numbers of testStatus as array
  nums=$(echo "${testStatus}" | tr -dc ' 0-9')
  arr=($nums)

  #If number of fails equals zero
  echo "Testing $fName"
  echo $testStatus
  if [ ${arr[2]} != 0 ]
  then
    echo -e "XSpec test failed. See html file for details."
    echo -e " \n "
    return 1
  elif [ ${arr[2]} == 0 ]
  then
    echo -e "XSpec test successful."
    echo -e " \n "
    return 0
  else
    echo -e "XSpec error"
    echo -e " \n "
    return 1
  fi
}

run_all_xspec_tests() {
  local success=0

  #Testing all XSpec files in produksjonssystem
  for (( i=0; i<${#xspecFiles[@]}; i++ ));do
    if ! run_xspec_test "${xspecFiles[i]}"
    then
      success=1
    fi
  done

  return $success
}

if run_all_xspec_tests; then
  exit 0
fi
exit 1
