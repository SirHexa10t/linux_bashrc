#!/usr/bin/python3

"""
recolors text by replacing color tags with their appropriate color-codes
arg 1: tagged text ; unless it's "--print_available_colors" (print available tags)
"""

import sys
import re

colors_map = {
    # less standard colors
    '<=orange=>': '\033[38;5;208m', '<=brown=>': '\033[38;5;130m', 
    '<=pink=>': '\033[38;5;213m', '<=light_pink=>': '\033[38;5;219m', '<=very_light_red=>': '\033[38;5;210m',
    '<=skin_light=>': '\033[38;5;223m', '<=skin_pink=>': '\033[38;5;225m', '<=skin_pink_2=>': '\033[38;5;217m',
    '<=dark_brown=>': '\033[38;5;58m', '<=dark_brown_2=>': '\033[38;5;94m',
    '<=light_grey=>': '\033[38;5;254m',
    '<=neon_green=>': '\033[38;5;118m', '<=medium_green=>': '\033[38;5;77m',
    # colors
    '<=black=>': '\033[30m', '<=red=>': '\033[31m', '<=green=>': '\033[32m', '<=yellow=>': '\033[33m',
    '<=blue=>': '\033[34m', '<=purple=>': '\033[35m', '<=cyan=>': '\033[36m', '<=grey=>': '\033[37m',
    # bright colors (work like regular when stylized bold)
    '<=b_black=>': '\033[90m', '<=b_red=>': '\033[91m', '<=b_green=>': '\033[92m', '<=b_yellow=>': '\033[93m',
    '<=b_blue=>': '\033[94m', '<=b_purple=>': '\033[95m', '<=b_cyan=>': '\033[96m', '<=b_grey=>': '\033[97m',
    # highlights / markers (can be switched with text color using 7m). If you want to "hide" text as a solid block of color run the same colors for both (i.e. \033[43m\033[33m)
    '<=h_black=>': '\033[40m', '<=h_red=>': '\033[41m', '<=h_green=>': '\033[42m', '<=h_yellow=>': '\033[43m',
    '<=h_blue=>': '\033[44m', '<=h_purple=>': '\033[45m', '<=h_cyan=>': '\033[46m', '<=h_grey=>': '\033[47m',
    # bright backgrounds (highlights)
    '<=bh_black=>': '\033[100m', '<=bh_red=>': '\033[101m', '<=bh_green=>': '\033[102m', '<=bh_yellow=>': '\033[103m',
    '<=bh_blue=>': '\033[104m', '<=bh_purple=>': '\033[105m', '<=bh_cyan=>': '\033[106m', '<=bh_grey=>': '\033[107m',
    # stylizing
    '<=bold=>': '\033[1m', '<=dark=>': '\033[2m', '<=italic=>': '\033[3m', '<=uline=>': '\033[4m',
    '<=flicker=>': '\033[5m', '<=fast_flicker=>': '\033[6m', '<=switch_fg_bg=>': '\033[7m', '<=hidden=>': '\033[8m',
    '<=crossed=>': '\033[9m',
    # reset
    '<=bold_reset=>': '\033[22m', '<=italics_reset=>': '\033[23m', '<=reset=>': '\033[0m',
}

reset_tag = '<=reset=>'
processed_reset = colors_map[reset_tag].replace('\033', '\x1b')  # resets placed in previous runs
reset_either_regex = f'({reset_tag}|\x1b\[0m)'

def draw_formatted(text: str, is_testing=False):

    color_tag_chain_regex = r'(<=[a-zA-Z_]+=>)+'
    processed_tag_chain_regex = '(\x1b\[[0-9]+m)+'
    persistence_regex = rf'<=persist({color_tag_chain_regex})this=>'
    whitespace_regex_raw = r'<=([0-9]+)WS=>'  # for picking out the number
    whitespace_regex_sub_raw = r'<=\d+WS=>'  # for picking out the entire tag

    lines = text.splitlines()
    processed_lines = []
    for line in lines:
        # tag persistence support (tag activates by default for the rest of the line)
        after_persistence_match = re.search(f'({persistence_regex})(.+)(?=$)', line)
        if after_persistence_match:
            matched_str = after_persistence_match.group()
            persisted_chain = re.search(f'{persistence_regex}', matched_str).group(0).removeprefix('<=persist').removesuffix('this=>')
            line = re.sub(f'({reset_either_regex})(?!.*{persisted_chain})', rf'{reset_tag}{persisted_chain}', line)  # attach the persisting tag after each reset tag, after the match
            line = re.sub(f'{persistence_regex}', persisted_chain, line, count=1)  # remove the matched persistence tagging

        # add resets
        line = re.sub(f'({color_tag_chain_regex})', rf'{reset_tag}\1', line)  # add resets before (groups of) color tags
        line = re.sub(f'({processed_tag_chain_regex})', rf'{reset_tag}\1', line)  # add resets before (groups of) applied color tags
        line = re.sub(f'({whitespace_regex_sub_raw})', rf'{reset_tag}\1', line)  # add resets before whitespace tags

        # apply whitespaces (replace tag with number-of-spaces)
        line = re.compile(whitespace_regex_raw).sub(lambda match: ' ' * int(match.group(1)), line)

        # clean up excess: delete resets from line start (they don't help there)
        while line.startswith(reset_tag): line = line.removeprefix(reset_tag)
        line = re.sub(f'{color_tag_chain_regex}$', '', line)  # delete tags at end of line - they're useless.

        # add EOL reset
        if line and not line.endswith(reset_tag): line += reset_tag  # add reset before EOL (but not if it's already there)

        # apply the colors by swapping tags with their respective color-coding
        for k, v in colors_map.items():
            line = line.replace(k, v)

        # remove duplicate reset tags (both regular and processed - here they're all processed)
        while f'{processed_reset}{processed_reset}' in line:
            line = line.replace(f'{processed_reset}{processed_reset}', processed_reset)  # remove reset duplications

        processed_lines.append(line)

    text = "\n".join(processed_lines)

    print(f'{text}')  # "return" result (bash)

    if is_testing:
        print(repr(text))
        return f'{text}'


