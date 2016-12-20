#!/bin/bash -o pipefail
#!/bin/sh -e
# cpd_code_analys.sh
# @desc Detect copy-paste code. 
# @usage
# Use CPD (build in PMD).

RESULT_FILE=$1	
TOKENS=$2	
FILES=$3	
FILES_EXCLUDE=$4	
LAN=$5	

pmd cpd \
	--minimum-tokens $TOKENS \
 	--files $FILES \
 	--language $LAN \
 	--exclude $FILES_EXCLUDE \
 	--format xml > $RESULT_FILE