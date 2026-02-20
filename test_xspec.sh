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

cd "$DIR/xslt"

xspecFiles=($(find . -name '*.xspec'))

success=0

print_help() {
  echo "Usage: $0 <subcommand> [args]"
  echo ""
  echo "Subcommands:"
  echo "  help                Show this help message"
  echo "  list                List all available xspec test files"
  echo "  run <xspec-file>    Run the specified xspec test file"
  echo "  run-all             Run all xspec tests"
}

list_xspec_tests() {
  for (( i=0; i<${#xspecFiles[@]}; i++ ));do
    echo "${xspecFiles[i]}"
  done
}

find_xspec_file() {
  local query="$1"
  local normalizedQuery="$query"
  local candidate
  local matches=()

  if [[ "$normalizedQuery" != ./* ]]; then
    normalizedQuery="./$normalizedQuery"
  fi

  if [[ "$normalizedQuery" != *.xspec ]]; then
    normalizedQuery="$normalizedQuery.xspec"
  fi

  for (( i=0; i<${#xspecFiles[@]}; i++ ));do
    candidate="${xspecFiles[i]}"
    if [ "$candidate" = "$query" ] || [ "$candidate" = "$normalizedQuery" ] || [ "$(basename "$candidate")" = "$query" ] || [ "$(basename "$candidate")" = "$(basename "$normalizedQuery")" ]; then
      matches+=("$candidate")
    fi
  done

  if [ ${#matches[@]} -eq 1 ]; then
    echo "${matches[0]}"
    return 0
  elif [ ${#matches[@]} -gt 1 ]; then
    echo "Ambiguous xspec file: $query" >&2
    echo "Multiple matches found:" >&2
    for (( i=0; i<${#matches[@]}; i++ ));do
      echo "  ${matches[i]}" >&2
    done
    return 1
  fi

  echo "XSpec file not found: $query" >&2
  return 1
}

run_xspec_test() {
  local xspecFile="$1"
  local printToConsole="${2:-false}"

  # Declare local variables to avoid conflicts
  local fName
  local name
  local numLines
  local testStatus
  local nums
  local arr
  local failedCount

  fName=$(basename "$xspecFile")
  name=$(echo "$fName" | cut -f 1 -d '.')

  # Runs xSpec tests. Log info to TARGET_DIR/stdXSpecTestName.log.
  if [ "$printToConsole" = "true" ]; then
    $XSPEC -t "$xspecFile" | tee "$TARGET_DIR/$name.log"
  else
    $XSPEC -t "$xspecFile" >"$TARGET_DIR/$name.log" 2>&1
  fi

  #Third line from the bottom is the one containing test status
  numLines=`wc -l < "$TARGET_DIR/$name.log"`
  numLines=$((numLines-2))
  testStatus=`sed "${numLines}q;d" "$TARGET_DIR/$name.log"`

  #only numbers of testStatus as array
  nums=$(echo "${testStatus}" | tr -dc ' 0-9')
  arr=($nums)
  failedCount="${arr[2]}"

  #If number of fails equals zero
  echo "Testing $fName"
  if [ -n "$testStatus" ]; then
    echo "$testStatus"
  else
    echo "Could not determine test status from log output."
  fi

  if [ -z "$failedCount" ]; then
    echo -e "XSpec error"
    echo -e "See log for details: $TARGET_DIR/$name.log"
    echo -e " \n "
    return 1
  fi

  if [ "$failedCount" != 0 ]
  then
    echo -e "XSpec test failed. See html file for details."
    echo -e " \n "
    return 1
  elif [ "$failedCount" = 0 ]
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

command="$1"

if [ "$command" = "" ] || [ "$command" = "help" ]; then
  print_help
  exit 0
elif [ "$command" = "list" ]; then
  list_xspec_tests
  exit 0
elif [ "$command" = "run" ]; then
  if [ "$2" = "" ]; then
    echo "Missing xspec file argument for 'run'" >&2
    echo "" >&2
    print_help
    exit 1
  fi

  selected_file=$(find_xspec_file "$2")
  prepare_xspec_environment
  if run_xspec_test "$selected_file" "true"; then
    exit 0
  fi
  exit 1
elif [ "$command" = "run-all" ]; then
  prepare_xspec_environment
  if run_all_xspec_tests; then
    exit 0
  fi
  exit 1
else
  echo "Unknown subcommand: $command" >&2
  echo "" >&2
  print_help
  exit 1
fi
