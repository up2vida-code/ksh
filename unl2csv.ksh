#!/bin/ksh
###############################################################################
# Program     :  /usr/local/bin/unl2csv
# File        :  unl2csv
# Description :  Convert a pipe deimited data file (typically a ".unl" file)
#             :  to a coma-separated-values (".csv") file.
# Date written:  01-06-2005
# Author      :  Richard Bergeron
#                EliteNet
###############################################################################
# Edit history:
# ------------
# rbergero091420     Initial coding.
###############################################################################

if [ $# -lt 2 -o $# -gt 3 ]
then
    echo "?usage: $0 UNL_FILENAME CSV_FILENAME [HEADER_FILENAME]"
    exit 1
fi

UNLFILE=$1
CSVFILE=$2
HEADER=$3

(
if [ -r "$HEADER" ]
then
    cat $HEADER
fi
awk -F "|" '
{
for (I=1; I<=NF; I++) {
    if (I < NF) printf "\"%s\",", $I
    else printf "\"%s\"\n", $I;
    }
}
' $UNLFILE
) >$CSVFILE