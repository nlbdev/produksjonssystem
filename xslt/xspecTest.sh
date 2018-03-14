#!/bin/bash

#TEMPDIR="`tempfile`"
#rm "$TEMPDIR" -r && mkdir "$TEMPDIR"
#/tmp/yfjhjhg
xspecFiles=($(find . -name '*.xspec'))

success=0

for (( i=0; i<${#xspecFiles[@]}; i++ ));do
  fName=$(basename ${xspecFiles[i]})
  name=$(echo "$fName" | cut -f 1 -d '.')

  #Runs xSpec tests
  xspec.sh -t ${xspecFiles[i]} >/tmp/std${name}.log 2>&1

  #Third line from the bottom is the one containing test status
  numLines=`wc -l < /tmp/std${name}.log`
  numLines=$((numLines-2))
  testStatus=`sed "${numLines}q;d" /tmp/std${name}.log`

  #only numbers of testStatus as array
  nums=$(echo "${testStatus}" | tr -dc ' 0-9')
  arr=($nums)

  echo "Testing $fName"
  echo $testStatus
  if [ ${arr[2]} != 0 ]
  then
    echo -e "XSpec test failed. See html file for details.\n"
    success=1
  else echo -e "XSpec test successful.\n"
  fi

#  .... >/dev/null 2>&1
#  .... >/tmp/loggfil 2>&1
done

#Returns 0 if all tests was successful, 1 otherwise
exit $success
