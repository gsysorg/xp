#!/bin/bash

if [ -v DEBUG ]; then
    set -x
fi;

SHORT=n
IGNORE_CASE=n
REGEXP=n
THIS_MODE=n
MATCHING=()
XBPS_QUERY_FLAGS=('-R')

# extra flags
GREP_FLAGS=()
XBPS_FLAGS=()

print_help() {
    local arg0=$(basename $0)
    echo xbps-q: better wrapper for xbps-query
    echo "Usage: $arg0 [flags...] <matches...>"
    echo "       $arg0 [flags...] -T <package>"
    echo Options:
    echo '   -h (--help)               Display a help message'
    echo '   -P (--flag) <FLAG>        Pass a flag FLAG to xbps-query'
    echo '   -R (--regex, --regexp)    Search by regexp'
    echo '   -i                        Ignore case when searching'
    echo '   -N (--only-names,         Display only names of packages'
    echo '       --short)'
    echo '   -T (--this)               Display info for a single specific package'
    echo '                              (conflicts with some options)'
    echo '  --installed                Display only installed packages'
    echo '                              (conflicts with --not-installed)'
    echo '  --not-installed            Display only not installed packages'
    echo '                              (conflicts with --installed)'
}

error() {
    echo $(basename $0): $@
    exit 1
}

# Parse CLI options
parse_cli() {
    while :; do
        if [ -z $1 ]; then break; fi;
        case "$1" in
            '-h'|'--help')
                print_help
                exit 0
                ;;
            '-P'|'--flag')
                [ -z $2 ] && error "No flag specified to $1"
                XBPS_USER_FLAGS+=($2)
                shift # skip the passed flag itself
                shift
                ;;
            '-R'|'--regex'|'--regexp')
                XBPS_USER_FLAGS+=("--regex")
                REGEXP=y
                shift
                ;;
            '-i')
                IGNORE_CASE=y
                shift
                ;;
            '-T'|'--this')
                THIS_MODE=y
                shift
                ;;
            '-N'|'--short'|'--only-names')
                PP_FILTERS="S$PP_FILTERS"
                shift
                ;;
            '--installed')
                if [[ $PP_FILTERS == *N* ]]; then
                    error "Conflicting arguments: $1 and --not-installed"
                fi
                PP_FILTERS="I$PP_FILTERS"
                shift
                ;;
            '--not-installed')
                if [[ $PP_FILTERS == *I* ]]; then
                    error "Conflicting arguments: $1 and --installed"
                fi
                PP_FILTERS="N$PP_FILTERS"
                shift
                ;;
            -*) # match unknown flag options
                echo Unrecognized option: $1
                print_help
                exit 1
                ;;
            *) # add things to match into the array
                MATCHING+=($1)
                shift
        esac
    done

    XBPS_FLAGS+=($XBPS_USER_FLAGS)

    if [ $THIS_MODE == y ]; then
        # cannot query for a single package with regexp
        if [ $REGEXP = y ]; then
            error "Cannot use '--this' flag with '--regexp'"
        elif [[ $PP_FILTERS == *I* ]] || [[ $PP_FILTERS == *N* ]]; then
            error "Cannot use '--this' flag with '--[not-]installed'"
        fi
    fi

    if [ $IGNORE_CASE == y ]; then
        GREP_FLAGS+=("-i")
    fi
    if [ $REGEXP == y ]; then
        GREP_FLAGS+=("-E")
        XBPS_FLAGS+=("--regex")
    fi
}

do_match() {
    local tmp_file=$(mktemp)
    grep $GREP_FLAGS $1 $MATCHED_FILE > $tmp_file
    [ -v DEBUG ] && cat $tmp_file
    mv $tmp_file $MATCHED_FILE
}

find_matches() {
    xbps-query -Rs ${MATCHING[0]} $XBPS_FLAGS > $MATCHED_FILE

    for thing in ${MATCHING[@]:1}; do
        do_match $thing
    done
}

find_this_match() {
    local thing=$1
    (xbps-query -RS $thing $XBPS_FLAGS > $MATCHED_FILE ) || error "Could not query package: $thing"
}

postprocess_matches() {
    [ -v DEBUG ] && echo Filters: $PP_FILTERS
    local last_flags=$GREP_FLAGS
    GREP_FLAGS=()
    if [[ $PP_FILTERS == *I* ]]; then # match only installed packages
        do_match "[*]"
    elif [[ $PP_FILTERS == *N* ]]; then # match only not installed packages
        # -v inverts grep (include only lines that didn't match)
        # this is a hotfix because matching "[-]" doesn't seem
        # to work at all, and I don't understand why.
        local last_flags=$GREP_FLAGS
        GREP_FLAGS+=("-v")
        do_match "[*]"
        GREP_FLAGS=$last_flags
    fi
    GREP_FLAGS=$last_flags
    if [[ $PP_FILTERS == *S* ]]; then # show very short version (names only, separated by newline)
        # TODO: strip the version off
        local tmp_file=$(mktemp)
        (cat $MATCHED_FILE | awk '{ print $2 }') > $tmp_file
        mv $tmp_file $MATCHED_FILE
    fi
}

postprocess_this_match() {
    if [[ $PP_FILTERS == *S* ]]; then
        # only display the lines matched here, in order:
        local tmp_file=$(mktemp)
        for line in "pkgname" "pkgver" "short_desc" "installed_size"; do
            grep $line $MATCHED_FILE >> $tmp_file
        done
        local cleaned_file=$(mktemp)
        awk '1 { printf(" %-16s: %s\n", $1, $2) }' FS=':' $tmp_file > $cleaned_file
        mv $cleaned_file $tmp_file
        mv $tmp_file $MATCHED_FILE
    fi
}

# Execution begins here:

parse_cli $@
if [ -z $MATCHING ]; then
    # echo Nothing to match
    print_help
    exit 1
fi

MATCHED_FILE=$(mktemp)
if [ $THIS_MODE == y ]; then
    find_this_match ${MATCHING[0]}
    postprocess_this_match
    cat $MATCHED_FILE
    rm $MATCHED_FILE
    # we handle package resolution failure in `find_this_match`
    exit 0
else
    find_matches
    postprocess_matches
    cat $MATCHED_FILE
    if ! [ -s $MATCHED_FILE ]; then
        rm $MATCHED_FILE
        exit 1
    fi
    rm $MATCHED_FILE
    exit 0
fi
