#!/bin/bash

CKSUM='draft/index/.cksum-list'

for filename in $( find draft/index -type f -name "*.md" | sort )
do
    newsum="`cksum $filename`"
    # find the ones with a differing checksum
    if ! grep -q "$newsum" $CKSUM
    then
        # Convert markdown to html
        newfilename="${filename%.md}".html
        markdown $filename > $newfilename

        # Prepend header
        # this could go to a header creation script
        cat draft/templates/header.template $newfilename > $newfilename.tmp
        mv $newfilename.tmp $newfilename

        # Append footer
        # this could go to a footer creation script
        cat draft/templates/footer.template >> $newfilename

        timestamp="`date \"+%B %d %Y\"`"

        sed "s/varTIMESTAMP/$timestamp/" < $newfilename > $newfilename.tmp
        mv $newfilename.tmp $newfilename
    fi
done

# rsync html files to live
rsync -at --include '*.html' --exclude '*' draft/index/ live/

# update .cksum-list
find draft/index -type f -name "*.md" -exec cksum {} + > $CKSUM
