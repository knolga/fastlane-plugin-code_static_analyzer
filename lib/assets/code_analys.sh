#!/bin/bash -o pipefail
#!/bin/sh -e
# code_analys.sh
# @desc Detect code warnings/errors by using static analyzer build in Xcode. 
# @usage
# 1. Income parameters
# WORKSPACE - name of xcode project workspace (.xcworkspace)
# BUILD_LANE - name of project target
# LOG - path-name of .log file for temporary usage to store full output of Xcode command

WORKSPACE=$1
BUILD_LANE=$2
LOG=$3

#detect warnings
#analyze code (build in xcode tools)
xcodebuild -scheme $BUILD_LANE -workspace $WORKSPACE clean analyze |
tee ${LOG} | 
xcpretty