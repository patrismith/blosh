#!/bin/bash

# TODO: add something to suppress updating timestamps if post/page is not new
# Search TODO to find more to do

# Folder names
# It's a little awkward with the slashes and dots, should change that
PATH_DRAFT='./draft/'
PATH_LIVE='./live/'
PATH_BLOG='blog/'
PATH_INDEX='index/'
PATH_CSS='css/'
PATH_IMAGES='images/'
PATH_TEMPLATES='templates/'

HEADER=$PATH_DRAFT$PATH_TEMPLATES"header.template"
BLOGHEADER=$PATH_DRAFT$PATH_TEMPLATES"blogheader.template"
TEMPHEADER=$PATH_DRAFT$PATH_TEMPLATES"tempheader.template"
FOOTER=$PATH_DRAFT$PATH_TEMPLATES"footer.template"

# 'variables' that appear in the html templates.
# Used for inserting times, dates, and links to other posts.
HTML_VAR_TIMESTAMP="varTIMESTAMP"
HTML_VAR_DATESTAMP="varDATESTAMP"
HTML_VAR_OLDER="varOLDER"
HTML_VAR_PREV="varPREVIOUS"
HTML_VAR_NEWER="varNEWER"
HTML_VAR_NEXT="varNEXT"

CKSUM_FILE='.cksum-list'

while getopts fv name
do
    case $name in
        f) forceall=true;;
        v) verbose=true;;
        ?) echo "Usage: hahahaha"
        exit 2;;
    esac
done

# errors just get echoed to stderr
error ()
{
    echo "$@" >&2
}

# echo a message if verbose flag is set
vecho ()
{
    [ $verbose ] && echo "$@"
}

