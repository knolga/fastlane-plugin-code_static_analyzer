#!/bin/bash -o pipefail
#!/bin/sh -e
# code_analys.sh
# @desc Detect code warnings/errors by using static analyzer build in Xcode. 
# @usage
# 1. Income parameters
# BUILD_LANE - name of project scheme
# LOG - name of .log file for temporary usage to store full output of Xcode command
# TEMP_LOG - name of .log file for temporary usage to store detected warnings/errors (unformatted)

BUILD_LANE=$1
LOG=$2
SRCROOT=$3

#detect warnings
#analyze code (build in xcode tools)
xcodebuild -scheme $BUILD_LANE -workspace 'mobilecasino.xcworkspace' clean analyze |
tee "${SRCROOT}${LOG}" | 
xcpretty