#!/bin/bash



echo "# prerequisites"
echo "# ============="
LOCAL_BASHRC_FILE="$(dirname $(readlink -f -- "$BASH_SOURCE"))/custom_bashrc"
echo "temporarily loading local bashrc file to access its functions (file: \"$LOCAL_BASHRC_FILE\" )"
SCRIPTED_SOURCING=1  # silent sourcing and no key-binds
. "$LOCAL_BASHRC_FILE" && dagecho 'Done' || { echo 'Failed loading bashrc file. Quitting.'; exit; }  # source file

buecho "From here-on, you may quit at any point during a prompt by pressing CTRL+C. It's fine to re-run the script later, after quitting a previous run in the middle."
buecho "If any update breaks your configurations, try rerunning this script (it'll be updated accordingly)"


title_prnt_cmd='yecho'

$title_prnt_cmd "# git handling (for updates and such)"
$title_prnt_cmd "# ==================================="

function update_with_git () {
    if [ -e "$CUSTOM_BASHRC_FOLDER/.git" ]; then
        dagecho "Detected that a git setup exists." 
    else  # no git directory
        recho "git setup not detected."
        
        deprecated_folder_name="${CUSTOM_BASHRC_FOLDER}_old"

        dagecho "deprecating current folder by moving it to '_old': $deprecated_folder_name"
        mv "$CUSTOM_BASHRC_FOLDER" "$deprecated_folder_name"

        dagecho "cloning from git"
        git clone "https://github.com/SirHexa10t/linux_bashrc.git" "$CUSTOM_BASHRC_FOLDER"

        [ ! -e "$CUSTOM_BASHRC_FOLDER/.git" ] && { errcho "Something is wrong, I still don't see the git configurations. Exiting!" ; exit ; }

        dagecho "Finished cloning. You should see the re-downloaded project in the previous one's location (remember to handle/clear-away the _old one)"
        becho "The current script might no longer be the same, so it'll exit now. Rerun the script, preferably on a new terminal."
        exit
    fi

    git fetch  # update git setup's metadata so it'll know the status of remote
    if git status -uno | grep 'Your branch is behind' | grep -q 'can be fast-forwarded'; then
        becho "Local repository is behind on branch \"$(git branch --show-current)\""
        git pull \
            && becho "Your project should be up-to-date now. The current script might no longer be the same, so it'll exit now. Rerun the script, preferably on a new terminal." \
            || errcho "Something went wrong with the pull command; resolve it"
        exit
    else
        dagecho "Local repository is up to date. Or just can't be fast-forwarded (if you think something is wrong, update your git branch manually)."
    fi
}

if command -v git &> /dev/null; then  # if command "git" exists
    update_with_git
else
    errcho "The program \"git\" is not installed. It's highly recommended that you install it and rerun this script."
    if _prompt_yn "Would you like to continue anyway?"; then dagecho "Alright, it's your choice."; else { dagecho "Exiting." ; exit ; } ; fi
fi





$title_prnt_cmd "# setting up bashrc for the user"
$title_prnt_cmd "# =============================="

locations=(
    "$HOME/.bashrc"
    "$HOME/.bash_profile"
    "$HOME/.bash_login"
    "$HOME/.profile"
    "/etc/bash.bashrc"
    "/etc/profile"
    "/etc/profile.d/bashrc"
    "skip"
)
declare -A location_suggestions=(
    ["$HOME/.bashrc"]="(recommended; if this setup is meant only for your user)"
    ["/etc/bash.bashrc"]="(ideal for setting up / maintaining for all users at the same time. In this scenario, for security's sake, make the bashrc file unwritable)"
    ["/etc/profile"]=$([ ! -f "/etc/profile" ] && echo "(NOT recommended - file doesn't exist)")
    ["/etc/profile.d/bashrc"]=$([ ! -f "/etc/profile.d/bashrc" ] && echo "(NOT recommended - file doesn't exist)")
    ["skip"]="(if you already set-up the project's sourcing previously)"
)
location_chosen=''
while [ -z "$location_chosen" ]; do

    buffered_prompt=$(
    becho "Where should the bashrc file be sourced? (pick number)"
    index=''
    for index in "${!locations[@]}"; do
        location="${locations[$index]}"
        echo "$index $location $(dabecho "${location_suggestions[$location]}")"
    done
    becho "============================================="
    )

    echo "$buffered_prompt"
    read -p "choice-index: " number_picked  # Read the user's input
    [[ "$number_picked" =~ ^[0-9]+$ ]] && location_chosen="${locations[$number_picked]}"  # if picked a number, set the pick
done

