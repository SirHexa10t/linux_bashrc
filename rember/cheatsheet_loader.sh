#!/bin/bash

# Cheatsheet management file

CHEATSHEETS_INIT_FILE="$(realpath "$BASH_SOURCE")"  # not necessary if main script already has it, but with this the file is more independent
CHEATSHEETS_PATH="$(dirname "$CHEATSHEETS_INIT_FILE")/cheatsheets"
CHEATSHEET_PREFIX='howdoi_'

declare -A CHSH_FLAGS
CHSH_FLAGS['--edit']='xdg-open'  # open with default editor (like Xed)
CHSH_FLAGS['-e']='xdg-open'
CHSH_FLAGS['--fp']='echo'  # file-path printing
CHSH_FLAGS['--cd']='cd'  # change-dir to file location (uses custom_bashrc's cd override)
[ -n "$(which codium)" ] && CHSH_FLAGS['-c']='codium'  # open with VSCodium (only if available)
CHEATSHEET_PLACEHOLDER='chsh_file'

# TODO ? -g for grep, maybe --cat for cat and changing fp to --echo

function _get_chsh_edit_conditions () {
    function _get_chsh_edit_condition () { echo 'if [ "$1" == '"$1"' ]; then '"${CHSH_FLAGS[$1]} '$CHEATSHEET_PLACEHOLDER'; "; }  # if var exists, check gets printed
    local flag  condition_items=()
    for flag in "${!CHSH_FLAGS[@]}"; do condition_items+=("$(_get_chsh_edit_condition "$flag")"); done
    # separate with "el" (to make those "elif") and add the default op
    local final_contents="$(printf '%sel' "${condition_items[@]}")if : ; then commecho -l < $CHEATSHEET_PLACEHOLDER; fi"  # last block applies by default, but still uses "if" (if TRUE), in case the string before it is empty
    
    echo "$final_contents"
}
CHSH_FUNCTION_CONTENTS="$(_get_chsh_edit_conditions)"
CHSH_FLAGS_SPECIFICATION="$( for flag in "${!CHSH_FLAGS[@]}"; do echo -n "$(wecho "$flag"): open/print file using $(orecho "${CHSH_FLAGS[$flag]}") ;  "; done )"


# Synonymous to "cheatsheets".
alias list_cheatsheets='cheatsheets'

# get the list of cheatsheet files
function _get_cheatsheet_files () { find "$CHEATSHEETS_PATH" -type f; }
# get command name that opens cheatsheet ; arg1: cheatsheet file
function _derive_chsh_cmd_name () { echo "${CHEATSHEET_PREFIX}$(basename "${1:-$(cat)}")"; }


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
        # buffer the prints
        local paste_explanation="$(
            orecho "To search within cheatsheets, rerun this command, followed by string-to-search."
            orecho "To edit a cheatsheet you can run its \"$CHEATSHEET_PREFIX\" command, followed by a flag. $( for flag in "${!CHSH_FLAGS[@]}"; do echo -n "$(wecho "$flag"): open/print file using $(orecho "${CHSH_FLAGS[$flag]}") ;  "; done )"
            echo 
            tree --dirsfirst "$CHEATSHEETS_PATH"  # paste files, tree style
            echo
            echo "${command_list[@]}" | _print_if_stream "Commands:"
        )"
        echo "$paste_explanation"
    fi
}


