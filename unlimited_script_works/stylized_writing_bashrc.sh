#!/bin/bash

# Alias and shorten usage of stylizing programs with simple bash functions


# Tag-coloring
# ============


# TODO - pass the args in a temp (RAM-only) file, so it won't complain about too many args (that's what python does...)
# recolors text by replacing color tags with their appropriate color-codes. Calls '_py_draw_formatted' to do that 
function _draw_formatted () {  ###tags: text-coloring
    if type -t _py_draw_formatted &> /dev/null ; then _py_draw_formatted "${@:-$(cat)}";
    else echo -e "$@"; fi
}

# Lists available colors (tags), and associated functions. Calls '_py_draw_formatted' for the list of colors 
function list_colors_available () {  ###tags: text-coloring
    local tags=$(
        local tag
        for tag in $(_py_draw_formatted --print_available_colors); do
            echo "<=$(_colored_echo "$tag" "${tag:2:-2}")=>" 
        done
    )
    echo "$tags"

    # TODO - list coloring commands
}

# comment-colorized echo - Colorize and reorganize in ways that make text easy to read. It's a bit like markdown, but with colors, and better compatibility with code readability
# -l (optional: include legend)
function commecho () {  ###tags: text-coloring
    local bullet_point_color='<=cyan=>'                                 # * item
    local bullet_point_sub_color='<=green=>'                            # *   sub-item
    local upper_line_continuing_arrow="$bullet_point_sub_color"         # char automatically added to sub-items: ↳
    local double_cat_line_color='<=bold=><=yellow=>'                    # >> title
    local single_cat_line_color='<=bold=><=blue=>'                      # > topic
    local tilda_cat_line_color='<=b_purple=>'                           # ~> table_topic
    local tilda_bra_line_color='<=italic=>'                             # ~< table_content
    local minus_bra_line_color='<=yellow=>'                             # -< table_content (contains emojis or other chars that don't look well with regular formatting)
    local plus_line_color='<=bold=><=cyan=>'                            # + remark
    local sharp_comment_color='<=yellow=>'                              #   # comment
    local double_slash_documentation_color="$sharp_comment_color"       #  // comment
    local colon_comment_color='<=yellow=>'                              #   : comment
    local sharp_documentation_color='<=green=>'                         # # comment
    local double_quotes_color='<=bold=><=red=>'                         # "something"       # also used for text between bra and ket ( <> )
    local tilted_quote_color='<=bold=><=orange=>'                       # `code piece`      # TODO - make code-marking persistant, but only until the closing '`', not until EOL
    local warning_color='<=flicker=><=uline=><=bold=><=red=>'           # oh_no!!
    local hyperlink_color='<=uline=><=b_cyan=>'                         # https://gg.ez
    # angled_brackets_color='<=italic=>'  # problematic when within a color that's already within persisting color  # TODO - fix (improve the coloring function)
    local reset='<=reset=>'

    while [[ $# -gt 0 ]]; do
        case "$1" in
        	'-l'|'--legend')
                local legend_items=(
                "$(_draw_formatted "${double_cat_line_color}topic")"
                "$(_draw_formatted "${single_cat_line_color}sub-topic")"
                "$(_draw_formatted "${plus_line_color}trick/tip")"
                "$(_draw_formatted "${sharp_comment_color}# comment/explanation")"
                "$(_draw_formatted "${sharp_documentation_color}# documentation")"
                "$(_draw_formatted "${double_quotes_color}\"specifics\"")"
                "$(_draw_formatted "${tilted_quote_color}\`code\`")"
                "$(_draw_formatted "${warning_color}\"WARNING!!\"")"
                # "$(_draw_formatted "${angled_brackets_color}<your-choice>")"
                )
                # Alternatively use this (with the command substitution, so IFS change won't stay) if you want tab-separation: $(IFS=$'\t'; echo "${legend_items[*]}
                # print list separated by comma+spaces into variable, and remove comma and any space after it
                echo -e "Legend: $(printf '%s , ' "${legend_items[@]}" | sed 's/,\s*$//' )"  # with an extra line (that's what the -e is there for), to separate the legend from the data
                shift
        		continue
        	;;
        	*)
                break  # no more options, now it's just data
        	;;
        esac
    done

    local formatted="${@:-$(cat)}"  # get all of the input, possibly from cat
    
    # improving readability of the following code:
    local ny='\(.*\)'  # "n-ything"
    local n_e='\(.*$\)'  # "en-ee"; "ANYthing until End". The braces need to be escaped, but not the dollar sign, it means "end"
    local cs='^``` '  # code-start (line starts with: '``` '), used to identify if later code-comment is applicable
    local cm="$tilted_quote_color"  # code-marking (the color-coding at the start of a code-line)
    
    # formatted=$(echo "$formatted" | sed -E "s/(<[^>]+>)/$angled_brackets_color\1$reset/g")  # recolor within '< >' (user-input). Needs to run first, to not modify the color tags
    
    #  TODO - add coloring for tables (in table rows, color-code numericals/units, and the words "yes" and "no")
    
    # TODO - implement positive/negative/neutral bullet-points (*+, *-, *%)
    
    # TODO - implement timeline stylizing (a line that goes from top to bottom with data-points within (spacing the data-points according to date or some other numerical))
    
    # TODO - replace info-indicators, from + to !. Then you can do +,-,% directly as variants of list items 
    
    # TODO - hide text between two "[]" (set same color in foreground and background)
    
        
    formatted="$(echo "$formatted" | awk '
                    in_code && !/^    / { in_code = 0 }                 # if entered code-mode, stay in it only if the spacing indicates youre still in the same block 
                    /^``` / { in_code = 1 }                             # enter code-mode (maybe a whole block)
                    in_code { sub(/^``` /, "*   "); print "'$cm'" $0 }  # prints, replacing the starting ``` (if found) with something else
                    !in_code { print $0 }'
                )"  # replace lines beginning with '``` ' (code-line) with a colored '*' and then 3 spaces   TODO - do better (maybe give it a different background and make the chars softer, not black/white; get inspiration from markdown)
    formatted=$(echo "$formatted" | sed "s/^$cm$ny  #$n_e$/$cm\1  ${sharp_comment_color}#\2/g")  # recolor starting from '  #'  (code-comments)            
    formatted=$(echo "$formatted" | sed "s|^$cm$ny  //$n_e$|$cm\1  ${double_slash_documentation_color}//\2|g")  # recolor starting from '  //'  (code-comments)
    
    formatted=$(echo "$formatted" | sed -E "s/(\`[^\`]*\`)/$tilted_quote_color\1$reset/g")  # recolor within ` ` (code)
    formatted=$(echo "$formatted" | sed -E "s/(https?:\/\/[^[:space:]]+)/$hyperlink_color\1$reset/g")  # recolor text that starts with 'http(s)://' (URLs)
    formatted=$(echo "$formatted" | sed -E "s/(\"[^\"]*\")/$double_quotes_color\1$reset/g")  # recolor within " " (specifics)
    # formatted=$(echo "$formatted" | sed -E "s/(<[^>]*>)/$double_quotes_color\1$reset/g")  # recolor within < > (specifics)  # TODO - this doesn't work because of tags nested within quotes (or other semi-persistent thing), so the tagging system needs a "stepping down" mechanic which allows a reset to the previous color
    formatted=$(echo "$formatted" | sed "s/^*  /${bullet_point_sub_color}*${reset} ${upper_line_continuing_arrow}↳${reset}/g")  # replace beginning '*  ' with a colored asterisk, a space, and a mildly colored arrow referencing line above (sub-bullet-points)
    formatted=$(echo "$formatted" | sed "s/^* /${bullet_point_color}*${reset} /g")  # replace beginning with '* ' with a colored '*' and then space  (bullet-points)
    formatted=$(echo "$formatted" | sed "s/^>> $n_e/${double_cat_line_color}➤ \1/g")  # recolor lines beginning with '>> ', and replace with a nice ascii char  (topics)
    formatted=$(echo "$formatted" | sed "s/^> $n_e/${single_cat_line_color}⇾ \1/g")  # recolor lines beginning with '> ', and replace with a nice ascii char  (sub-topics)
    formatted=$(echo "$formatted" | sed "s/^~> $n_e/${tilda_cat_line_color} \1/g")  # recolor lines beginning with '~>' (table-title)
    formatted=$(echo "$formatted" | sed "s/^~< $n_e/${tilda_bra_line_color} \1/g")  # recolor lines beginning with '~<' (table-content)
    formatted=$(echo "$formatted" | sed "s/^-< $n_e/${minus_bra_line_color} \1/g")  # recolor lines beginning with '-<' (table-content)
    formatted=$(echo "$formatted" | sed "s/^+ $n_e/${plus_line_color}&/g")  # recolor lines beginning with '+ '  (notes)
    formatted=$(echo "$formatted" | sed "s/^# /${sharp_documentation_color}&/g")  # recolor starting from '# '  (page's documentation)
    formatted=$(echo "$formatted" | sed "s/  # $n_e$/  ${sharp_comment_color}# \1/g")  # recolor starting from '  # '  (coded-line-comments)            
    formatted=$(echo "$formatted" | sed "s/  : $n_e$/  ${colon_comment_color}: \1/g")  # recolor starting from '  : '  (item-comments)
    formatted=$(echo "$formatted" | sed "s/[A-Z]\+![!]\+/${warning_color}&$reset/g")  # recolor capitalized words with at least two '!' exclamation marks
    _draw_formatted "$formatted"  # automatically puts the color reset at the ends of the lines
}


# TODO - detect if the terminal is bright instead of dark? If it's white, the colored prints should be darker; so you should remove the "\033[1m" prefix
# recolors all lines with specified color
# starting args: coloring tags to apply to all text ; all other args OR piped data is text to format
function _colored_echo () {
    local tags=''
    while [[ $# -gt 0 ]]; do
        if [[ "$1" =~ ^'<='.+'=>'$ ]]; then tags+="$1" && shift
        else break; 
        fi
    done
    # decorate tags as needed, if they exist
    [ -n "$tags" ] && tags="<^^^$tags^^^>"  # the ^^^ thing means persistence until EOF
    
    _draw_formatted "${tags}${@:-$(cat)}"
}


# echo in red
function recho () { _colored_echo "<=bold=><=red=>" "$@"; }
# echo in dark red
function darecho () { recho "<=dark=>" "$@" ; }
# echo in green
function gecho () { _colored_echo "<=bold=><=green=>" "$@" ; }
# echo in dark green
function dagecho () { gecho "<=dark=>" "$@" ; }
# echo in blue
function becho () { _colored_echo "<=bold=><=blue=>" "$@" ; }
# echo in dark blue
function dabecho () { becho "<=dark=>" "$@" ; }
# echo in cyan
function cecho () { _colored_echo "<=bold=><=cyan=>" "$@" ; }
# echo in yellow
function yecho () { _colored_echo "<=bold=><=yellow=>" "$@" ; }
# echo in orange
function orecho () { _colored_echo "<=bold=><=orange=>" "$@" ; }
# echo in white, bold
function wecho () { _colored_echo "<=bold=><=grey=>" "$@" ; }


# underlined echo
function uecho () { _colored_echo "<=bold=><=uline=>" "$@" ; }
# underlined echo in red
function ruecho () { recho "<=uline=>" "$@" ; }
# underlined echo in green
function guecho () { gecho "<=uline=>" "$@" ; }
# underlined echo in blue
function buecho () { becho "<=uline=>" "$@" ; }
# underlined echo in cyan
function cuecho () { cecho "<=uline=>" "$@" ; }
# underlined echo in yellow
function yuecho () { yecho "<=uline=>" "$@" ; }
# underlined echo in orange
function oruecho () { orecho "<=uline=>" "$@" ; }
# underlined echo in white
function wuecho () { wecho "<=uline=>" "$@" ; }


# echo into error output
function errcho () { recho "$@" >&2 ; }



# colors a specified substring within given text, like grep without line filtering
# -t/--text <text> (specify text to color, if it's not piped-in) ; -w/--word <word> (substring to color, no option needed if it's the only arg and text is piped-in) ; -c/--color <color-string> (see available colors in "_draw_formatted", default is red)
function color_word () {  ###tags: text-coloring
    local text word color='<=bold=><=red=>'
    if [[ $# -eq 1 && ! -t 0 ]]; then  # only 1 arg + streamed input. Given arg is the word that needs to be colored.
        word="$1"
    else  # "regular" case
        while [[ $# -gt 0 ]]; do
        	case "$1" in
        		'-t'|'--text')
        			text="$2"
        			shift 2
        			continue
        		;;
        		'-w'|'--word')
        			word="$2"
        			shift 2
        			continue
                ;;
                '-c'|'--color')
                    color="$2"
                    shift 2
                    continue
                ;;
        		*)
                    return  # received undefined argument
        		;;
        	esac
        done
    fi

    # If text is not provided via --text, and if standard input (piped data) exists : assign standard input to text
    [ ! -t 0 ] && text="$(cat)"  # if there's a stream, it's meant to go into text var.
    
    [ -z "$text" ] && return 1  # no text given
    [ -z "$word" ] && echo "$text" && return  # no word

    # insert tags around word, I makes it case-insensitive
    _draw_formatted "$(echo "$text" | sed -e "s/$word/$color&<=reset=>/gI")"
}




# ASCII-art
# =========

# the best function in this entire collection
function draw_hentai () {
    local HY='<=b_yellow=>'  # Hair Yellow
    local HYD='<=yellow=>'  # Hair Yellow Dark
    local S='<=reset=>'  # skin
    local SD='<=b_red=>'  # Skin Dark
    local EW='<=b_grey=>'  # Eyes white
    local W='<=grey=>'  # teeth White
    local WD=$S  # teeth White Dark
    local WS='<=dark=><=b_grey=>'  # White Shirt
    local WSD='<=b_black=>'  # White Shirt Dark
    local G='<=dark=><=red=>'  # Glove and eyebrows Brown
    local GD='<=b_black=>'  # Glove Brown Dark
    local D='<=dark=><=b_black=>'  # dark
    
    declare -A SPR # whitespaces that'll reset colors in drawing
    local num
    for num in {1..25}; do SPR[$num]="<=${num}WS=>"; done
    declare -A SP # whitespaces. just spaces.
    for num in {1..25}; do SP[$num]="$(_repeat_space_n_times ${num})"; done
    local WS_unconventional='⠀'

    # don't try to peek at the drawing here, go run the command in terminal
    local surprise
    read -r -d '' surprise << EOM
${SPR[17]}$HY⠰⡘⡸⢏$HYD⠼⠋$HY⡀⣱$HYD⢏⣾⣿⣿⣿⣿⣿⣿⣿⣧⠻⣿⣿⣷⣦$HY⡪⡳⠹⣷⣀⣀
${SPR[17]}$HY⢀⣽⣿⡶⣢⢸$HYD⡇⡏⣾⣿⠹⣿⣆⢻⣿⣇⢿⣿⣷⡙⠿⣿⣿⣿⣮$HY⠢⣽⡯⡑⠂
${SPR[17]}$HY⢘⣷⡱$HYD⣾⡟⠊⠧⠈⠟⢿⣧⢙⠻⣇⠙⢿⣎⢛⡻⠿⠦⠐⠩⠭⣭⣷⡜$HY⢷⡌⠄
${SPR[15]}$HY⠢⠴⣾⣛$HYD⢱⣿⡑$S⡀$HYD⡀⠄$S⢸$SD⢧$HYD⠹⠸⠁⣈${SP[1]}⣰$SD⠌⣥$HYD⡈⢙⣿⠻⢛$SD⠭$HYD⠻⣿⡄$HY⡸⣧
${SPR[16]}$HY⠠⢪⣇$HYD${SP[1]}⣇⢳${SP[1]}$S⣇⢻⡄$HYD⠆⡁$EW${SP[2]}$HYD⠁$EW⣀$SD${SP[1]}⢾⣿⣿⣶${SP[1]}⣰⢁⡛⠇$HYD⢿⣿$HY⢸⡇
${SPR[16]}$HY⠁⢸⢻$HYD⡰$S${SP[1]}$G⠈⠐$S⠩⠸⣄${SP[1]}⠢⣀$EW⠃$S⣀⣴⣿⣷⣮$SD⢻⣿⢠⡟⠠⢛⡘$HYD⢸⡏$HY⡞⠤
${SPR[17]}$HY⢀⡌$HYD${SP[1]}⡴⣆$EW⠠$S${SP[1]}⣠⣷⣵⣿⣿⣿⣿⣿⣿⣿⣿$SD⣿⣿⣿⡿⠒⢅$HYD⣴⣿⠃$HY⢎⢩⡄⡀
${SPR[20]}$HYD⠃⠿$S⢸⣿⡇⢙⠿⠛⣻⣿⣿⣿⡿⣿⡇$SD⣿⣿⣿⡇$HYD⠰⣾⣿⣿$HY⢸⠈⠃⠉⠁
${SPR[23]}$S⢿⣿⡶⠬⡾⠿⣛⣛⢛⢰⣿⡇$SD⣿⣿⣿⡇⢧$HYD⡉⠻⢿$HY⠂⢃
${SPR[23]}$S⠈⢻⣿⣆$W⠋⠉$D⣀⣀⠂$S⣾⣿$SD⢸⣿⣿⠛${SP[1]}⠸⠁⠆$HYD⣾⣦$HY⡲⡒⠂
${SPR[25]}$S⠙⢿⣇$W⠘⠻⢕$S⣴⣿⡏$SD⣾⠟⣡⠆⠄${SP[3]}$HYD⠹⠟⠃$HY⢈⠷⡀
${SPR[11]}$G⣀⣀⣠$S⢠⡀${SPR[10]}$S⠈⢻⣟⠫⢍⣰⡿$SD⢐⣥⣾⠟${SP[9]}$HY⢠⠈
${SPR[8]}$G⣠⠠⠴⠦$S⣻⣿⠌$SD⣴${SP[1]}⣐⣺⣿⠷${SPR[7]}$S⠛⠿⠟$SD⣩⣴⣿⠿⠁${SP[10]}$HY⢸⡆
${SPR[6]}$G⣀⡌⢦⡙$S⠰⠿⠟$SD⢁⢡$GD⣾$SD⠸⣿⠏${SPR[8]}$WS⢤⣶⣆$SD⠇⣼⠟⠁${SP[1]}$SD⢀⣀⣀⡤⠤⣤$WSD⣶⣶⠆${SP[2]}$HY⠸⠇
${SPR[5]}$G⣼⢻⡟⣪$S⡘⠿$SD⠉⣸$GD⡿⠘⠋${SPR[9]}$WS⡄⠦⠠⡀$WSD⠹⡄${SP[2]}⠴⣾⠿⠙⠉⠁${SP[1]}⢹⣿⡇
${SPR[3]}$G⣠⣰⣿⠄$SD⠘⣿⠍$GD⢰⢣⡿⠃${SPR[11]}$WS⢇⢠⢀$WSD${SP[2]}⠁⣄${SP[1]}⢀⣰⡀⢀⠤⡆⠠${SP[1]}⠃${SP[2]}⢀⣴⣶⣿⢿⣿⣿⣿⡶⠖⠒⠢
${SPR[1]}$G⣀⣿⠟$GD⣴⣿⣿⣦⡣⠡${SP[1]}⠛${SPR[9]}$WS⣀⣠⣭⣭⣵⣮⡙⢾⣷⡆$WSD⠐⣿⣷⣾⣿⣿⣗⡤⡴⠐${SP[1]}⣠⣴⣿⣿⣿⣿⡿⠟⠋
$G⣼⡟$GD⣸⣿⣿⠋⠁${SPR[8]}$WS⣀⣬⣶⣾⣿⣿⣿⣿⣿⣿⣿⡿⡊⢋⣉⣬⣬$WSD⡰⣿⣿⡟⠋⢁⣠⣶⣿⣿⣿⣿⣿⣿⠫⠃${SPR[8]}$WSD⣀⣤⣾⣿
${SPR[2]}$GD⠈⠉${SPR[8]}$WS⢀⣴⢇⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠏⢠⣾⣿⣿⣿⣿⣿⣎$WSD⠻⣿⣿⣿⣿⣿⣿⣿⣿⡿⠿⠇${SPR[7]}$WSD⢀⣤⣾⣿⣿⣿⢿
\x59\x4f\x55\x20\x57\x45\x52\x45\x20\x45\x58\x50\x45\x43\x54\x49\x4e\x47\x20\x4c\x45\x57\x44\x53\x2c\x20\x42\x55\x54\x20\x49\x54\x20\x57\x41\x53\x20\x4d\x45\x2c\x20\x44\x49\x4f\x21
EOM

    _draw_formatted "$surprise"
}




# ASCII Animation
# ===============

# short "LET'S GO" animation. -v : verbose (debugging)
function animate_lets_go () {
    # Define the animation frames as an array of strings
    local frame1="
⠀⢀⣤⡤⣄⠀
⣴⢿⢿⢳⢛⠂
⠿⣘⢱⣦⡤⠃
⣦⣿⡏⠉⢢⠀
⠈⣷⣞⣟⡅⠀
"
    local frame2="
⠀⣠⣴⠖⣦⠀
⣾⢻⠻⠻⠩⡁
⠻⣮⣸⣿⠶⠁
⣶⣟⠀⢀⣵⣦
⠛⠁⠉⠁⠙⠁
"

    local banner="
    ####      *########  ##########  ##  #######*      #########   ,####n###  
   ,###       ##r          a##     ##n ###/         ,####         ####    ###)
   ###       #######(     ###         /#####,      ,###/  o####  ####     ####
  ##b       *###         ###             d####     ####    *### .###,    #### 
 ######### ,########    ###          #######/      #####_####/   ####_#####   
"

    # there are spaces here, in case your IDE doesn't show you that easily

    # draw runner "spreading" the banner by having it revealed behind him, than runner "disappears" into an invisible wall
    # how it's done:
    # runner is "pushed" by an ever-extending banner from 1 to full length
    # once banner is full length, runner is "pushed" by an extra invisible window of spaces
    # the invisible wall appears after the [full width of the banner + invisible window] , so that the window would keep pushing the runner past it 

    # ----------- Define sprites, and terminal limits -----------
    local is_verbose
    [[ "$@" =~ ^"-v"$ ]] && is_verbose='true'

    local terminal_width=$(tput cols)
    local terminal_height=$(tput lines)
    local banner_width=$(sed -n '2p' <<< "$banner" | wc -c)  # width of banner, going by 2nd line
    local runner_width=$(sed -n '2p' <<< "$frame1" | wc -c)  # width of runner, going by 2nd line of the first frame
    local sprite_height=$(($(echo "$banner" | wc -l)-1))  # same for all sprites involved

    local runner_frames=("$frame1" "$frame2")
    local runner_frames_count="${#runner_frames[@]}"

    # check that the screen is wide enough
    local necessary_terminal_width=$((banner_width + runner_width))
    if ((necessary_terminal_width > terminal_width)); then errcho "Cancelled animation-playing; your terminal needs to be wider." ; return 1 ; fi
    # check that the screen is high enough
    local necessary_terminal_height=$sprite_height
    if ((necessary_terminal_height > terminal_height)); then errcho "Cancelled animation-playing; your terminal needs to be taller." ; return 1 ; fi
    # make sure that there's vertical space for the ascii animation
    if [ -n "$is_verbose" ]; then
        clear  # make more room for the extra prints
    else
        # make the necessary room needed for the animation
        local el
        for ((el=1; el<=$necessary_terminal_height; el++)); do echo ; done  # put new lines below
        tput cuu $necessary_terminal_height  # go back up, to make future use of added lines
    fi


    # ----------- Define iteration variables -----------
    local progress_speed=3  # positions moved in each iteration (minimum 1)
    local total_run=$terminal_width  # $(( banner_width + window_width ))  # the total run distance (not drawing beyond that). Runner starts fading at $((total_run - runner_width))
    local iter_time=0.035  # iteration time in seconds
    local min_key_input_time=0.003  # minimum time to listen to user input

    local exit_key  # save the pressed key that stopped the animation

    # ----------- Animation iteration -----------
   
    echo -ne "\033[s"  # Save cursor position

    # arg 1: n (width to reveal) , arg 2: text-block to partially reveal
    function _reveal_first_n_cols () {
        [ "$1" -le 0 ] && return  # negative or 0 width wanted. Return nothing.
        local max_width=$(sed -n '2p' <<< "$2" | wc -c)  # width of sprite, going by 2nd line
        
        if [ "$1" -lt "$max_width" ]; then echo "$2" | awk '{print substr($0, 1, n)}' n=$1;  # partially reveal the text
        else echo "$2";  # revealing-width is too big, just echo back everything
        fi
    }

    # d is total distance progressed
    local d runner_i
    for ((d=1, runner_i=0; d<=$total_run; d+="$progress_speed" , runner_i++ , runner_i%=runner_frames_count)); do
        local time_start=$(date +%s.%N)

        local window_dist=$((d - banner_width))  # extra distance of runner past banner, minimum is 0 (starts counting up once banner is full)
        local runner_width_still_visible=$((total_run - d))  # how much of the runner gets drawn (drawn fully until reaching the wall).

        local banner_sprite=$(_reveal_first_n_cols "$d" "$banner")
        local extra_dist_sprite=$(_repeat_whitespace_rows "$sprite_height" "$window_dist")
        local cut_back_runner_sprite=$(_reveal_first_n_cols "$runner_width_still_visible" "${runner_frames[$runner_i]}")  # runner disappears into an invisible wall, by drawing less of it as it runs further away
        _side_by_side --glued --no_padding "$(gecho "$banner_sprite")" "$extra_dist_sprite" "$cut_back_runner_sprite"
        
        [ -n "$is_verbose" ] || echo -ne "\033[u"  # Restore cursor position (but not if you're debugging - you need to see each frame)

        # TODO - shorten iteration time (optimize)
        # wait for the rest of the iteration
        local time_remaining=$( echo "$time_start + $iter_time - $(date +%s.%N)" | bc )
        local key_press_wait=$(max "$time_remaining" "$min_key_input_time")
        read -t "$key_press_wait" -N 1 exit_key && break

        [ -n "$is_verbose" ] && echo "banner_width: $banner_width , runner_width: $runner_width , total_run: $total_run"
        [ -n "$is_verbose" ] && echo "iteration took $( echo "$(date +%s.%N) - $time_start" | bc )'s , key_press_wait: ${key_press_wait}s , distance-window width: $window_dist , distance ran: $d , distance remaining: $runner_width_still_visible"
        
    done

    # dim the banner (and progress the cursor) by pasting over it at-once
    echo -ne "\033[u"  # Restore cursor position
    local banner_final=$(dagecho "$banner")  # recolored banner
    local space_window_final=$( _repeat_whitespace_rows "$sprite_height" $(($total_run - $banner_width)) )
    _side_by_side "$banner_final" "$space_window_final"
    if [ -z "$exit_key" ]; then  # if the user didn't terminate manually; there's time to do more animations
        # draw over again
        echo -ne "\033[u"  # Restore cursor position
        local erase_final=$( _repeat_whitespace_rows "$sprite_height" "$total_run" )  # TODO - replace with the ascii title of tmux window, if provided
        echo -e "$erase_final" | pv -qL 200  # erase line by line
        echo -ne "\033[u"  # Restore cursor position  # TODO - make this conditional; only if used only whitespaces (deleted the banner), go back.
    fi

}