function write_sourcing_into_file () {
    [ ! -f "$location_chosen" ] && { errcho "The file \"$location_chosen\" doesn't exist. Set it up and then re-run this script."; exit ;}

    q_ch="'"
    appended_sourcing='
CUSTOM_BASHRC_FILE='"$CUSTOM_BASHRC_FILE"'
if [ -f "$CUSTOM_BASHRC_FILE" ]; then source "$CUSTOM_BASHRC_FILE" 
else echo "couldn'$q_ch't find custom_bashrc file at \"$CUSTOM_BASHRC_FILE\" , fix the file'$q_ch's permission-modifiers or fix the sourcing at \"$(readlink -f -- "$BASH_SOURCE")\"";  # print faulty file-dir, and this (current) file'$q_ch's location
fi
'
    if ! grep -q "$appended_sourcing" "$location_chosen"; then
        becho "appending sourcing code to $(wecho $location_chosen)"
        echo "$appended_sourcing" >> "$location_chosen" ||  { echo "$appended_sourcing" | sudo tee -a "$location_chosen" >/dev/null; }

        if grep -q "$appended_sourcing" "$location_chosen"; then
            dagecho "Done."
        else
            errcho "Didn't manage to write the sourcing."
            becho "this is the sourcing text:"
            echo "$appended_sourcing"
            becho "this is the current end of the file:"
            tail "$location_chosen" || sudo tail "$location_chosen"
            exit
        fi
    else
        dagecho "seems like sourcing is already set in \"$location_chosen\""
    fi
}

# add the sourcing if user didn't pick "skip"
[ "$location_chosen" != 'skip' ] && write_sourcing_into_file





$title_prnt_cmd "# setting up utility files"
$title_prnt_cmd "# ========================"

var_pick_quit='done'
utility_vars=($(printf '%s\n' "${!_UTILITY_FILE_MAP[@]}" | sort))
utility_vars+=("$var_pick_quit")

declare -A vars_explanation=(
    ['TESTS_FILE']="A file that gets sourced after bashrc finishes loading, so any tests you write in it will execute ASAP. For $(wecho "development") of this project."
    ['GARBAGE_OUTPUTS']="Default text-dump. There are aliases for tailing or writing into it. Mostly for $(wecho "development") of this project."
    ['SUBDIR_MOUNTS_FILE']="Defines custom shortcuts for media-drives, like /music, or /projects"
    ['CREDENTIALS_OPENAI']="API key for OpenAI's ChatGPT 3.5 (paid-subscription). Used to query $(wecho "A.I.") through simple terminal commands."
    ['DISPLAY_ARRANGEMENT']="Screen rearrangement through a keybind. Useful if your OS messes up your screen layout at times."
    ['CUSTOM_TMPDIR']="Changes the tmp-files target-location from root (/) to your folder of choice (possibly on a large drive)"
    ['VM_IMG_PARTITION_UUID']="Partition auto-mounting, in case you use $(wecho "Virtual Machines"), and the VMs' storage is on a separate mountable partition"
    ['LOOKING_GLASS_CLIENT']="Enables custom_bashrc's usage looking-glass (a $(wecho "Virtual Machine") tool)"
)

function choose_utility_var () {
    var_chosen=''
    while [ -z "$var_chosen" ]; do
    
        local buffered_prompt=$(
        becho "Which utility would you like to set-up? (pick number)"
        becho "(note: check available commands once you have a new feature set-up; related functions might stay hidden until then)"
        local index=''
        for index in "${!utility_vars[@]}"; do
            local utility_var="${utility_vars[$index]}"
            local echo_cmd=$( [ -n "$(eval "echo \${$utility_var}")" ] && echo "gecho" || echo "recho")  # if the current var has any value, color it green; otherwise color it red
            [ $utility_var = $var_pick_quit ] && echo_cmd='echo'  # no coloring for the quitting option
            echo "$index $($echo_cmd "$utility_var")  $(dagecho -p "${vars_explanation[$utility_var]}")"
        done
        becho "============================================="
        )
    
        echo "$buffered_prompt"
        read -p "choice-index: " number_picked  # Read the user's input
        [[ "$number_picked" =~ ^[0-9]+$ ]] && var_chosen="${utility_vars[$number_picked]}"  # if picked a number, set the pick
    done
}

