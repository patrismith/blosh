#!/bin/bash

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
readonly HTML_VAR_PREVVISIBLE="varPVISIBLE"
readonly HTML_VAR_PREVINVISIBLE="varPINVISIBLE"
readonly HTML_VAR_NEXTVISIBLE="varNVISIBLE"
readonly HTML_VAR_NEXTINVISIBLE="varNINVISIBLE"

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

# errors are echoed to stderr
error ()
{
    echo "$@" >&2
}

# echo a message if verbose flag is set
vecho ()
{
    [ "$verbose" ] && echo "$@"
}

# rsync with -at and easy --include, --exclude options
my_rsync ()
{
    # $1 - path to source folder
    # $2 - path to destination folder
    # $3 - optional extension to include (exclude everything else)
    [[ "$verbose" ]] && v='v'
    [[ "$dryrun" ]] && n='n'

    if [ $# -lt 2 ]; then
        error "Needs two params."
        return 1
    fi

    # TODO: -v option contingent on $verbose
    # TODO: --dry-run option enabled with flag
    if [ "$3" ]; then
        rsync -at"$v$n" --include "*.$3" --exclude "*" "$1" "$2"
        vecho "Synced $3 files of $1 and $2."
    else
        rsync -at"$v$n" "$file_format" "$1" "$2"
        vecho "Synced $1 and $2."
    fi
    vecho
    return 0
}

# try to find a file's checksum in a list of checksums
check_if_file_modified ()
{
    # $1 - filename w/ path
    # $2 - a file containing the output of update_cksum
    local newsum=$( cksum "$1" )
    local oldsum=$( grep "$newsum" "$2" )

    if [ ! "-f $2" ]
    then
        vecho "No checksum list found."
        return 0
    elif [[ ! "$oldsum" ]]
    then
        vecho "$1: File's checksum doesn't match (or file not found in list)"
        return 0
    else
        vecho "$1: Checksum matches."
        return 1
    fi
}

# Get the checksums of all files in a folder, and save the results in a file
update_cksum ()
{
    # $1 - path to folder
    # $2 - extension to check
    # $3 - path to store the list

    find "$1" -type f -name "*.$2" -exec cksum {} + > "$3"
}

# Sync draft and live css files
update_css ()
{
    my_rsync "$PATH_DRAFT$PATH_CSS" "$PATH_LIVE" 'css'
    if [ $? -eq 1 ] ; then
        error "Rsync failed for css."
    fi
}

# Sync draft and live image folders
update_images ()
{
    my_rsync "$PATH_DRAFT$PATH_IMAGES" "$PATH_LIVE$PATH_IMAGES" 'png'
    if [ $? -eq 1 ] ; then
        error "Rsync failed for images."
    fi
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
    datestamp=$( date --d @"$1" "+%B %d %Y")
}

# Replace a specific string in an html file with a 'last modified' timestamp
apply_timestamp ()
{
    # $1 - an html file
    local timestamp

    if [ "$1" ]; then
        get_timestamp
        sed "s/$HTML_VAR_TIMESTAMP/$timestamp/" < "$1" > "$1.tmp"
        mv "$1.tmp" "$1"
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

    if [[ "$1" && "$2" ]]; then
        get_datestamp "$2"
        sed "s/$HTML_VAR_DATESTAMP/$datestamp/" < "$1" > "$1.tmp"
        mv "$1.tmp" "$1"
        vecho "Datestamp of $datestamp applied to $1"
        vecho
    fi
}

update_index ()
{
    local LPATH="$PATH_DRAFT$PATH_INDEX"
    local CKSUM_LIST="$LPATH$CKSUM_FILE"
    local htmlfilename
    local update
    local modified
    local filename

    for filename in $( find "$LPATH" -type f -name "*.md" | sort )
    do
        check_if_file_modified "$filename" "$CKSUM_LIST"
        modified="$?"
        if [ "$forceall" ] || [ "$modified" -eq 0 ]
        then
            vecho "Updating $filename."
            update=true
            htmlfilename="${filename%.md}.html"
            markdown "$filename" > "$htmlfilename"
            cat "$TEMPLATE_HEADER" "$htmlfilename" > "$htmlfilename.tmp"
            cat "$TEMPLATE_FOOTER" >> "$htmlfilename.tmp"
            mv "$htmlfilename.tmp" "$htmlfilename"
            apply_timestamp "$htmlfilename"
        fi
    done

    my_rsync "$LPATH" "$PATH_LIVE" "html"

    if [ "$update" ]
    then
        update_cksum "$LPATH" "md" "$CKSUM_LIST"
        vecho "Index files updated."
    else
        vecho "Index files up-to-date."
    fi
    vecho
}

# rename a blog post with the date of its first being processed by this script
# (i.e. post date)
date_post ()
{
    if [[ ! "$1" =~ [0-9][0-9][0-9][0-9][0-9].*_.*.md$ ]]
    then
        mv "$1" "$PATH_DRAFT$PATH_BLOG$( stat -c %Y $1 )_${1##*/}"
    fi
}

update_history ()
{
    local stripped_filename
    local created_date
    local title
    local postname
    local datestamp

    # to suppress cat error message when add_history_entry is first called
    touch "$TEMPLATE_HISTORY.allentries"

    for filename in $( find draft/blog -type f -name "*.md" | sort -r )
    do
        vecho "Generating history entry for $filename..."
        stripped_filename="${filename##*/}"
        read created_date title_and_extension <<<$(IFS="_"; echo $stripped_filename)
        read title unused <<<$(IFS="."; echo $title_and_extension)
        postname=$( echo "$title" | tr - ' ' )
        get_datestamp "$created_date"
        sed "s/varDATESTAMP/$datestamp/;s/varTITLE/$title.html/;s/varPOSTNAME/$postname/" < "$TEMPLATE_HISTORY" > "$TEMPLATE_HISTORY.tmp"
        cat "$TEMPLATE_HISTORY.allentries" "$TEMPLATE_HISTORY.tmp" > "$TEMPLATE_HISTORY.allentries.tmp"
        cp "$TEMPLATE_HISTORY.allentries.tmp" "$TEMPLATE_HISTORY.allentries"
    done

    # uses prepend_header function, but notice that it is moved directly to live here.
    # since the html is generated directly, and not from a markdown file,
    # it doesn't fit neatly with the operations of the index or blog folders.
    cat "$TEMPLATE_HEADER" "$TEMPLATE_HISTORY.allentries" > "$PATH_HISTORY_PAGE"
    cat "$TEMPLATE_FOOTER" >> "$PATH_HISTORY_PAGE"
    apply_timestamp "$PATH_HISTORY_PAGE"
    rm -f "$TEMPLATE_HISTORY.tmp" "$TEMPLATE_HISTORY.allentries.tmp" "$TEMPLATE_HISTORY.allentries" "$PATH_DRAFT$PATH_BLOG.tmp"
    vecho "History page saved to $PATH_HISTORY_PAGE."
    vecho
}

update_blog ()
{
    local LPATH=$PATH_DRAFT$PATH_BLOG
    local CKSUM_LIST=$LPATH$CKSUM_FILE
    local filename
    local update

    # make sure all the markdown files that don't have dates are given dates now
    for filename in $( find "$LPATH" -type f -name "*.md" | sort )
    do
        date_post "$filename"
    done

    for filename in $( find "$LPATH" -type f -name "*.md" | sort )
    do
        local modified
        local pathless_filename
        local created_date
        local title
        local unused
        local prev_filename=""
        local next_filename=""
        local save_timestamp
        local neighborfile

        vecho "Updating $filename."
        update=true

        pathless_filename="${filename##*/}"
        read created_date title_and_extension <<<$(IFS="_"; echo $pathless_filename)
        read title unused <<<$(IFS="."; echo $title_and_extension)

        check_if_file_modified "$filename" "$CKSUM_LIST"
        modified="$?"

        markdown "$filename" > "$LPATH$title.html"

        cat "$TEMPLATE_HEADER" "$TEMPLATE_BLOGHEADER" > "$TEMPLATE_TEMPHEADER"
        cat "$TEMPLATE_TEMPHEADER" "$LPATH$title.html" > "$LPATH$title.html.tmp"
        rm -f "$TEMPLATE_TEMPHEADER"
        cat "$TEMPLATE_FOOTER" >> "$LPATH$title.html.tmp"
        mv "$LPATH$title.html.tmp" "$LPATH$title.html"

        if [ "$modified" -eq 0 ]
        then
            apply_timestamp "$LPATH$title.html"
        else
            # change to grep timestamp from the live version and push it
            save_timestamp=$( grep "Page updated on" "$PATH_LIVE$PATH_BLOG$title.html" | sed "s/Page updated on //;s/.<.h6>//;s/<h6>//g" )
            sed "s/$HTML_VAR_TIMESTAMP/$save_timestamp/" < "$LPATH$title.html" > "$LPATH$title.html.tmp"
            mv "$LPATH$title.html.tmp" "$LPATH$title.html"
            vecho "Timestamp of $save_timestamp applied to $LPATH$title.html"
            vecho
        fi
        apply_datestamp "$LPATH$title.html" "$created_date"

        # get previous file
        for neighborfile in $( find "$LPATH" -type f -name "*.md" | sort | grep -B 1 "$filename" | sed "s|^.*$filename||g" )
        do
            echo "found $neighborfile"
            unused_filename="${neighborfile##*/}"
            read unused unused2 <<<$(IFS="_"; echo $unused_filename)
            read prev_filename unused <<<$(IFS="."; echo $unused2)
        done

        # get next file
        for neighborfile in $( find "$LPATH" -type f -name "*.md" | sort | grep -A 1 "$filename" | sed "s|^.*$filename||g" )
        do
            echo "found $neighborfile"
            unused_filename="${neighborfile##*/}"
            read unused unused2 <<<$(IFS="_"; echo $unused_filename)
            read next_filename unused <<<$(IFS="."; echo $unused2)
        done

        echo "For $filename, $prev_filename and $next_filename are the links"

        if [[ "$prev_filename" != "" ]]
        then
            #add link to previous blogpost
            local ABSPATH="/$PATH_BLOG$prev_filename.html"
            local postname=$( echo $prev_filename | tr - ' ' )

            sed 's|'"$HTML_VAR_OLDER"'|'"$ABSPATH"'|g' < "$LPATH$title.html" > "$LPATH$title.html.tmp"
            sed "s/$HTML_VAR_PREV/prev: $postname/;s/$HTML_VAR_PREVINVISIBLE/$HTML_VAR_PREVVISIBLE/g" < "$LPATH$title.html.tmp" > "$LPATH$title.html"
        else
            #an invisible 'previous' link
            sed "s/$HTML_VAR_PREVVISIBLE/$HTML_VAR_PREVINVISIBLE/g" < "$LPATH$title.html" > "$LPATH$title.html.tmp"
            mv "$LPATH$title.html.tmp" "$LPATH$title.html"
        fi

        if [[ "$next_filename" != "" ]]
        then
            #add link to next blogpost
            local ABSPATH="/$PATH_BLOG$next_filename.html"
            local postname=$( echo $next_filename | tr - ' ' )

            sed 's|'"$HTML_VAR_NEWER"'|'"$ABSPATH"'|g' < "$LPATH$title.html" > "$LPATH$title.html.tmp"
            sed "s/$HTML_VAR_NEXT/next: $postname/;s/$HTML_VAR_NEXTINVISIBLE/$HTML_VAR_NEXTVISIBLE/g" < "$LPATH$title.html.tmp" > "$LPATH$title.html"
        else
            #an invisible 'previous' link
            sed "s/$HTML_VAR_NEXTVISIBLE/$HTML_VAR_NEXTINVISIBLE/g" < "$LPATH$title.html" > "$LPATH$title.html.tmp"
            mv "$LPATH$title.html.tmp" "$LPATH$title.html"
        fi

        final_post="$title.html"

    done

    my_rsync "$LPATH" "$PATH_LIVE$PATH_BLOG" "html"
    update_history
    cp "$LPATH$final_post" "$PATH_LIVE""index.html"

    if [ "$update" ]
    then
        update_cksum "$LPATH" "md" "$CKSUM_LIST"
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
    touch $TEMPLATE_HEADER $TEMPLATE_BLOGHEADER $TEMPLATE_FOOTER $TEMPLATE_HISTORY
elif [[ $doupdate || $forceall ]]; then
    #update_index
    update_blog
    #update_css
    #update_images
else
    echo "Try './blo.sh -h' for help."
fi
