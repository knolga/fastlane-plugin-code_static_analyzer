#!/bin/bash -o pipefail
#!/bin/sh -e
# cpd_code_analys.sh
# @desc Detect copy-paste code. 
# @usage
# Use CPD (build in PMD).

SRCROOT='./artifacts/'			
pmd cpd \
	--minimum-tokens 100 \
 	--files . \
 	--language objectivec \
 	--exclude ./Pods ./ThirdParty/ \
 	--format xml > "${SRCROOT}copypaste.xml"