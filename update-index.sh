#!/bin/bash

while getopts fv name
do
    case $name in
        f) forceall=true;;
        v) verbose=true;;
        ?) echo "Usage: ha ha"
            exit 2;;
    esac
done



CKSUM='draft/index/.cksum-list'

for filename in $( find draft/index -type f -name "*.md" | sort )
do
    newsum="`cksum $filename`"
    if ! grep -q "$newsum" $CKSUM
    then
        forcefile=true
    else
        forcefile=false
    fi

    # find the ones with a differing checksum
    if [ $forceall -o $forcefile ]
    then
        if [ $verbose ]
        then
            echo "Updating $filename."
        fi
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
        if [ $verbose ]
        then
            echo "Added on $timestamp."
        fi
    fi
done

if [ $forceall -o $forcefile ]
then
    # rsync html files to live
    rsync -at --include '*.html' --exclude '*' draft/index/ live/

    # update .cksum-list
    find draft/index -type f -name "*.md" -exec cksum {} + > $CKSUM
    if [ $verbose ]
    then
        echo "Updated html and checksums."
    fi
fi

exit 0
