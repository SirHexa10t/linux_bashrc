#!/bin/bash

# Embed other-language scripts into bashrc, as simple commands

SCRIPTS_INIT_FILE="$(realpath "$BASH_SOURCE")"  # this file
SCRIPTS_PATH="$(dirname "$SCRIPTS_INIT_FILE")/scripts"

# alias _scripts_loaded_comfirmation='_py_confirm_loaded'  # a call to a script added in just to confirm that the rest of the scripts are reached right 

 # get the list of cheatsheet files
function _get_script_files () { find "$SCRIPTS_PATH" -type f -not -path '*/__pycache__/*' -not -path '*/.idea/*'; }
 # get the list of script-relevant bashrc-expansion files
function _get_bashrc_adaptation_files () { find "$(dirname "$SCRIPTS_INIT_FILE")" -maxdepth 1 -type f -not -name "$MODULE_LOADER_PATTERN" -name "*.sh"; }
# get command name that runs the script/program-file ; arg1: the file (or main file)
function _get_cmd_name () {
    local filename="$(basename "$scr_file")"
    local extension=$([[ "$filename" = *.* ]] && echo "${filename##*.}" || echo 'generic' )  # gets file-type, or default if there's no dot.
    echo "$extension ${filename%.*}" | awk '{ print (substr($2,1,1) == "_") ? "_"$1$2 : $1"_"$2 }'  # keep the file name but not the ending suffix. use ext as prefix, and make sure it's separated from the filename and that it keeps the leading "_" if it exists
 }

# used by "remindme" - lists this file's introduced aliases and functions
function _list_script_calls () {
    echo '# ---------- EXTERNAL (sourced non-bash) ----------'
    
    local scr_file
    while IFS= read -r scr_file; do
        local documentation="$(
            if [[ "$scr_file" == *.py ]]; then  sed -n '/"""/, /"""/{ /"""/! { /"""/! {p; q}}}' "$scr_file";  # get the documentation between 2 """ strings
            else  grep -n -m 1 -v '^#' "$scr_file" | cut -d ':' -f 1 | head -n $(($(cat) - 1)) "$scr_file";  # default (no extension) - get consecutive comments starting with '#' from top of file
            fi
        )"
        # unify multiple lines and sanitize
        [ -n "$documentation" ] && documentation="$( echo "$documentation" | paste -s -d ' ' | sed 's/^#[[:space:]]*//' )"
        echo "$(_get_cmd_name "$scr_file")  # $documentation"
    done <<< "$(_get_script_files)" 
}

# load script-files as terminal commands
while read -r scr_file; do eval "function $(_get_cmd_name "$scr_file") () { "$scr_file" \"\$@\"; }"; done <<< "$(_get_script_files)"  && unset scr_file

# source all other .sh files in same dir
while read -r file; do source "$file"; done <<< "$(_get_bashrc_adaptation_files)"  && unset file


