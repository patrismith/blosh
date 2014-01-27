#!/bin/bash

CKSUM='.cksum-list'

# Make list of files to update
# cksum each file, compare to .cksum-list

# First, make sure all the posts are timestamped
# If one isn't, prepend a timestamp based on the modification date
# (we're using seconds since epoch)
# This becomes the post date!
for filename in $( find draft/blog -type f -name "*.md" | sort )
do
    # if file doesn't start with a timestamp (or 5+ digits), prepend a timestamp to its name
    if [[ ! $filename =~ [0-9][0-9][0-9][0-9][0-9].*_.*.md$ ]]
    then
        mv $filename draft/blog/$( stat -c %Y $filename )_${filename##*/}
    fi
done


for filename in $( find draft/blog -type f -name "*.md" | sort )
do
    newsum="`cksum $filename`"
    # find the ones with a differing checksum
    if ! grep -q "$newsum" $CKSUM
    then
        forcefile=true
    else
        forcefile=false
    fi

    if [ $forcefile ]
    then
        # Strip timestamp from filename
        combined=${filename##*/}
        read timestamp title <<<$(IFS="_"; echo $combined)
        echo "timestamp: $timestamp"
        echo "title: $title"
        echo "combined: $combined"
        echo "filename: $filename"

        # Convert markdown to html
        read title unused<<<$(IFS="."; echo $title)
        echo "title: $title"
        newfilename=draft/blog/$title.html
        echo "newfilename: $newfilename"
        markdown $filename > $newfilename

        # Prepend header
        # this goes to a header creation script
        cat draft/templates/header.template $newfilename > $newfilename.tmp
        mv $newfilename.tmp $newfilename

        # Append footer
        # this goes to a footer creation script
        cat draft/templates/footer.template >> $newfilename

        # Replace varTIMESTAMP in file with actual timestamp
        timestamp="`date \"+%B %d %Y\"`"

        sed "s/varTIMESTAMP/$timestamp/" < $newfilename > $newfilename.tmp
        mv $newfilename.tmp $newfilename
        echo "Added on $timestamp."
    fi
done

# rsync html files to live
rsync -at --include '*.html' --exclude '*' draft/blog/ live/blog/

# update .cksum-list
#find draft/blog -type f -name "*.md" -exec cksum {} + > $CKSUM
