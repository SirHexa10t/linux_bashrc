#!/bin/bash

# Cheatsheet management file

CHEATSHEETS_FILE="$(realpath "$BASH_SOURCE")"  # not necessary if main script already has it, but with this the file is more independent
CHEATSHEETS_PATH="$(dirname "$CHEATSHEETS_FILE")/cheatsheets"
CHEATSHEET_PREFIX='howdoi_'
CHSH_EDIT_FLAG='--edit'

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
        eval "function $cmd_name () { [[ \"\$1\" == \"$CHSH_EDIT_FLAG\" ]] && xdg-open \"$chsh_file\" || commecho -l < \"$chsh_file\"; }"
    done <<< "$(_get_cheatsheet_files)" 
}
_load_cheatsheets


function _list_cheatsheets_api () {
    # get consecutive comments starting with '#' from top of file ; arg1: file
    function _get_cheatsheet_comments () {
        # get first line-num where '#' isn't first char, get all lines before given index, merge and sanitize, print along with filename
        grep -n -m 1 -v '^#' "$1" | cut -d ':' -f 1 | head -n $(($(cat) - 1)) "$1" | paste -s -d ' ' | sed 's/^#[[:space:]]*//'
    }
    echo ''
    echo '# ---------- CHEATSHEETS (info-packed notes) ----------'
    local chsh_file
    while IFS= read -r chsh_file; do
        echo "$(_derive_chsh_cmd_name "$chsh_file")  # $(_get_cheatsheet_comments "$chsh_file")"; 
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
        # search filenames
        echo "$command_list" | grep "$1" --color=always | _print_if_stream "Comment/filename matches"
        # search files' contents
        local file
        _get_cheatsheet_files | while IFS= read -r file; do grep -e "$1" -i "$file" -C 2 --color=always | _print_if_stream "Matches within $(wecho $(_derive_chsh_cmd_name "$file"))" ; done        
    else    # general info
        orecho "To search within cheatsheets, rerun this command, followed by string-to-search."
        orecho "To edit a cheatsheet you can run its \"$CHEATSHEET_PREFIX\" command, followed by the flag \"$CHSH_EDIT_FLAG\""
        echo 
        tree --dirsfirst "$CHEATSHEETS_PATH"  # paste files, tree style
        echo
        echo "${command_list[@]}" | _print_if_stream "Commands:"
    fi
    
}








