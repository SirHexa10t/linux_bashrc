#!/bin/bash

# Cheatsheet management file

CHEATSHEETS_FILE="$(realpath "$BASH_SOURCE")"  # not necessary if main script already has it, but with this the file is more independent
CHEATSHEETS_PATH="$(dirname "$CHEATSHEETS_FILE")/cheatsheets"
CHEATSHEET_PREFIX='howdoi_'

# Synonymous to "cheatsheets".
alias list_cheatsheets='cheatsheets'

# get the list of cheatsheet files
function _get_cheatsheet_files () { find "$CHEATSHEETS_PATH" -type f; }
# get command name that opens cheatsheet ; arg1: cheatsheet file
function _derive_chsh_cmd_name () { echo "${CHEATSHEET_PREFIX}$(basename "${1:-$(cat)}")"; }

function _load_cheatsheets () {
    local chsh_file
    while IFS= read -r chsh_file; do
        local cmd_name="$(_derive_chsh_cmd_name "$chsh_file")"
        eval "function $cmd_name () { commecho -l < \"$chsh_file\"; }"
    done <<< "$(_get_cheatsheet_files)" 
}

_load_cheatsheets


function _list_cheatsheets_api () {
    echo ''
    echo '# ---------- CHEATSHEETS (info-packed notes) ----------'
    local chsh_file
    while IFS= read -r chsh_file; do
        local non_comment_line_number="$(grep -n -m 1 -v '^#' "$chsh_file" | cut -d ':' -f 1)"  # get number of first line that doesn't start with '#'
        # get comment lines consecutively, merge into one line, trip away the beginning sharp sign
        local documentation="$( head -n $((non_comment_line_number - 1)) "$chsh_file" | paste -s -d ' ' | sed 's/^#[[:space:]]*//' )"
        
        echo "$(_derive_chsh_cmd_name "$chsh_file")  # $documentation"
    done <<< "$(_get_cheatsheet_files)" 
}


# TODO - scan this file to have these functions listed in "remindme"
# displays all cheatsheet commands
# arg1 (optional): word to search within cheatsheets
function cheatsheets () {
    function _print_if_stream () {
        local text="$(cat)"
        [ -n "$text" ] && { echo; becho "$(_underline "$1")"; echo "$text"; }
    }
    
    local command_list=$(_get_cheatsheet_files | while IFS= read -r line; do _derive_chsh_cmd_name "$line"; done)
    if [ -n "$1" ]; then    # search
        echo "$command_list" | grep "$1" --color=always | _print_if_stream "Comment/filename matches"
        local file
        _get_cheatsheet_files | while IFS= read -r file; do grep -e "$1" -i "$file" --color=always | _print_if_stream "Matches within $(wecho $(_derive_chsh_cmd_name "$file"))" ; done        
    else    # general info
        tree --dirsfirst "$CHEATSHEETS_PATH"
        echo
        echo "${command_list[@]}" | _print_if_stream "Commands:"
    fi
    
}








