#!/bin/bash

CKSUM='.cksum-list'

# Make list of files to update
# cksum each file, compare to .cksum-list
for filename in $( find draft/single -type f -name "*.md" | sort )
do
    # if file doesn't start with a timestamp, prepend a timestamp to its name
    if [ "filename doesn't start with timestamp regex, basically a string of numbers > 5 length" ]
    then
        #cp file to "date +%s file.md"
        #delete old file
    fi
done

for filename in $( find draft/single -type f -name "*.md" | sort )
do
    newsum="`cksum $filename`"
    # find the ones with a differing checksum
    if ! grep -q "$newsum" $CKSUM
    then
        # Strip timestamp from filename

        # Convert markdown to html

        # Prepend header
        # this goes to a header creation script

        # Append footer
        # this goes to a footer creation script
    fi
done

# rsync html files to live

# update .cksum-list
find draft/single -type f -name "*.md" -exec cksum {} + > $CKSUM
