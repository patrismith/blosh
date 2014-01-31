#!/bin/bash

# TODO: forceall appears to be called all the time, what what
# TODO: add something to suppress updating timestamps if post/page is not new
#       when forceall is enabled
# TODO: deal with edge cases
# Search TODO to find more to do

# Folder names
readonly PATH_DRAFT='./draft/'
readonly PATH_LIVE='./live/'
readonly PATH_BLOG='blog/'
readonly PATH_INDEX='index/'
readonly PATH_CSS='css/'
readonly PATH_IMAGES='images/'
readonly PATH_TEMPLATES='templates/'
readonly PATH_HISTORY_PAGE=$PATH_LIVE"history.html"

readonly TEMPLATE_HEADER=$PATH_DRAFT$PATH_TEMPLATES"header.template"
readonly TEMPLATE_BLOGHEADER=$PATH_DRAFT$PATH_TEMPLATES"blogheader.template"
readonly TEMPLATE_TEMPHEADER=$PATH_DRAFT$PATH_TEMPLATES"tempheader.tmp"
readonly TEMPLATE_FOOTER=$PATH_DRAFT$PATH_TEMPLATES"footer.template"
readonly TEMPLATE_HISTORY=$PATH_DRAFT$PATH_TEMPLATES"history.template"

# 'variables' that appear in the html templates.
# Used for inserting times, dates, and links to other posts.
readonly HTML_VAR_TIMESTAMP="varTIMESTAMP"
readonly HTML_VAR_DATESTAMP="varDATESTAMP"
readonly HTML_VAR_OLDER="varOLDER"
readonly HTML_VAR_PREV="varPREVIOUS"
readonly HTML_VAR_NEWER="varNEWER"
readonly HTML_VAR_NEXT="varNEXT"

readonly CKSUM_FILE='.cksum-list'

