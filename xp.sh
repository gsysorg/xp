#!/bin/bash

# xp -i [install] D
# xp -rm [remove] D
# xp -q [query]   D
# xp -rc [reconfigure] L
# xp -u [-Syu] L
# ... more functions to go, D means early implementation, L means later implementation

show_help()
{
    local arg0="${0##*/}"
    cat <<EOF
xp: xbps wrapper for better days
forked from xbps-q
original author: pohod <https://github.com/pohod/xbps-q>

Usage: $arg0 [flag] [...]

flag parameters [...] are the same from original xbps
for specialized help, check xp -h [cmd]

Options for help flag:
        install, -i, i    Show help for installing packages
        remove, -rm, rm   Show help for uninstalling packages
        query, -q, q      Show help for xp -q / xbps-query

Current Version: ${XP_VERSION:-elm1catch1}
EOF
}

exec_as_su()
{
    if [ "$EUID" -ne 0 ]; then
        sudo "$@"
    else
        "$@"
    fi
}

init_parse()
{
    while :; do
        if [ -z "$1" ]; then return 1; fi;
        case "$1" in
            'help' | '-h' | 'h')
                show_help
                return 0
                ;;
            'install' | '-i' | 'i')
                # sudo xbps-install <package> ...
                shift
                if [ "$1" == "" ]; then
                    echo "[ERROR] Usage: xp -i <package1> <package2> ..."
                    return 1
                fi                
                if [ "$1" == "-y" ]; then
                    shift
                    while [ -n "$1" ] && [[ "$1" != -* ]]; do
                        echo "Installing as $1..."
                        exec_as_su xbps-install -y "$1"
                        shift
                    done
                else
                    while [ -n "$1" ] && [[ "$1" != -* ]]; do
                        echo "Installing as $1..."
                        exec_as_su xbps-install "$1"
                        shift
                    done                    
                fi
                ;;
            'remove' | '-rm' | 'rm')
                # sudo xbps-remove -R <package> ...
                shift
                if [ "$1" == "" ]; then
                    echo "[ERROR] Usage: xp -rm <package1> <package2> ..."
                    return 1
                fi
                if [ "$1" == "-y" ]; then
                    shift
                    while [ -n "$1" ] && [[ "$1" != -* ]]; do
                        echo "Removing $1..."
                        exec_as_su xbps-remove -R -y "$1"
                        shift
                    done
                else
                    while [ -n "$1" ] && [[ "$1" != -* ]]; do
                        echo "Removing $1..."
                        exec_as_su xbps-remove -R "$1"
                        shift
                    done
                fi           
                ;;
            'query' | '-q' | 'q')
                # xbps-query, for now only xbps-query -l, -Rs and -s for simplicity
                shift
                if [ "$1" == "" ]; then
                    echo "[ERROR] Usage: xp -q <cmd> <optional> <optional> ..."
                    return 1
                fi
                if [ "$1" == "-l" ]; then
                    shift
                    xbps-query -l
                fi
                if [ "$1" == "-Rs" ]; then
                    while [ -n "$1" ] && [[ "$1" != -* ]]; do
                        shift
                        xbps-query -Rs "$1"
                    done
                fi
                if [ "$1" == "-s" ]; then
                    while [ -n "$1" ] && [[ "$1" != -* ]]; do
                        shift
                        xbps-query -s "$1"
                    done
                fi                
                ;;
            *)
                echo "[FATAL] Unknown command, please enter xp -h"
                ;;
        esac
        shift        
    done
}
