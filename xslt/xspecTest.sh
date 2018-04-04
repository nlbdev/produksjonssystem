#!/bin/bash


xspecFiles=($(find . -name '*.xspec'))

success=0

#Testing all XSpec files in produksjonssystem
for (( i=0; i<${#xspecFiles[@]}; i++ ));do
  fName=$(basename ${xspecFiles[i]})
  name=$(echo "$fName" | cut -f 1 -d '.')

  #Runs xSpec tests. Log info to tmp/stdXSpecTestName.log.
  xspec.sh -t ${xspecFiles[i]} >/tmp/std${name}.log 2>&1

  #Third line from the bottom is the one containing test status
  numLines=`wc -l < /tmp/std${name}.log`
  numLines=$((numLines-2))
  testStatus=`sed "${numLines}q;d" /tmp/std${name}.log`

  #only numbers of testStatus as array
  nums=$(echo "${testStatus}" | tr -dc ' 0-9')
  arr=($nums)

#If number of fails equals zero
  echo "Testing $fName"
  echo $testStatus
  if [ ${arr[2]} != 0 ]
  then
    echo -e "XSpec test failed. See html file for details."
    success=1
  elif [ ${arr[2]} == 0 ]
    then
    echo -e "XSpec test successful."
  else
    success=1
    echo -e "XSpec error"
  fi
echo -e " \n "

done

#Returns 0 if all tests were successful, 1 otherwise
exit $success
