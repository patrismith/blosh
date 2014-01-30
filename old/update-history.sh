#!/bin/bash

# Generate new history file with links to blog posts in reverse chronological order.

echo "entering loop"
# Get sorted list of .md files in draft/blog
for filename in $( find draft/blog -type f -name "*.md" | sort -r )
do
    echo "$filename"
    # strip number and convert it to date
    combined=${filename##*/}
    read createddate title <<<$(IFS="_"; echo $combined)
    read title unused<<<$(IFS="."; echo $title)
    postname=$( echo $title | tr - ' ' )
    datestamp=$( date --d @$createddate "+%B %d %Y")

    echo "trying to sed"

    # create html string of date, pretty filename, link to actual filename (use template?)
    sed "s/varDATESTAMP/$datestamp/;s/varTITLE/$title.html/;s/varPOSTNAME/$postname/" < draft/templates/history.template > draft/templates/tempnew.template


    # cat to tempfile, appending if already exists
    cat draft/templates/tempfinal.template draft/templates/tempnew.template > draft/templates/temp.template

    cp draft/templates/temp.template draft/templates/tempfinal.template

done

echo "loop over"
# at end, append header and footer
cat draft/templates/header.template draft/templates/tempfinal.template > draft/templates/temp.template

mv draft/templates/temp.template live/blog/index.html

cat draft/templates/footer.template >> live/blog/index.html

rm draft/templates/temp.template
rm draft/templates/tempnew.template
rm draft/templates/tempfinal.template

# save to blog/index.html
