#!/bin/bash



echo "# prerequisites"
echo "# ============="
LOCAL_BASHRC_FILE="$(dirname $(readlink -f -- "$BASH_SOURCE"))/custom_bashrc"
echo "temporarily loading local bashrc file to access its functions (file: \"$LOCAL_BASHRC_FILE\" )"
SCRIPTED_SOURCING=1  # silent sourcing and no key-binds
. "$LOCAL_BASHRC_FILE" && dagecho 'Done' || { echo 'Failed loading bashrc file. Quitting.'; exit; }  # source file

buecho "From here-on, you may quit at any point during a prompt by pressing CTRL+C. It's fine to re-run the script later, after quitting a previous run in the middle."
buecho "If any update breaks your configurations, try rerunning this script (it'll be updated accordingly)"


function title_prnt_cmd () { yecho "$(_underline "$1" '=')"; }


title_prnt_cmd "# git handling (for updates and such)"
# ================================================================================================================================================


function update_with_git () {
    if [ -e "$CUSTOM_BASHRC_FOLDER/.git" ]; then
        dagecho "Detected that a git setup exists."
    else  # no git directory
        recho "git setup not detected."
        
        deprecated_folder_name="${CUSTOM_BASHRC_FOLDER}_old"

        dagecho "deprecating current folder by moving it to '_old': $deprecated_folder_name"
        mv "$CUSTOM_BASHRC_FOLDER" "$deprecated_folder_name"

        dagecho "cloning from git"
        git -C "$CUSTOM_BASHRC_FOLDER" clone "https://github.com/SirHexa10t/linux_bashrc.git" "$CUSTOM_BASHRC_FOLDER"

        [ ! -e "$CUSTOM_BASHRC_FOLDER/.git" ] && { errcho "Something is wrong, I still don't see the git configurations. Exiting!" ; exit ; }

        dagecho "Finished cloning. You should see the re-downloaded project in the previous one's location (remember to handle/clear-away the _old one)"
        becho "The current script might no longer be the same, so it'll exit now. Rerun the script, preferably on a new terminal."
        exit
    fi

    git -C "$CUSTOM_BASHRC_FOLDER" fetch  # update git setup's metadata so it'll know the status of remote
    if git -C "$CUSTOM_BASHRC_FOLDER" status -uno | grep 'Your branch is behind' | grep -q 'can be fast-forwarded'; then  # TODO - improve upon this. This might break once git would change its feedback messages.
        becho "Local repository is behind on branch \"$(git branch --show-current)\""
        git -C "$CUSTOM_BASHRC_FOLDER" pull \
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





title_prnt_cmd "# adding the sourcing of custom_bashrc"
# ================================================================================================================================================


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
    ["/etc/profile"]=$([ ! -f "/etc/profile" ] && echo "(NOT recommended - file doesn't exist in your setup)")
    ["/etc/profile.d/bashrc"]=$([ ! -f "/etc/profile.d/bashrc" ] && echo "(NOT recommended - file doesn't exist in your setup)")
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

    local q_ch="'"
    local appended_sourcing='
CUSTOM_BASHRC_FILE='"$CUSTOM_BASHRC_FILE"'
if [ -f "$CUSTOM_BASHRC_FILE" ]; then source "$CUSTOM_BASHRC_FILE" 
else echo "couldn'$q_ch't find custom_bashrc file at \"$CUSTOM_BASHRC_FILE\" , fix the file'$q_ch's permission-modifiers or fix the sourcing at \"$(readlink -f -- "$BASH_SOURCE")\"";  # print faulty file-dir, and this (current) file'$q_ch's location
fi
'
    local sourcing_check="CUSTOM_BASHRC_FILE=$CUSTOM_BASHRC_FILE"  # comparing multiple lines with special characters is a problem. This should do...

    if ! grep -q "$sourcing_check" "$location_chosen"; then
        becho "appending sourcing code to $(wecho $location_chosen)"
        echo "$appended_sourcing" | _sudo_if_necessary tee -a "$location_chosen" >/dev/null;  # add with sudo if permission is needed

        if grep -q "$sourcing_check" "$location_chosen"; then
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





title_prnt_cmd "# setting up utility files"
# ================================================================================================================================================


var_pick_quit='done'
utility_vars=($(printf '%s\n' "${!_UTILITY_FILE_MAP[@]}" | sort))
utility_vars+=("$var_pick_quit")

declare -A vars_explanation=(
    ['TESTS_FILE']="A file that gets sourced after bashrc finishes loading, so any tests you write in it will execute ASAP. For $(wecho "development") of this project."
    ['GARBAGE_OUTPUTS']="Default text-dump. There are aliases for tailing or writing into it. Mostly for $(wecho "development") of this project."
    ['TERMINAL_DIMS']="Sets the size of terminal (number of chars in height/width)."
    ['SUBDIR_MOUNTS_FILE']="Defines custom shortcuts for media-drives, like /music, or /projects"
    ['CREDENTIALS_OPENAI']="API key for OpenAI's ChatGPT 3.5 (paid-subscription). Used to query $(wecho "A.I.") through simple terminal commands."
    ['DISPLAY_ARRANGEMENT']="Screen rearrangement through a keybind. Useful if your OS messes up your screen layout at times."
    ['CUSTOM_TMPDIR']="Changes the tmp-files target-location from root (/) to your folder of choice (possibly on a large drive)"
    ['VM_IMG_PARTITION_UUID']="Partition auto-mounting, in case you use $(wecho "Virtual Machines"), and the VMs' storage is on a separate mountable partition"
    ['LOOKING_GLASS_CLIENT']="Enables custom_bashrc's usage of looking-glass (a $(wecho "Virtual Machine") tool)"
    ['STOCKS_FILE']="Used for stock-data querying (graphs)"
    ['MONERO_MINER']="Privacy/secrecy-oriented crypto-currency CPU miner"
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

    function install_monero_miner () {
        [ -n "$(_nonempty_folder_or_nothing "$directory_value")" ] && { _prompt_yn "Monero Miner is already installed, re-install?" || return 0; }

        local monero_pick_skip='skip'
        local latest_release_page=$(curl -s "https://api.github.com/repos/xmrig/xmrig/releases/latest")  # latest release data
        local download_urls=($(echo "$latest_release_page" | jq -r '.assets[].browser_download_url'))
        [ -z "$download_urls" ] && { errcho "Seems like the miner's webpage wasn't retrieved properly. Please try again later, in case it's a momentary internet connectivity issue"; return 1; }

        local url_chosen
        while [ -z "$url_chosen" ]; do
            declare -A xmrig_urls xmrig_filenames sha256_contents
            local index=1 index2=1 durl
            for durl in "${download_urls[@]}"; do
                local dfile=$(basename "$durl")
                [[ "$dfile" == SHA* ]] && {
                    [[ "$dfile" == "SHA256SUMS" ]] && sha256_contents="$(curl -sSL "$durl")"  # it's the file we want - get it.
                    continue;  # not a program, just SHA checksum
                }

                xmrig_filenames["$index"]="$dfile"
                xmrig_urls["$index"]="$durl"
                index=$((index+1))
            done
            # add skipping option at the end
            xmrig_filenames["$index"]="$monero_pick_skip"
            xmrig_urls["$index"]="$monero_pick_skip"

            local choices_dialog="$(
                becho "Which miner would you like to download? (pick number)"
                dabecho "Reminder: \"bionic\" is Ubuntu18.04 , \"focal\" is Ubuntu20.04 ; \"static\" means it has self-contained dependencies (recommended over non-static)"
                for ((index2=1; index2<=index; index2++)) do echo "$index2 ${xmrig_filenames[$index2]}"; done
                becho "============================================="
            )"
            echo "$choices_dialog"
            local number_picked
            read -p "choice-index: " number_picked  # Read the user's input
            [[ "$number_picked" =~ ^[0-9]+$ ]] && url_chosen="${xmrig_urls[$number_picked]}"  # if picked a number, set the pick

            local checksum_string="$(echo "$sha256_contents" | grep "${xmrig_filenames[$number_picked]}")"  # the appropriate entry out of the checksum text
        done

        # if isn't installed and user skipped anyway
        [[ -n "$(_nonempty_folder_or_nothing "$directory_value")" && "$url_chosen" = "$monero_pick_skip" ]] && { errcho "There's no existing installation and you don't want to download it now, so there's no way to proceed with the setup" ; return 1;}

        install_targz_from_url --url "$url_chosen" --app_name monero_miner --install_folder "$CRYPTO_PROGRAMS_DIR" --checksum256 "$checksum_string"  # --alias xmrig  # --alias is not necessary - a bashrc alias can replace it 

        # check that the files are alright
        [ ! -f "$directory_value/xmrig" ] && { errcho "Can't find the miner executable! Quitting."; return 1; }
        becho -p "Final checks for files' hash ($(recho "if there's no match, you should QUIT IMMEDIATELY! (ctrl+c)"))"
        checksum_sha256_entry "$directory_value/config.json" "$directory_value/SHA256SUMS"
        checksum_sha256_entry "$directory_value/xmrig" "$directory_value/SHA256SUMS"
    }

    function configure_monero_miner () {
        local config_file="$directory_value/config.json"

        # arg 1: field_name , arg 2: value_name
        function field_match_expression () {
            echo "\"$1\": $2,"
        }

        # arg 1: field_name , arg 2: replacement_value
        function replace_json_field () {
            local dq='"'  # double quotes
            [[ "$2" =~ ^-?[0-9]+$ || "$2" = 'true' || "$2" = 'false' ]] && dq=''  # value is a number or "true"/"false"- no quotes needed

            local before="$(field_match_expression "$1" "${dq}.*${dq}")"
            local after="$(field_match_expression "$1" "${dq}$2${dq}")"
            sed -i "s|$before|$after|1" "$config_file"  # replace first occurence
        }

        # arg 1: how we call the replaced term, arg 2: jquery, arg3: json_field_name
        function prompt_changing_field () {
            dagecho "Current $1: $(recho "$(jq -r "$2" "$config_file")")"
            local user_input
            read -p "Input $1 (leave empty to skip change): " user_input  # Read the user's input
            if [ -n "$user_input" ]; then
                replace_json_field "$3" "$user_input"
                dagecho "Done replacing $1"
            fi
        }

        dabecho -p "You need a wallet-address, unless you plan to do charity-mining. If you don't have one, go download from: $(wecho "https://www.getmonero.org/downloads/#cli") or $(wecho "https://web.getmonero.org/downloads/#gui")."
        echo "Notice: $(dabecho "You have an option to download the blockchain to your computer - it takes many hours, but you should do it at some point. You could start without it.")"
        hang

        becho -p "Choose a pool address. You can browse $(wecho "https://miningpoolstats.stream/monero") to see available offers and stats."
        dabecho -p "Recommended: $(cecho "p2pool.io") ; it has no pool fees, frequent pays, very low min-payout, but it requires extra setup (not covered here, yet). These are also solid choices: $(cecho "nanopool.org") , $(cecho "hashvault.pro") , $(cecho "supportxmr.com")"
        dagecho "Current pool mining address (domain+port): $(recho "$(jq -r '.pools[0].url' "$config_file")")"
        local pool_address
        read -p "Pool address; prepend your input with \"pool.\" (leave empty to skip change): " pool_address  # Read the user's input
        if [ -n "$pool_address" ]; then
            if [[ "$pool_address" =~ :[0-9] ]]; then
                dagecho "I was about to ask about the port number, but it seems to already be provided."
                replace_json_field 'url' "$pool_address"
            else
                becho "Choose a port number. Notice that starting difficulty is temporary, and doesn't matter much for long workloads"
                dabecho -p "Options: $(cecho "3333")/$(cecho "5555")/$(cecho "7777") : low/mid/high starting difficulty. $(cecho "9000") : SSL/TLS. $(cecho "8080") or $(cecho "80") or $(cecho "443") : http ports, could help bypass firewall."
                local port
                read -p "Port: " port  # Read the user's input
                replace_json_field 'url' "$pool_address:$port"
            fi
            dagecho "Done replacing URL"
        fi

        becho "Choose a payment address. It's a public address, i.e. isn't sensitive information."
        dabecho "In the GUI wallet it's in tab \"Receive\"; you might need to click \"Create new address\" there."
        prompt_changing_field 'payment address' '.pools[0].user' 'user'


        becho "Would you like to donate to XMRig? (note: XMRIG might set a minimum donation percentage regardless of your choice)"
        dagecho "Current donation amount: $(recho "$(jq -r '.["donate-level"]' "$config_file")%")"
        local donation_p
        read -p "Donation percentage (leave empty to skip change): " donation_p  # Read the user's input
        if [ -n "$donation_p" ]; then
            donation_p="${donation_p/%\%/}"  # make sure there's no '%' that the user may have added in.
            replace_json_field 'donate-level' "$donation_p"
            replace_json_field 'donate-over-proxy' "$donation_p"
            dagecho "Done replacing donation amount"
        fi

        becho "Would you like to name your worker? (easier to keep track if you mine with more than one machine)"
        prompt_changing_field 'worker name' '.pools[0].pass' 'pass'

        becho "Would you the UI to use colors? (true/false)"
        prompt_changing_field 'coloring' '.["colors"]' 'colors'

        becho "Use 1gb-pages? (true/false)"
        dabecho -p "If not enabled already by your OS, put this in grub ($(cecho "/etc/default/grub")): $(wecho 'GRUB_CMDLINE_LINUX="default_hugepagesz=2M hugepagesz=1GB hugepages=3"') , then run \`sudo update-grub\`, and reboot"
        prompt_changing_field '1GB-pages' '.randomx."1gb-pages"' '1gb-pages'


        becho "You manually can configure further (like defining more workers, or changing other fields), in this file: $config_file"

        # TODO - setup proxy?
        # TODO - setup default number of cores?

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
        'TERMINAL_DIMS')
            becho "Feature: set your terminal-window size on launch. Alternatively you can be also set through (but gets overriden by this feature): toolbar menu -> Edit > Preferences"
            local prompt_file_input="$(becho -p "This feature requires 2 inputs that'll be saved into $directory_value. First is number of rows (height), second is number of columns (width). 36 on 120 is a decent choice.")" 
            _prompt_input_to_file "$directory_value" "$prompt_file_input" '2'
        ;;
        'SUBDIR_MOUNTS_FILE')
            becho "Feature: Create convenient shortcuts into various directories in media partitions, for portability/access/order."
            becho 'Manually write command lines like these into the file: _shortaccess_folder --uuid b25fb935-b252-466f-8e45-63c8e7f62acf --subfolder "test/cache folder" --mountpoint "/temp_cache" --subfolder "logfiles" --mountpoint "/logs" --nomount'
            echo "$executable_file_warning ; will be turned into a read-only file in the future"  # TODO - make this file read-only and sort it out
            prompt_create_file
        ;;
        'CREDENTIALS_OPENAI')
            becho "Feature: Ask ChatGPT using a simple terminal command."
            local prompt_file_input="$(becho -p "This feature requires your API key (something like: sk-3wUxEyevvnEf9fP2xDn7T3BAbkFJmAOjhKEgH0t1ngXCP7c0). You can get it at: $(buecho https://platform.openai.com/account/api-keys)")"
            _prompt_input_to_file "$directory_value" "$prompt_file_input"
            chmod 600 "$directory_value"  # only user is allowed to read/write
        ;;
        'DISPLAY_ARRANGEMENT')
            becho "Easily restore display layout from saved configuration. Convinient in case your OS messes it up."
            local prompt_file_input="$(becho -p 'This feature requires screen-layout (example: HDMI-0: nvidia-auto-select +1920+1080, DP-0: nvidia-auto-select +1920+0, DP-2: nvidia-auto-select +3840+1080, DP-4: 1920x1080_240 +0+1080" ), which gets fed into an nvidia-settings command. Get this info through: '"$(dabecho 'NVIDIA Settings > X Server Display Configuration -> click on "Save to X Configuration File" -> click on "Show preview..."')"'. I don'"'"'t know how to configure for AMD or Intel, nor whether the display issue occurs on their cards')"
            _prompt_input_to_file "$directory_value" "$prompt_file_input"
        ;;
        'CUSTOM_TMPDIR')
            becho "Feature: Replace the temp-files dir (default is /tmp), using a symlink that points to a folder. It can improve available cache-writing space (could be critical for some tools/commands) or faster cache-read/write. custom_bashrc evaluates the symlink each time it's sourced, so it won't default to given folder unless it's available."
            prompt_rootdir_shortcut
        ;;
        'VM_IMG_PARTITION_UUID')
            becho "Feature: auto-mount the VMs' storage (usually .qcow2 files) partition when starting a VM through custom_bashrc's functions. If you have no such partition, don't set this."
            local prompt_file_input="$(becho -p "This feature requires writing the partition's UUID into: \"$directory_value\". You can find the UUID of your partition by running the cusrom command \"devs\"")"
            _prompt_input_to_file "$directory_value" "$prompt_file_input"
        ;;
        'LOOKING_GLASS_CLIENT')
            becho "Feature: Utilize looking-glass host-client (passthrough of image-stream from a VM-dedicated GPU), using the path to its binaries-file."
            local prompt_file_input="$(becho -p "This feature requires writing the LG-host-client's path into \"$directory_value\". If you don't have such a client and need one, there's a guide in one of my other git repositories. You can also follow the official guide: $(buecho "https://looking-glass.io/docs/B6/install/")")"
            _prompt_input_to_file "$directory_value" "$prompt_file_input"
        ;;
        'STOCKS_FILE')
            becho "Feature: keep track of selected stocks (get graphs in real-time)."
            local stop_str="thats_all"
            local prompt_file_input="Write stock symbols (and optionally price-point), one per line. Example: \"AMD\", or \"AMD 76.50\". When you're done, type: $(becho "$stop_str")"
            _prompt_input_to_file "$directory_value" "$prompt_file_input" '1000' "$stop_str"
        ;;
        'MONERO_MINER')
            becho "Feature: Manage your monero mining operations conveniently via Terminal. The miner works on CPU; there's a GPU version too, but as of the time of this writing, it's not worth considering."
            install_monero_miner && configure_monero_miner
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





title_prnt_cmd "# compiling local projects into binaries"
# ================================================================================================================================================

echo TODO  # TODO


title_prnt_cmd "# bringing in external tools and binaries"
# ================================================================================================================================================

echo TODO  # TODO



becho "All done."
becho "As stated before, you can rerun this script anytime."