if len(sys.argv) >= 2 and sys.argv[1]:  # arg 1 is this file
    if sys.argv[1] == '--print_available_colors':
        print(*colors_map.keys())
    else:   # regular run
        draw_formatted(sys.argv[1])
else:  # having just 1 input arg means there's nothing to draw, so it's a test-run
    pass

    # def run_tests():
    #     final_color_coding = {k: v.replace('\033', '\x1b') for k, v in colors_map.items()}  # color-coding map (active coloring tags)
    #     fin_rst = final_color_coding[reset_tag]
    #
    #     # calculate final form
    #     def fin(*args) -> str:
    #         strs = list(args)
    #         return ''.join([final_color_coding[f'<={tagstr}=>'] for tagstr in strs])
    #
    #     def asrt(input_str: str, outpt_str: str):
    #         result = draw_formatted(input_str, is_testing=True)
    #         plain_result = re.sub('\x1b', '', result)
    #         plain_output = re.sub('\x1b', '', outpt_str)
    #         assert result == outpt_str, f'Failed.\nResult: {plain_result}\nExpect: {plain_output}'
    #
    #     asrt(input_str=f"<=bold=><=green=>AAAAA<=reset=>",
    #          outpt_str=f"{fin('bold', 'green')}AAAAA{fin_rst}")
    #     asrt(input_str=f"aa <=bold=><=italic=><=green=>AAAAA<=reset=>",
    #          outpt_str=f"aa {fin_rst}{fin('bold', 'italic', 'green')}AAAAA{fin_rst}")
    #     asrt(input_str=f"aa <=reset=><=bold=><=italic=><=green=>AAAAA<=reset=>",
    #          outpt_str=f"aa {fin_rst}{fin('bold', 'italic', 'green')}AAAAA{fin_rst}")
    #     asrt(input_str=f"only one {reset_tag}{reset_tag}{reset_tag}{reset_tag} reset",
    #          outpt_str=f"only one {fin_rst} reset{fin_rst}")
    #     asrt(input_str=f"\n\nline1\n\nline2",
    #          outpt_str=f"\n\nline1{fin_rst}\n\nline2{fin_rst}")
    #     asrt(input_str=f"this text is <=red=>red , <=green=>green<=reset=> , regular",
    #          outpt_str=f"this text is {fin_rst}{fin('red')}red , {fin_rst}{fin('green')}green{fin_rst} , regular{fin_rst}")
    #     asrt(input_str=f"this text is has \"<=22WS=>\" 22 whitespaces",
    #          outpt_str=f"this text is has \"{fin_rst}                      \" 22 whitespaces{fin_rst}")
    #     asrt(input_str=f"this text is has \"<=reset=><=22WS=>\" 22 whitespaces",
    #          outpt_str=f"this text is has \"{fin_rst}                      \" 22 whitespaces{fin_rst}")
    #     asrt(input_str=f"<=2WS=><-2 spaces",
    #          outpt_str=f"  <-2 spaces{fin_rst}")
    #     asrt(input_str=f"<=red=>this text has <=blue=>few tags.",
    #          outpt_str=f"{fin('red')}this text has {fin_rst}{fin('blue')}few tags.{fin_rst}")
    #     asrt(input_str=f"<=red=>this text has <=bold=><=blue=>few tags.",
    #          outpt_str=f"{fin('red')}this text has {fin_rst}{fin('bold', 'blue')}few tags.{fin_rst}")
    #     chain_tags = '<=green=><=bold=>'
    #     chain_values = f"{fin('green','bold')}"
    #     asrt(input_str=f"<=red=>R <=persist{chain_tags}this=>G <=blue=><=dark=>B<=reset=> G\nno_color",
    #          outpt_str=f"{fin('red')}R {fin_rst}{chain_values}G {fin_rst}{fin('blue', 'dark')}B{fin_rst}{chain_values} G{fin_rst}\nno_color{fin_rst}")
    #     asrt(input_str=f"<=red=>R <=persist<=green=>this=>G {fin('blue')}B{fin_rst} G\nno_color",
    #          outpt_str=f"{fin('red')}R {fin_rst}{fin('green')}G {fin_rst}{fin('blue')}B{fin_rst}{fin('green')} G{fin_rst}\nno_color{fin_rst}")
    #     asrt(input_str=f"<=persist<=bold=><=green=>this=>aaa {fin('blue')}BBBBBB{fin_rst} ccc",
    #          outpt_str=f"{fin('bold', 'green')}aaa {fin_rst}{fin('blue')}BBBBBB{fin_rst}{fin('bold', 'green')} ccc{fin_rst}")
    #     asrt(input_str=f"<=persist<=bold=><=green=>this=>aaa {fin('blue')}bbb{fin_rst} ccc<=reset=>",
    #          outpt_str=f"{fin('bold', 'green')}aaa {fin_rst}{fin('blue')}bbb{fin_rst}{fin('bold', 'green')} ccc{fin_rst}")
    #     asrt(input_str=f"unnecessary color at end <=bold=>",
    #          outpt_str=f"unnecessary color at end {fin_rst}")
    #     asrt(input_str=f"<=green=>*<=reset=> ip addr  <=persist<=yellow=>this=># display own networking interfaces",
    #          outpt_str=f"{fin('green')}*{fin_rst} ip addr  {fin_rst}{fin('yellow')}# display own networking interfaces{fin_rst}")
    # run_tests()


