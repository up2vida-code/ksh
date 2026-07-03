#!/bin/ksh
###############################################################################
# Program     :  csv2unl
# File        :  /usr/local/bin/csv2unl
# Description :  Convert a file from "comma separated values" format to
#                pipe-delimited Informix "unload" format.
# Date written:  07-16-2007
# Author      :  Richard Bergeron
###############################################################################
# Notes:
# -----
# This script is implemented as a filter, accepting the "csv" stream as
# standard in and sending the "unl" stream to standard out.  The following
# optional command line parameters may be used:
#
# -o FIELD_LIST
#    This is a coma separated list of input field numbers to output.  The
#    default is to output all input fields.
# -s SKIP_LINES
#    This is the number if input lines to skip before processing begins.
#    This can be used to bypass a header line, for example, by speciying
#    "-s 1".  The default is to skip no lines.
# -d DELIMITER
#    This specifies the delimiter to be used for the output.  The default is
#    the pipe -- "|".
# -c COLUMNS
#    Number of columns to output.  If the number of columns for a particular
#    input line is less than the specified number, additional empty columns
#    will be added to the output line.
#
###############################################################################
# Edit history:
# ------------
# rbergeron     Initial coding.
###############################################################################

if [ "$1" = "-?" ]
then
    echo "?Usage:"
    echo "    $0 [-o FIELD_LIST] [-s SKIP_LINES] [-d DELIMITER] [-c OUTCOLS] [<C
SVFILE] [>UNLFILE]"
    exit 1
fi

####
# Apply default options:

SKIP_LINES=0
DELIMITER="|"
FIELD_LIST=""
OUTCOLS=0

####
# Parse command line options:

while [ "$1" != "" ]
do
  OPTION=$1
  shift
  case $OPTION in
    -d) DELIMITER=$1; shift; continue;;
    -s) SKIP_LINES=$1; shift; continue;;
    -o) FIELD_LIST=$1; shift; continue;;
    -c) OUTCOLS=$1; shift; continue;;
  esac
done

####
# awk does the work:

awk -v OFLIST="$FIELD_LIST" -v DELIMITER="$DELIMITER" -v SKIP_LINES="$SKIP_LINES
" -v OUTCOLS=$OUTCOLS '

# Process every line after the lines we are supposed to skip:

(NR > SKIP_LINES) {

# Escape any backslashes:

gsub("\\\\","\\\\");

# Line initialization:

FCC=0;  # field character count
FV="";  # field value
IFN=0;  # input field number

# Initialize logical end of record indicator.
# Used in case we have new lines embedded in quoted fields.
END_OF_INPUT="N";

# Keep looping until we have a complete input record
# (could span more than one line of input):

while ( END_OF_INPUT == "N" ) {

# Get rid of CRs:

gsub("^M","");

# Loop through the line character by character:
for (i=1; i<=length($0); i++) {
    FCC++;   # Got another character for the field

    # First character of the field:
    if (FCC == 1) {
        # Initialize the field value to blank:
        FV = "";
        # If we start with a quote, skip it and
        # mark this field as quoted:
        if (substr($0,i,1) == "\"") {
            QUOTED="Y";
            CLOSE_QUOTE="N";  # Keep track if we got the close quote yet
            i++;
        }
        else {
            QUOTED="N"
        }
    }

    # Speical processing for quoted fields:
    if (QUOTED == "Y") {
        # Turn two quotes in to one:
        if (substr($0,i,2) == "\"\"") {
            FV=FV substr($0,i,1);
            i++;
        }
        else {
             # One quote alone is the end of the field:
            if (substr($0,i,1) == "\"") {
                CLOSE_QUOTE="Y";  # Now we have the close quote
                # Increment the field count:
                IFN++;
                # Save the field value:
                IFV[IFN] = FV;
                # Re-initialize for the next field:
                FCC=0;
                # Skip past the coma delimiter, if any:
                if (substr($0,i+1,1) == ",") {
                    i++;
                }
            }
            else {
                # This character is a part of the field value:
                FV = FV substr($0,i,1)
            }
        }
    }
    # Not a quoted field:
    else {
        # Everything but a coma is a part of the field value:
        if (substr($0,i,1) == ","  || i == length($0)) {
            if (substr($0,i,1) != ",") { FV = FV substr($0,i,1) }
            # Increment the field count:
            IFN++;
            # Save the field value:
            IFV[IFN] = FV;
            # Re-initialize for the next field:
            FCC=0;
        }
        else {
            # This character is a part of the field value:
            FV = FV substr($0,i,1)
        }
    }

} # for

# If we end the line with an open quoted field, we have a field with a line brea
k in it.
# Add an escaped new line to the field value, and continue processing with the
# next line:

if (QUOTED == "Y" && CLOSE_QUOTE == "N") {
    FV=FV "\\" "\n";
    getline;
} else {
    END_OF_INPUT="Y"
}

}

# End of the input record reached, output the fields with the specified delimite
r:

OUTCOUNT=0;

if (OFLIST == "") {
    # No output field list specified, output all fields:
    for (i=1; i<=IFN; i++) {
        printf "%s", IFV[i] DELIMITER; OUTCOUNT++
    }
}
else {
    # Output field list was specified, output the specified fields:
    OFN=split(OFLIST,OFA,",");
    for (i=1; i<=OFN; i++) {
        printf "%s", IFV[OFA[i]] DELIMITER; OUTCOUNT++
    }
}

# Fill out to the specified number of output fields:

while (OUTCOUNT < OUTCOLS)
{
    printf "%s", DELIMITER; OUTCOUNT++
}

# End of output line:

print "";

}

'

    