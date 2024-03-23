#!/bin/bash

# handle preferences set by the user

CONFIGS_INIT_FILE="$(realpath "$BASH_SOURCE")"  # this file
CONFIGS_FILE_NAME='configs'
CONFIGS_TEMPLATE_FILE="$(dirname "$SCRIPTS_INIT_FILE")/${CONFIGS_FILE_NAME}_template"

CONFIGS_USER_FILE="$UTILITY_FOLDER_PERSONAL/$CONFIGS_FILE_NAME"


# # check if user already has configs, create them if not
# if [! -f "$CONFIGS_USER_FILE" ]; then
#     echo "Personal config file not found. Creating file: "$CONFIGS_USER_FILE""
#     mkdir -p "$(dirname "$CONFIGS_USER_FILE")"  # make sure dir exists
#     cp "$CONFIGS_TEMPLATE_FILE" "$CONFIGS_USER_FILE"
# fi

# load configs
declare -A BASHRC_CONFIGS


# announcements to user regarding configs and packages
# functions _


# check if user's configs are outdated
function _is_ver1_outdated() {
    IFS="." read -r -a v1_arr <<< "$1"
    IFS="." read -r -a v2_arr <<< "$2"
    
    for ((i=0; i<${#v1_arr[@]}; ++i)); do
        [[ ${v1_arr[i]} -lt ${v2_arr[i]} ]] && return 0
        [[ ${v1_arr[i]} -gt ${v2_arr[i]} ]] && return 1
    done
    return 1
}


