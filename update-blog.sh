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
    # if title already exists, then there is a previous file to link to
    if [ $title ]
    then
        previousfile="$title".html
    fi

    # Strip timestamp from filename
    combined=${filename##*/}
    # set title for the next file to use
    read createddate title <<<$(IFS="_"; echo $combined)
    read title unused<<<$(IFS="."; echo $title)

    newsum="`cksum $filename`"
    # find the ones with a differing checksum
    if ! grep -q "$newsum" $CKSUM
    then
        forcefile=true
    else
        forcefile=false
    fi

    # if blogpost has been modified or is new
    if [ $forcefile ]
    then

        # Convert markdown to html
        newfilename=draft/blog/$title.html
        markdown $filename > $newfilename

        # Append blogheader to header
        cat draft/templates/header.template draft/templates/blogheader.template > draft/templates/temp.template

        # Prepend header
        # this goes to a header creation script
        cat draft/templates/temp.template $newfilename > $newfilename.tmp
        mv $newfilename.tmp $newfilename

        # Append footer
        # this goes to a footer creation script
        cat draft/templates/footer.template >> $newfilename

        # Replace varTIMESTAMP in file with actual timestamp
        timestamp=$( date "+%B %d %Y" )
        datestamp=$( date --d @$createddate "+%B %d %Y")

        sed "s/varTIMESTAMP/$timestamp/;s/varDATESTAMP/$datestamp/" < $newfilename > $newfilename.tmp
        mv $newfilename.tmp $newfilename
        if [ $previousfile ]
        then
            postname=$( echo $title | tr - ' ' )
            sed "s/varNEWER/$title.html/;s/varNEXT/next: $postname/" < draft/blog/$previousfile > draft/blog/$previousfile.tmp
            mv draft/blog/$previousfile.tmp draft/blog/$previousfile

            postname=$( echo $previoustitle | tr - ' ' )
            sed "s/varOLDER/$previousfile/;s/varPREVIOUS/prev: $postname/" < $newfilename > $newfilename.tmp
        else
            sed "s/varOLDER//;s/varPREVIOUS//" < $newfilename > $newfilename.tmp
        fi
        mv $newfilename.tmp $newfilename
        lastpost=$title.html
        previoustitle=$title
    fi
done

sed "s/varNEWER//;s/varNEXT//" < draft/blog/$lastpost > draft/blog/$lastpost.tmp
mv draft/blog/$lastpost.tmp draft/blog/$lastpost

# rsync html files to live
rsync -at --include '*.html' --exclude '*' draft/blog/ live/blog/

# update .cksum-list
#find draft/blog -type f -name "*.md" -exec cksum {} + > $CKSUM