function setup_utility () {
    local directory_value="${_UTILITY_FILE_MAP[$var_chosen]}"

    function prompt_create_file () {
        becho -p "This feature requires file: \"$(wecho "$directory_value")\"."
        [ -f "$directory_value" ] && { dagecho "The file already exists, nothing to do."; return ;}
        _prompt_yn "Would you the file to be created?" && mktouch "$directory_value"
    }

    function prompt_input_to_file () {
        [ -n "$1" ] && echo "$1" || becho -p "This feature requires writing into file: \"$(wecho "$directory_value")\"."
        if [ -f "$directory_value" ]; then
            local buffered_prompt=$(
                dagecho -p "The file \"$(wecho "$directory_value")\" already exists, and has these contents:"
                becho "-----------------file-start-----------------"
                cat "$directory_value"
                becho "------------------file-end------------------"
            )
            echo "$buffered_prompt"
            _prompt_yn "Writing a into this file would overwrite the existing contents! Are you sure?" || return  # return if the user doesn't want to overwrite
        fi
        local user_input
        read -r -p "File contents: " user_input 
        mktouch "$directory_value" && echo "$user_input" > "$directory_value"
    }

    function prompt_rootdir_shortcut () {
        [ -n "$1" ] && echo "$1" || becho -p "This feature uses the symlink: \"$(wecho "$directory_value")\"."
        if [ -L "$directory_value" ]; then
            local buffered_prompt=$(
                dagecho -p "The link \"$(wecho "$directory_value")\" already exists:"
                lll "$directory_value"
            )
            echo "$buffered_prompt"
            _prompt_yn "Writing a new target would overwrite the old one. Are you sure?" || return  # return if the user doesn't want to overwrite
        fi
        local user_input
        while [ ! -d "$user_input" ]; do
            read -r -p "Target folder to link into: " user_input
            [ ! -d "$user_input" ] && errcho "\"$user_input\" is not a valid folder!" 
        done
        user_input=$(readlink -f -- "$user_input")  # remove possible '/' at the end
        becho "The shortcut is in root dir, it'll require sudo to create/overwrite the symlink"
        sudo rm "$directory_value" 2>/dev/null ; sudo ln -s "$user_input" "$directory_value"
    }

    local executable_file_warning=$(recho "This file's contents are executable - don't make it permissible for others to write into it.")

    case "$var_chosen" in
        'TESTS_FILE')
            becho "Feature: at the end of custom_bashrc's sourcing, it will automatically run (via another source) a file. It's up to you to decide what's in this file. As the name suggests, it's convenient for testing custom_bashrc."
            echo "$executable_file_warning"
            prompt_create_file
        ;;
        'GARBAGE_OUTPUTS')
            becho "Feature: A default text-dump. Tied to several aliases that make it accessible. Useful for debugging or temporarily storing the output of a long-time operation."
            prompt_create_file
        ;;
        'SUBDIR_MOUNTS_FILE')
            becho "Feature: Create convenient shortcuts into various directories in media partitions, for portability/access/order."
            becho 'Manually write command lines like these into the file: _shortaccess_folder --uuid b25fb935-b252-466f-8e45-63c8e7f62acf --subfolder "test/cache folder" --mountpoint "/temp_cache" --subfolder "logfiles" --mountpoint "/logs" --nomount'
            echo "$executable_file_warning ; will be turned into a read-only file in the future"  # TODO - make this file read-only and sort it out
            prompt_create_file
        ;;
        'CREDENTIALS_OPENAI')
            becho "Feature: Ask ChatGPT using a simple terminal command."
            prompt_input_to_file "$(becho -p "This feature requires your API key (something like: sk-3wUxEyevvnEf9fP2xDn7T3BAbkFJmAOjhKEgH0t1ngXCP7c0). You can get it at: $(buecho https://platform.openai.com/account/api-keys)")"
            chmod 600 "$directory_value"  # ony user is allowed to read/write
        ;;
        'DISPLAY_ARRANGEMENT')
            becho "Easily restore display layout from saved configuration. Convinient in case your OS messes it up."
            prompt_input_to_file "$(becho -p 'This feature requires screen-layout (example: HDMI-0: nvidia-auto-select +1920+1080, DP-0: nvidia-auto-select +1920+0, DP-2: nvidia-auto-select +3840+1080, DP-4: 1920x1080_240 +0+1080" ), which gets fed into an nvidia-settings command. Get this info through: '"$(dabecho 'NVIDIA Settings > X Server Display Configuration -> click on "Save to X Configuration File" -> click on "Show preview..."')"'. I don'"'"'t know how to configure for AMD or Intel, nor whether the display issue occurs on their cards')"
        ;;
        'CUSTOM_TMPDIR')
            becho "Feature: Replace the temp-files dir (default is /tmp), using a symlink that points to a folder. It can improve available cache-writing space (could be critical for some tools/commands) or faster cache-read/write. custom_bashrc evaluates the symlink each time it's sourced, so it won't default to given folder unless it's available."
            prompt_rootdir_shortcut
        ;;
        'VM_IMG_PARTITION_UUID')
            becho "Feature: auto-mount the VMs' storage (usually .qcow2 files) partition when starting a VM through custom_bashrc's functions. If you have no such partition, don't set this."
            prompt_input_to_file "$(becho -p "This feature requires writing the partition's UUID into: \"$directory_value\". You can find the UUID of your partition by running the cusrom command \"devs\"")"
        ;;
        'LOOKING_GLASS_CLIENT')
            becho "Feature: Utilize looking-glass host-client (passthrough of image-stream from a VM-dedicated GPU), using the path to its binaries-file."
            prompt_input_to_file "$(becho -p "This feature requires writing the LG-host-client's path into \"$directory_value\". If you don't have such a client and need one, there's a guide in one of my other git repositories. You can also follow the official guide: $(buecho "https://looking-glass.io/docs/B6/install/")")"
        ;;
    	*)
            errcho "unable to handle choice: $var_chosen"
    	;;
    esac
    
    _remap_utility_files  # reload utility-file vars
}


while [ "$var_chosen" != "$var_pick_quit" ]; do
    choose_utility_var
    [ "$var_chosen" != "$var_pick_quit" ] && setup_utility
done





$title_prnt_cmd "# bringing in external tools and binaries"
$title_prnt_cmd "# ======================================="

echo TODO  # TODO



becho "All done."
becho "As stated before, you can rerun this script anytime."
becho "This terminal session is old by now. You should open a new terminal or renew it to use the sourced bashrc."
