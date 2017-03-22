#!/bin/bash
#!/bin/sh -e
# run_script.sh
# @desc Run shell script. 
# @usage
# Parameters
# $1 - shell script you want to run
# $2 - filename with extension to store command results
set -o pipefail
{ 
  eval $1 | tee "$2"
} &> /dev/null
exit $?