# load cheatsheets
while read -r chsh_file; do
    eval "function $(_derive_chsh_cmd_name "$chsh_file") () { "${CHSH_FUNCTION_CONTENTS//$CHEATSHEET_PLACEHOLDER/$chsh_file}"; }"
done <<< "$(_get_cheatsheet_files)"   && unset chsh_file













function _howdoi_rember () {
    
    local br='<=very_light_red=>'       # eyes-inner, tongue
    local r='<=red=><=bold=>'           # eyes outer
    local m='<=red=>'                   # inner-mouth
    local o='<=dark_brown_2=>'          # outline and brows and borders
    local c='<=skin_pink_2=>'           # cheeks
    local s='<=skin_light=>'            # skin ; maybe use <=b_yellow=> 
    local h='<=medium_green=>'          # hair ; maybe use <=b_green=>
    local w='<=light_grey=><=bold=>'    # reflections and background
    local writings='<=h_green=> '
    local y='*'                 # not a color, just an almost-outline char that counts on the background to "darken" the color

    # To make parts of the hair brighter, replace the hair chars with '#' - it's leaving less space fot the blackness of the terminal

local ascii_gyate_yuuka_inverted="\
${w}@@@@@@@@@@@@@@&${o}(${w}%@${h}%((((((((((((((((((((((((((((((((((((((((((((((((${w}##((@&#(#%@@@@@@@@@@@@&#${o}&L${w}&@@@@@@
${w}@@@@@@@@@@@@${o}%${w}(@@@@@%${h}(((((((((((((((((((((((((((((((((((((((((${w}#@@%(%@@&####${h}/((((((((((${w}Y%@@%${h}l${w}%${o}Y(${w}@@@@@@
${w}@@@@@@@@@@#${o}/${w}8@@@@@@%${h}(${w}%@%${h}(((((((((((((((((((((((((((${w}(##%%&@@@@&${h}((((${y}((${y}((${y}((/((((((((((((${w}V&${h}((((${o}R${w}&@@@@
${w}@@@@@@@@${o}%/${h}(((${w}@@@@%#${h}((${w}##${h}(((((((((((((((((((${o}(${h}(((((${w}(&&${y}###${h}((((((((((((${y}(((${y}((${y}((((((((((((((${w}v${h}(((((/${o}(${w}@@@
${w}@@@@@@${o}%${h}(((((((((((((((((((((((((((${y}((((((${o}(${s}&${o}@${h}((((((((${y}(((((((((((((((${y}((${y}((((${y}((((((((((((((((((((${o}(${w}&@
${w}@@@@@${o}#${h}((((((((((((((((((((((((((${w}/%%&${y}/${o}/((((&%${o}%(//${h}((((${y}((((((((((((((((${y}${o}/(((#((${y}/${h}(((((((((((${y}((((((${o}T${w}&
${w}@@@${o}&${h}((((((((((((((((((((((((((${w}(%((${o}/(${y}(${h}/(((${o}(${s}@@@@${o}&${h}((((((${y}((((((((((((((((${y}((((((${y}/(${o}#(/${h}((((((((${y}(((((${o}R${w}l
${w}@@${o}%${h}(((((((((((((((((((((((${w}####${o}//(${h}(((${y}//(((${o}(${s}@@@&@${o}@${h}(((((${y}((((((((((((((((${y}(((((((${y}(((((${o}^${h}(((((((${y}(((((${o})
${w}@${o}&${h}((((((((((${y}${y}${y}(((((((((((((${y}((((((((${y}(((((${s}@@@@@@&${h}/(((${y}(((((((((((((((${y}${y}(((((((${o}(#${h}/((/((((((((((((((${o}|
${o}&${h}((((((((${y}((((((${y}(((((((((((${y}((((((((${y}(((${o}/${s}%@@@@@@@${o}%${h}/(${y}(${y}(((((((((((((${s}&${o}(/${h}((((((${o}/${s}#@${o}(${h}(((((((((((((((((${o}l
${o}/${h}(((((((${y}((((((${y}${y}(((((((((((${y}(((((((${o}(${s}@${o}/${h}((${o}(${s}&@@@@@@@${o}@${h}((${o}#${h}((${y}(((((((((((${o}/${s}&${o}(${h}${s}#${o}(${h}(((${o}/${s}(%@@${o}%${h}(((((((((((((((/(${o}/
${h}((((((${y}((((((${y}((((((((((((${y}(((((((/(${s}@&${o}/${h}(${o}(${s}#%%#%%&@@${o}&${h}((${s}(${o}/${h}&${y}(((${o}(((${h}((((${o}(${s}&&@(//${o}==${r}====${s}@&${o}(${h}((((((((((((((${o}h${h}l${w}l
${h}(((((${y}(((((((((((((((((((${y}((((((${o}/(${s}%#${o}//${r}//////////${w}&${s}@${o})${h}v${s}d&${o}%@${h}v${o}//${s}#@@&@@${o}&&${s}@@@@${o}*${w}#/${r}/*////*//${o}b${h}((((((((((((${o}/${w}l${o}H${w}(
${h}(((((${y}(((((((((((((((((${y}(((((${o}(/${s}@@${o}/${w}/&/${r}///&&&&/${br}#${w}@@@@${s}@&&@@@@@@@@@@@@@@@@@@${w}##(${r}///${br}&&&/${r}///${o}&${h}((((((((((${o}#${w}/#${o}V${w}#
${h}((((((${y}((((((((((((${y}${y}(((((${o}(/${s}(@@${o}(/${w}%@#${r}///&${br}&&&&&${r}(///${w}#${s}%@@@@@@@@@@@@@@@@@@@@${w}@#${r}///${br}d&&&${w}@@@@${o}b${h}/(((((((((${o}(${w}/@@&
${h}(((((((${y}${y}${y}${y}((((${y}${y}${y}${y}(/(((/${o}#${s}@@@&${o}(${w}(@@&${r}////${br}&&&&&&(${r}(//${w}#${s}%@@@@@@@@@@@@@@@@@@@@@${w}#${r}///${br}&&&&&&${r}//${w}#${s}(${o}Y${h}(((((((${o}(${w}/&@@@
${h}(((((((((((${y}${y}${y}(((((((((${o}((${s}@@@@${o}#${w}/&@@/${r}////${br}&&&&&&(#${r}(/${w}#${s}%@@@@@@@@@@@@@@@@@@@@@${w}#${r}///${br}&&&&&&${r}//${w}(${s}&${o}/${h}((((${y}${y}${o}/#${w}@@@@@
${h}(((((((((((((((((((((${o}((${s}(@@@@&${o}#${w}/@@@&${r}(///${br}&&&&&&#${w}&${r}@/${w}#${s}%@@@@@@@@@@@@@@@@@@@@@${w}&${r}//${w}@@b${br}&&&${w}@@${r}/${w}(${s}&${o}I${h}(((((((((((${o}7${w}V
${h}(((((((((((((((((((((${y}(%${o}@${s}@@@@${o}(${w}&@@@@${r}(//${w}&&@%${br}&&${w}#&@%${r}/${w}#${s}@@@@@@@@@@@@@@@@@@@@@@@${w}%${r}/${w}(@@@@@@${r}((${w}&${s}@%${o}R${h}(((((((((((${o}(
${h}(((((((((((((((((((((${y}((((%${o}&${s}@&${o}(${w}&@@@@${r}(*(${w}&@@&@@@#${r}/${w}#${s}&@@@@@@@@@@@@@@@@@@@@@@@@${w}%${r}(//((//${w}%${s}@@@@@${o}#${h}(((((((((((
${h}(((((((((((((((((((((${y}(((((((${o}&${s}@${o}#${w}@@@@@&(${r}/*//*//${w}%${s}@@@@@@@@@@@@@@@@@${o}#${s}&@@@@@@@@@@&&&&@@@@${c}&@&&&%#%%${h}((((${w}&@${h}(
${h}((((((((((((((((((((((((((((((${o}@${s}@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@${c}&&&&&&&&&&&${w}d@@&@&
${h}((((((((((((((((((((((((((((((${o}/${s}&@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@${c}&&&&&&&&&${h}((((((${w}V${h}(
${h}(((((((((((((((((((((((((((${w}@&${h}(${c}%&&&&&&&&${s}@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@${o}@${h}/(((((((((
${h}((((((((((((((((((((${w}&@@&${h}(${w}%@@&${c}&&&&&&&&&&&${s}@@@@@@@@@@@@@@@@@PMMMMMMM8@@@@@@@@@@@@@@@@@@@@@@@${o}@${h}((((((((((
${h}((((((((((((((((((${w}(#@&#&@@${h}(${w}#@&${c}&&&&&&&&&${s}@@@@@@@@@@@@@&${m}%%%%%%//////${o}//@7${s}@@@@@@@@@@@@@@@@@@@@${o}@${h}((((((((((
${h}((((((((((((((${w}#####${h}(${w}#${h}(((${w}##${h}(${w}(&#${h}/${o}#${s}@@@@@@@@@@@@@@@@@@@@@${o}#${br}/######6(${r}(//${o}/${s}%@@@@@@@@@@@@@@@@@@@@${o}@${h}(/((((${y}((((
${h}(((((((((((((((((((((((((((((${w}(${h}/${o}%${s}@@@@@@@@@@@@@@@@@@@@@&${o}#${br}########&${m}(/${s}d@@@@@@@@@@@@@@@@@@@@${o}&${h}(((((${y}((${y}(((
${h}(((((((((((((((((((((${y}((((((((((${o}@${s}@@@@@&@@@@@@@@@@@@@@@@${o}#${br}########/${o}#${s}@@@@@@@@@@@@@@@@@@@${o}%${h}((((((((${y}${y}${y}${y}${y}(
${h}(((((((((((((((((((((${y}((((((${y}((((${o}%${s}@@&P${o}/${s}@@@@@@@@@@@@@@@@@@&${br}%###((${s}&@@@@@@@@@@@@@@@@@${o}%${h}(((((((((((((${y}${y}${y}${o}/
${h}((((((((((((((((((((((${y}(((((${y}(((${y}((${h}(${y}${o}#${s}@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@${o}&#${h}((((((((((((((((${o}L${w}7#&
${h}((((((((((((((((((((((${y}${y}((((((${y}(((${y}(${o}%${s}@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@${o}&%${h}((((((((((((((((${o}w${h}((${o}(${w}#@@@@
${h}((((((((((((((((((((((((${y}(((((${y}${y}((((((/${o}/${o}(${w}#&${o}&@${s}@@@@@@@@@@@@@@@@@@@@@&${o}%${h}((((((((((((((((((((((${o}(${w}@${o}^${w}#%@@@@@
${h}/((((((((((((((((((((((((((${y}((((${y}((${y}${o}/${w}(%@@@@@@@@%${o}>${s}W@@@@@@@<${o}</${w}d@@@@@${o}&${h}((((((((((((((((((((((${o}/${w}%@@@@@@@@@
${writings}pls rember that wen u feel scare or frigten 
${writings}never forget ttimes wen u feeled happy      
${writings}                                            
${writings}wen day is dark alway rember happy day      
"

    _draw_formatted "$ascii_gyate_yuuka_inverted"
}





# @@@@@@@@@@@@@@&(%@%((##((((((((((((((((((((((((((((((((###(#((##(((##((@&#(#%@@@@@@@@@@@@&#/@&@@@@@@
# @@@@@@@@@@@@%(&@@@@%(###(((((((((((((((/(#(((((((((((((##((((#@@%(%@@&####/((#((#((((#%@@%(%((@@@@@@
# @@@@@@@@@@#/&@@@@@@%(%@%((((((((((((((#(/(((((((((((##%%&@@@@&(#((#((#((#((/((((((((((((#&((((/&@@@@
# @@@@@@@@%/(@@@@@@%#((##((((((((((((((/#((((/((#((&&####(((((((#(((((((((((#((((((#(((((((((((((/(@@@
# @@@@@@%(#(((((((((((((((((((((((((#((/(##(&@#/(#%(((((((((((#((((((/#((#((((((((#((((((((((((((#(/&@
# @@@@@#(((((((((((((((((((#((#(((/%%&#//((((&%%(///(((/((((((((((((((/(//(((#((//((((#((((((#((((((/&
# @@@&((((((((((((((((((((((#((((%((/(#(/((((@@@@&/(#(#(/(#(((((((((((/((((((##(//(#(//(((#(((#(((#(((
# @@%(((((((((((((((((((((((####//((((#//((((@@@&@@((#((//((((((((((((////(((((((/((((((/((((((((/(((/
# @&((#(((#(((((#((((#((((((((((/(#((((/((#((@@@@@@&/(#((/((#((((((###/#//(((#((#(#/((/((((((((((((((/
# &/(((((((#(((/((#((((((((((#((((((#((%((#/%@@@@@@@%/(((((((((((((((((&(/(##(#(/#@((#((#((((((((#(/((
# /((((#((#(/((((##(((((((((((/((#(#(((@/(((&@@@@@@@@((#/#((((#((((#((/&(#(#(#/(%@@%/#/((((((((((((/(/
# (##((#((/((#(#(((((((((((((/((##((/(@&/((#%%#%%&@@&#((/&#((#((((((((&&@(////(&%%@&((/(#(((((((#(#///
# (((##((((((((((#((((((((((/((#((/(%#///////////(/(/#//%@#//#@@&@@&&@@@@%(//*////*///((((((((((((#/#(
# ((#(#(/(((((((((((((((#(/((##(/##//&/////////#@@@@@&&@@@@@@@@@@@@&@@@&/#&(///////////((((((((((#/#&#
# #((((/(((((((((((((#(((/#((/(%@(/%@#///(((((((////%@@@@@@@@@@@@@@@@@@@@@#///((((#%&%//((((((((((/@@&
# (((#(/(##(((((##((#(/(((/#@@@&((@@&////((((((((///%@@@@@@@@@@@@@@@@@@@@@#///((((((//#(/#((##((((&@@@
# #((#(/((((((((##(/((#(#((@@@@#/&@@&////(((((((#(//%@@@@@@@@@@@@@@@@@@@@@#///((((((//(&/(#(((//#@@@@@
# ((((#((/((((((//(##(((((@@@@&#/@@@&(///((((((#&@//%@@@@@@@@@@@@@@@@@@@@@&//%%#(((#(/(&/(((((((((/(%@
# (#(((((((((((#((((((((/%@@&@@(&@@@@(//&&@%((#&@%/(@@@@@@@@@@@@&&@@@@@@@@@%/(&@@@@@((&@%/((((#(#(((((
# (((((((((((#((((((((((/#(/%&@&(&@@@@(*(&@@&@@@#/#&@@@@@@@@@@@@@@@@@@@@@@@@%(*/((//%@@@@@#/(#((((((((
# ((((((((#((((((((((#((((#(#(#&@#%@@@@&(/*//*//%@@@@@@@@@@@@@@@@@#&&@@@@@@@@@&&&&@@@@&@&&&%#%%(#((&@&
# (((((((((((((((((((((((((((#((@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@&&&&&&&&&&&%##&@&
# ((((((((((((((((((((((((((##((/&@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@&&&&&%&&&%##(((#%
# #(((((((((((((((((((((((((%@&#%&&&&&&&&@@@@@@@@@@@@@@@@@@@@@@@@@@&&@@@@@@@@@@@@@@@@@@@@@@@@/((((((((
# (#(((((((((((((((((#&@@&#%@@&&&&&&&&&&&&@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@&/(#((((((
# #(#((((((((((((((((#@&#&@@%#@&&&&&&&&&&@@@@@@@@@@@@@&%///////////////#@@@@@@@@@@@@@@@@@@@@(/((((((((
# #(((((((((((((#####%#(((##((&#/#@@@@@@@@@@@@@@@@@@@@@#/#((#(((((///%@@@@@@@@@@@@@@@@@@@@@(/(#((/((#(
# ((((((((((((((((((((#(((((#(((/%@@@@@@@@@@@@@@@@@@@@@&((#(#((((((/#&@@@@@@@@@@@@@@@@@@@&//(((#(//(//
# (((((((((((((((((((((#((((((((((@@@@@@&@@@@@@@@@@@@@@@@#/(#(((((/#@@&@@@@@@@@@@@@@@@@%/(((((((#(((((
# (((((((((((((((((((((((##(/(#((((%@@&%/@@@@@@@@@@@@@@@@@@&%(//((&@@@@@@@@@@@@@&@@@%(/(((((((((#((##(
# ((((((((((((((((((((((((((((/((((#((/#@@@&@@@@@@@@@@@@@@&@@@@@@@@@@&@@@@@@@@@@@#/((#((((((((((##(/#&
# ((((((((((((((((((((((##((((#(((((/(%@@@@&@@@&@@@@@@@@@@@@@@@@@@@@@@@@@@@&%(/((##(((((((#(((##(#@@@@
# (((((((((((((((((((#((((((#((////(((((//(#&&@@@@@@@@@@@@@@@@@@@@@@&%#(//((#((((##((((((((((@%#%@@@@@
# /((((((#((((((#(((((((((/((#(((#(((//(%@@@@@#//(%@@&@@@@@%(//((%&@&((#(((#(#((((((##((##(/%@@@@@@@@@
