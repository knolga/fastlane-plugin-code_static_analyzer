#!/bin/bash -o pipefail
#!/bin/sh -e
# code_analys.sh
# @desc Detect code warnings/errors by using static analyzer build in Xcode. 
# @usage
# 1. Income parameters
# WORKSPACE_PROJECT - name of xcode project or workspace (.xcodeproj / .xcworkspace)
# BUILD_LANE - name of project target
# LOG - path-name of .log file for temporary usage to store full output of Xcode command
# IN_WORKSPACE - true if WORKSPACE_PROJECT=.xcworkspace

WORKSPACE_PROJECT=$1
BUILD_LANE=$2
LOG=$3
IN_WORKSPACE=$4

#detect warnings
#analyze code (build in xcode tools)
if $IN_WORKSPACE; then
  xcodebuild -scheme $BUILD_LANE -workspace $WORKSPACE_PROJECT clean analyze |
  tee "$LOG" | 
  xcpretty
else
  xcodebuild -scheme $BUILD_LANE -project $WORKSPACE_PROJECT clean analyze |
  tee "$LOG" | 
  xcpretty
fi