while getopts fhinuv name
do
    case $name in
        f) forceall=true;;
        h) helpme=true;;
        i) initial=true;;
        n) dryrun=true;;
        u) doupdate=true;;
        v) verbose=true;;
        ?) echo "Try './blo.sh -h' for help."
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
    [[ $verbose ]] && v='v'
    [[ $dryrun ]] && n='n'

    if [ $# -lt 2 ]; then
        error "Needs two params."
        return 1
    fi

    # TODO: -v option contingent on $verbose
    # TODO: --dry-run option enabled with flag
    if [ "$3" ]; then
        rsync -at$v$n --include "*.$3" --exclude "*" "$1" "$2"
        vecho "Synced $3 files of $1 and $2."
    else
        rsync -at$v$n $file_format "$1" "$2"
        vecho "Synced $1 and $2."
    fi
    vecho
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
    # $3 - optional target destination
    local target

    if [ $3 ]; then
        target="$3"
    else
        target="$1"
    fi

    cat $2 $1 > $target.tmp
    mv $target.tmp $target
    vecho "Prepended header to $target"
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
concat_header ()
{
    # $1 - a header template
    # $2 - a blog-specific header addition

    cat $1 $2 > $TEMPLATE_TEMPHEADER
    vecho "Concatenated headers $1 and $2 "
}

# Append header and footer to history page
publish_history ()
{
    prepend_header $1 $2 $PATH_HISTORY_PAGE
}

#assumes local var 'timestamp'
get_timestamp ()
{
    timestamp=$( date "+%B %d %Y" )
}

#assumes local var 'datestamp'
get_datestamp ()
{
    # $1 - a number representing seconds since epoch
    datestamp=$( date --d @$1 "+%B %d %Y")
}

# Replace a specific string in an html file with a 'last modified' timestamp
apply_timestamp ()
{
    # $1 - an html file
    local timestamp

    if [ $1 ]; then
        get_timestamp
        sed "s/$HTML_VAR_TIMESTAMP/$timestamp/" < $1 > $1.tmp
        mv $1.tmp $1
        vecho "Timestamp of $timestamp applied to $1"
        vecho
    fi
}

# Replace a specific string in an html file with a 'date created' timestamp
apply_datestamp ()
{
    # $1 - an html file
    # $2 - a timestamp
    local datestamp

    if [[ $1 && $2 ]]; then
        get_datestamp $2
        sed "s/$HTML_VAR_DATESTAMP/$datestamp/" < $1 > $1.tmp
        mv $1.tmp $1
        vecho "Datestamp of $datestamp applied to $1"
        vecho
    fi
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
        if [[ $forceall || ! $( check_if_file_modified $filename $CKSUM_LIST ) ]]
        then
            vecho "Updating $filename."
            update=true
            md_to_html $filename
            prepend_header $htmlfilename $TEMPLATE_HEADER
            append_footer $htmlfilename $TEMPLATE_FOOTER
            apply_timestamp $htmlfilename
        fi
    done

    if [ $update ]
    then
        my_rsync "$LPATH" "$PATH_LIVE" "html"
        update_cksum "$LPATH" "md" "$CKSUM_LIST"
        vecho "Index files updated."
    else
        vecho "Index files up-to-date."
    fi
    vecho
}

# Gets rid of the hyphens in a filename
# assumes local var 'postname'
get_postname ()
{
    # $1 - a filename with hyphens
    postname=$( echo $1 | tr - ' ' )
}

add_newer_link ()
{
    # $1 - title of a blog entry
    # $2 - filename of a blog entry
    local LPATH=$PATH_DRAFT$PATH_BLOG
    local ABSPATH="/"$PATH_BLOG$1".html"
    local postname

    if [[ $1 && $2 ]]; then
        get_postname $1
        sed 's|'$HTML_VAR_NEWER'|'$ABSPATH'|g' < $LPATH$2 > $LPATH$2.tmp
        sed "s/$HTML_VAR_NEXT/next: $postname/g" < $LPATH$2.tmp > $LPATH$2
        rm $LPATH$2.tmp
    fi
}

add_older_link ()
{
    # $1 - title of a blog entry
    # $2 - filename of a blog entry
    local ABSPATH="/"$PATH_BLOG$2
    local postname

    if [[ $1 && $2 ]]; then
        get_postname $1
        sed 's|'$HTML_VAR_OLDER'|'$ABSPATH'|g' < $htmlfilename > $htmlfilename.tmp
        sed "s/$HTML_VAR_PREV/prev: $postname/g" < $htmlfilename.tmp > $htmlfilename
        rm $htmlfilename.tmp
    fi
}

# strip the timestamp off a filename
# assumes local vars:
# filename - the original timestamped md file
# stripped_filename - the filename without its path
# created_date - the timestamp (seconds since epoch)
# title - the 'title' part of the filename
strip_filename ()
{
    stripped_filename=${filename##*/}
    read created_date title_and_extension <<<$(IFS="_"; echo $stripped_filename)
    read title unused <<<$(IFS="."; echo $title_and_extension)
}

# records history entries in the master tmp file, $TEMPLATE_HISTORY.final.tmp
# assumes local vars:
# datestamp - a blog post's creation date
# title - the post's title
# postname - the post's title sans hyphens
add_history_entry()
{
    sed "s/varDATESTAMP/$datestamp/;s/varTITLE/$title.html/;s/varPOSTNAME/$postname/" < $TEMPLATE_HISTORY > $TEMPLATE_HISTORY.tmp
    cat $TEMPLATE_HISTORY.allentries $TEMPLATE_HISTORY.tmp > $TEMPLATE_HISTORY.allentries.tmp
    cp $TEMPLATE_HISTORY.allentries.tmp $TEMPLATE_HISTORY.allentries
}

clean_history_tmps()
{
    rm $TEMPLATE_HISTORY.tmp $TEMPLATE_HISTORY.allentries.tmp $TEMPLATE_HISTORY.allentries
}

# generate a page listing all blog posts in reverse chronological order
update_history ()
{
    local stripped_filename
    local created_date
    local title
    local postname
    local datestamp

    # to suppress cat error message when add_history_entry is first called
    touch $TEMPLATE_HISTORY.allentries

    for filename in $( find draft/blog -type f -name "*.md" | sort -r )
    do
        vecho "Generating history entry for $filename..."
        strip_filename
        get_postname $title
        get_datestamp $created_date
        add_history_entry
    done

    # uses prepend_header function, but notice that it is moved directly to live here.
    # since the html is generated directly, and not from a markdown file,
    # it doesn't fit neatly with the operations of the index or blog folders.
    prepend_header $TEMPLATE_HISTORY.allentries $TEMPLATE_HEADER $PATH_HISTORY_PAGE
    append_footer $PATH_HISTORY_PAGE $TEMPLATE_FOOTER
    apply_timestamp $PATH_HISTORY_PAGE
    clean_history_tmps
    vecho "History page saved to $PATH_HISTORY_PAGE."
    vecho
}

update_blog ()
{
    local LPATH=$PATH_DRAFT$PATH_BLOG
    local CKSUM_LIST=$LPATH$CKSUM_FILE
    local htmlfilename
    local update
    local stripped_filename
    local created_date
    local title

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

        # Strip timestamp from filename and set title for the next file to use
        strip_filename

        if [[ $forceall || ! $( check_if_file_modified $filename $CKSUM_LIST ) ]]
        then
            vecho "Updating $filename."
            update=true
            md_to_html $filename
            concat_header $TEMPLATE_HEADER $TEMPLATE_BLOGHEADER
            prepend_header $htmlfilename $TEMPLATE_TEMPHEADER
            rm $TEMPLATE_TEMPHEADER
            append_footer $htmlfilename $TEMPLATE_FOOTER
            apply_timestamp $htmlfilename
            apply_datestamp $htmlfilename $created_date

            if [ $prev_filename ]
            then
                add_newer_link $title $prev_filename
                add_older_link $prev_title $prev_filename
                mv $htmlfilename $LPATH$title.html
            else
                # a blank 'previous' link
                sed "s/$HTML_VAR_OLDER//;s/$HTML_VAR_PREV//" < $htmlfilename > $htmlfilename.tmp
                mv $htmlfilename.tmp $LPATH$title.html
                rm $htmlfilename
            fi
            prev_title=$title
            final_post=$title.html
        fi
    done

    if [ $final_post ]; then
        # a blank 'next' link
        sed "s/$HTML_VAR_NEWER//;s/$HTML_VAR_NEXT//" < $LPATH$final_post > $LPATH$final_post.tmp
        mv $LPATH$final_post.tmp $LPATH$final_post
        # copy last blog post to the index.html for the site
        cp $LPATH$final_post $PATH_LIVE"index.html"
    fi

    if [ $update ]
    then
        my_rsync "$LPATH" "$PATH_LIVE$PATH_BLOG" "html"
        update_cksum "$LPATH" "md" "$CKSUM_LIST"
        update_history
        vecho "Blog updated."
    else
        vecho "Blog up-to-date."
    fi
    vecho
}

usage ()
{
    echo "Usage: ./blo.sh [OPTION]"
    echo "A bash blog script."
    echo
    echo "-f            force update of all files"
    echo "-h            display this help"
    echo "-i            create necessary directories if they don't already exist"
    echo "-n            dry-run (no changes made)"
    echo "-u            selectively update new and changed files"
    echo "-v            verbose output"
    echo
    echo "Complete help available at <http://github.com/patrismith/blosh>"
}

if [[ $helpme ]]; then
    usage
elif [[ $initial ]]; then
    mkdir -p $PATH_DRAFT/{$PATH_BLOG,$PATH_INDEX,$PATH_CSS,$PATH_TEMPLATES,$PATH_IMAGES}
    mkdir -p $PATH_LIVE/{$PATH_BLOG,$PATH_IMAGES}
elif [[ $doupdate || $forceall ]]; then
    update_index
    update_blog
    update_css
    update_images
else
    echo "Try './blo.sh -h' for help."
fi