# rsync with -at and easy --include, --exclude options
my_rsync ()
{
    # $1 - source folder
    # $2 - destination folder
    # $3 - optional extension to include (exclude everything else)

    echo "$1 $2 $3"

    if [ $# -lt 2 ]; then
        error "Needs two params."
        return 1
    fi

    # TODO: -v option contingent on $verbose
    # TODO: --dry-run option enabled with flag
    if [ "$3" ]; then
        rsync -atv --include "*.$3" --exclude "*" "$1" "$2"
        vecho "Synced $3 files of $1 and $2."
    else
        rsync -atv $file_format "$1" "$2"
        vecho "Synced $1 and $2."
    fi
    return 0
}

# try to find a file's checksum in a list of checksums
check_if_file_modified ()
{
    # $1 - filename
    # $2 - checksum list

    newsum=$( cksum $1 )

    # combine the next two conditions ARRGGGHH
    if [ ! -f $2 ]
    then
        vecho "No checksum list found."
        return 1
    elif [ ! $( grep -q "$newsum" $2 ) ]
    then
        vecho "File's checksum doesn't match (or file not found in list)"
        return 1
    else
        return 0
    fi
}

# Get the checksums of all files in a folder,
# saving the results in a file
update_cksum ()
{
    # $1 - path to folder
    # $2 - extension to check
    # $3 - path to store the list

    find $1 -type f -name "*.$2" -exec cksum {} + > $3
}

generate_post_history ()
{
    echo
}

# Sync draft and live css files
update_css ()
{
    my_rsync $PATH_DRAFT$PATH_CSS $PATH_LIVE 'css'
    if [ $? -eq 1 ] ; then
        error "Rsync failed for css."
    fi
}

# Sync draft and live image folders
update_images ()
{
    my_rsync $PATH_DRAFT$PATH_IMAGES $PATH_LIVE$PATH_IMAGES
    if [ $? -eq 1 ] ; then
        error "Rsync failed for images."
    fi
}

# convert a markdown file to html
# assumes an empty local var named "htmlfilename" in the parent function <:(
# this is so htmlfilename can be used by that parent function.
# There's probably a better way!
md_to_html ()
{
    # $1 - a markdown file

    htmlfilename="${1%.md}".html

    markdown $1 > $htmlfilename
    vecho "Converted $1 to $htmlfilename."
}

# Add a header file to the beginning of an html file
prepend_header ()
{
    # $1 - an html file
    # $2 - a header template

    cat $2 $1 > $1.tmp
    mv $1.tmp $1
    vecho "Prepended header to $1"
}

# Add a footer file to the end of an html file
append_footer ()
{
    # $1 - an html file
    # $2 - a footer template

    cat $2 >> $1
    vecho "Appended footer to $1"
}

# Add a blog-specific header to a header file to create a new temporary template
create_blog_header ()
{
    # $1 - a header template
    # $2 - a blog-specific header addition

    cat $1 $2 > $TEMPHEADER
}

# Replace a specific string in an html file with a 'last modified' timestamp
apply_timestamp ()
{
    # $1 - an html file
    local timestamp=$( date "+%B %d %Y" )

    sed "s/$HTML_VAR_TIMESTAMP/$timestamp/" < $1 > $1.tmp
    mv $1.tmp $1
    vecho "Timestamp of $timestamp applied to $1"
}

# Replace a specific string in an html file with a 'date created' timestamp
apply_datestamp ()
{
    # $1 - an html file
    # $2 - a timestamp
    local datestamp=$( date --d @$2 "+%B %d %Y")

    sed "s/$HTML_VAR_DATESTAMP/$datestamp/" < $1 > $1.tmp
    mv $1.tmp $1
    vecho "Datestamp of $datestamp applied to $1"
}

# rename a blog post with the date of its first being processed by this script
# (i.e. post date)
date_post ()
{
    if [[ ! $1 =~ [0-9][0-9][0-9][0-9][0-9].*_.*.md$ ]]
    then
        mv $1 draft/blog/$( stat -c %Y $1 )_${1##*/}
    fi
}

# is there a way to make this and update_blag be the same?
update_index ()
{
    local LPATH=$PATH_DRAFT$PATH_INDEX
    local CKSUM_LIST=$LPATH$CKSUM_FILE
    local htmlfilename
    local update

    for filename in $( find $LPATH -type f -name "*.md" | sort )
    do
        if [[ $forceall || $( check_if_file_modified $filename $CKSUM_LIST ) ]]
        then
            vecho "---Updating $filename."
            update=true
            md_to_html $filename
            prepend_header $htmlfilename $HEADER
            append_footer $htmlfilename $FOOTER
            apply_timestamp $htmlfilename
        fi
    done

    if [ $update ]
    then
        my_rsync "$LPATH" "$PATH_LIVE" "html"
        update_cksum "$LPATH" "md" "$CKSUM_LIST"
    fi
}

add_newer_link ()
{
    # $1 - title of a blog entry
    # $2 - filename of a blog entry
    local LPATH=$PATH_DRAFT$PATH_BLOG
    local postname=$( echo $1 | tr - ' ' )
    sed "s/$HTML_VAR_NEWER/$1.html/;s/$HTML_VAR_NEXT/next: $postname/" < $LPATH$2 > $LPATH$2.tmp
    mv $LPATH$2.tmp $LPATH$2
}

add_older_link ()
{
    # $1 - title of a blog entry
    # $2 - filename of a blog entry
    local postname=$( echo $1 | tr - ' ' )
    sed "s/$HTML_VAR_OLDER/$2/;s/$HTML_VAR_PREV/prev: $postname/" < $htmlfilename > $htmlfilename.tmp
}

update_blog ()
{
    local LPATH=$PATH_DRAFT$PATH_BLOG
    local CKSUM_LIST=$LPATH$CKSUM_FILE
    local htmlfilename
    local update

    # make sure all the markdown files that don't have dates are given dates now
    for filename in $( find $LPATH -type f -name "*.md" | sort )
    do
        date_post $filename
    done

    # really gotta resort???
    for filename in $( find $LPATH -type f -name "*.md" | sort )
    do
        # if title already exists, then there is a previous file to link to
        [ $title ] && prev_filename="$title".html

        # Strip timestamp from filename
        stripped_filename=${filename##*/}
        # set title for the next file to use
        read created_date title_and_extension <<<$(IFS="_"; echo $stripped_filename)
        read title unused <<<$(IFS="."; echo $title_and_extension)

        if [[ $forceall || $( check_if_file_modified $filename $CKSUM_LIST ) ]]
        then
            vecho "---Updating $filename."
            update=true
            md_to_html $filename
            create_blog_header $HEADER $BLOGHEADER
            prepend_header $htmlfilename $TEMPHEADER
            rm $TEMPHEADER
            append_footer $htmlfilename $FOOTER
            apply_timestamp $htmlfilename
            apply_datestamp $htmlfilename $created_date

            # clean this mess up
            if [ $prev_filename ]
            then
                add_newer_link $title $prev_filename
                add_older_link $prev_title $prev_filename
            else
                # a blank 'previous' link
                sed "s/$HTML_VAR_OLDER//;s/$HTML_VAR_PREV//" < $htmlfilename > $htmlfilename.tmp
            fi
            mv $htmlfilename.tmp $LPATH$title.html
            rm $htmlfilename
            prev_title=$title
            final_post=$title.html
        fi
    done

    # a blank 'next' link
    sed "s/$HTML_VAR_NEWER//;s/$HTML_VAR_NEXT//" < $LPATH$final_post > $LPATH$final_post.tmp
    mv $LPATH$final_post.tmp $LPATH$final_post

    if [ $update ]
    then
        my_rsync "$LPATH" "$PATH_LIVE$PATH_BLOG" "html"
        update_cksum "$LPATH" "md" "$CKSUM_LIST"
    fi
}


update_index
update_blog
update_css
update_images
