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
    # resets
    '<=bold_reset=>': '\033[22m', '<=italics_reset=>': '\033[23m',
    # differently-tagged resets for tag-processing logic
    '<=reset=>': '\033[0m', '<=hard_reset=>': '\033[0m', '<=total_reset=>': '\033[0m',
}

reset_tag = '<=reset=>'
processed_reset = colors_map[reset_tag].replace('\033', '\x1b')  # resets placed in previous runs
reset_either_regex = f'({reset_tag}|\x1b\[0m)'


def draw_formatted(text: str):
    whitespace_regex_raw = r'<=([0-9]+)WS=>'  # for picking out the number
    color_tag_regex = r'<=[a-zA-Z_]+=>'
    persistence_regex = rf'<=persist(({color_tag_regex})+)this=>'  # contains at least one tag

    color_tag_chain_regex = r'(<=[a-zA-Z_]+=>)+'
    processed_tag_chain_regex = '(\x1b\[[0-9]+m)+'
    persistence_regex = rf'<=persist({color_tag_chain_regex})this=>'
    whitespace_regex_raw = r'<=([0-9]+)WS=>'  # for picking out the number
    whitespace_regex_sub_raw = r'<=\d+WS=>'  # for picking out the entire tag

    lines = text.splitlines()
    processed_lines = []
    for line in lines:
        # apply whitespaces (replace tag with number-of-spaces)
        line = re.compile(whitespace_regex_raw).sub(lambda match: ' ' * int(match.group(1)), line)

        # tag persistence support (tag activates by default for the rest of the line)
        after_persistence_match = re.search(f'({persistence_regex})(.+)(?=$)', line)
        if after_persistence_match:
            matched_str = after_persistence_match.group()
            persisted_chain = re.search(f'{persistence_regex}', matched_str).group(0).removeprefix('<=persist').removesuffix('this=>')
            line = re.sub(f'({reset_either_regex})(?!.*{persisted_chain})', rf'{reset_tag}{persisted_chain}', line)  # attach the persisting tag after each reset tag, after the match
            line = re.sub(f'{persistence_regex}', persisted_chain, line, count=1)  # remove the matched persistence tagging

        # add resets, but only if there are tags involved
        if re.match(color_tag_chain_regex, line):
            # line = f'{reset_tag}{line}'
            prepend_res = ( lambda some_tag: some_tag in colors_map and f"{reset_tag}{some_tag}" or some_tag )
            def preres(tag):
                return f"{reset_tag}{tag}"


            # line = re.sub(f'({color_tag_chain_regex})',
            #     lambda match: f'{reset_tag}{match.group(1)}' if match.group(1) in colors_map else match.group(1),
            #     line
            # )
            line = re.sub(f'({color_tag_chain_regex})', lambda match: preres(match.group(1)), line)  # add resets before (groups of) color tags
            line = re.sub(f'({processed_tag_chain_regex})', rf'{reset_tag}\1', line)  # add resets before (groups of) applied color tags

            # TODO - remove? WS is its own thing, handled way-earlier
            # line = re.sub(f'({whitespace_regex_sub_raw})', rf'{reset_tag}\1', line)  # add resets before whitespace tags

            # clean up excess: delete resets from line start (they don't help there)  # TODO - remove? No longer the case.
            # while line.startswith(reset_tag): line = line.removeprefix(reset_tag)

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

    return text


class TagChain:
    """
    Represents an ordered chain of tags (string enclosed in '<=' and '=>'),
    allowing efficient addition of unique tags and conversion to/from string.
    """

    def __init__(self):
        from collections import deque

        self.tag_queue = deque()
        self._tag_set = set()  # Private, added for efficient lookup/retrieval

    def add_tag(self, new_tag):
        """
        Add a new tag to the chain if it is a valid tag.

        Parameters:
            new_tag (str): The tag to be added.

        Note:
            If the tag already exists in the chain, it won't be added again.
            Only valid tags present in the colors_map dictionary will be added.
        """
        if new_tag not in self._tag_set and new_tag in colors_map:
            self.tag_queue.append(new_tag)
            self._tag_set.add(new_tag)

    def to_string(self):
        """
        Convert all contained tags to a single "tag-chain" string.

        Returns:
            str: A string representation of all tags in the tag queue.
        """
        return "".join(self.tag_queue)

    @classmethod
    def from_string(cls, tag_string):
        """
        Create a TagChain instance from a string containing tags enclosed in '<=' and '=>'.

        Parameters:
            tag_string (str): The string containing tags.

        Returns:
            TagChain: An instance of TagChain containing tags from the input string.
        """
        instance = cls()
        tags = re.findall(r'(<=[a-zA-Z_]+=>)', tag_string)
        for tag in tags:
            instance.add_tag(tag)
        return instance


def draw_formatted2(text: str):

    whitespace_regex_raw = r'<=([0-9]+)WS=>'  # for picking out the number
    color_tag_regex = r'<=[a-zA-Z_]+=>'
    persistence_regex = rf'<=persist(({color_tag_regex})+)this=>'  # contains at least one tag

    # handle whitespace-tags (like <=13WS=>)
    text = re.compile(whitespace_regex_raw).sub(lambda match: ' ' * int(match.group(1)), text)

    lines = text.splitlines()
    processed_lines = []

    def apply_next_tag(line: str):
        pass

    def process_line(line: str):
        if re.search("", text):
            pass
        processed_lines.append(line)

    for current_line in lines:  # the formatting is per-line, so there's no real reason not to make this separation
        # Find persistent tags and implant their copies wherever applicable

        # for each chain-find, call a (recursive) function that looks for another chain (for recursive
        # chance, building the stack), and then for resets (including hard-resets, total-resets)
        process_line(current_line)


    return '\n'.join(processed_lines)



if __name__ == "__main__":
    if len(sys.argv) >= 2 and sys.argv[1]:  # arg 1 is this file
        if sys.argv[1] == '--print_available_colors':
            print(*colors_map.keys())
        else:   # regular run
            text_result = draw_formatted(sys.argv[1])
            print(f'{text_result}')  # "return" result (bash)
        exit(0)
    exit(1)


# Add tests below this line
import unittest


class TestYourFunction(unittest.TestCase):

    # same dictionary, but with "final results"; active coloring after being applied
    final_color_coding = {k: v.replace('\033', '\x1b') for k, v in colors_map.items()}
    # final-form reset
    fin_rst = final_color_coding[reset_tag]

    # calculate final form
    def fin(self, *args) -> str:
        strs = list(args)
        return ''.join([self.final_color_coding[f'<={tagstr}=>'] for tagstr in strs])

    def asrt(self, input_str: str, expected_output_str: str):
        result = draw_formatted(input_str)

        def get_string_forms():
            outputs_report = ''
            outputs_report += f"\ntext_input_______: {input_str}"      # input
            outputs_report += f"\nresult_as_usr_see: {result}"         # colored result, as the user would see
            visible_chars = repr(result).removeprefix("'").removesuffix("'")
            outputs_report += f"\nresult_ansi_expli: {visible_chars}"  # result w visible special characters
            plain_result = re.sub('\x1b', '', result)
            plain_expect = re.sub('\x1b', '', expected_output_str)
            outputs_report += f"\nsimpl_ansi_actual: {plain_result}"   # shortened-result
            outputs_report += f"\nsimpl_ansi_expect: {plain_expect}"   # shortened-expected
            return outputs_report

        self.assertEqual(expected_output_str, result, f'Failed!!\n{get_string_forms()}')

    def test_tag_chain(self):
        test_tag_string = "<=b_blue=><=bold=><=b_blue=><=uline=><=5WS=><=not_a_color=><=uline=>"
        tag_chain = TagChain.from_string(test_tag_string).to_string()
        self.assertEqual('<=b_blue=><=bold=><=uline=>', tag_chain)

    def test_formatting(self):
        fin_rst = self.fin_rst
        # get translation of tags (tag chains). starts with reset.
        fin = (lambda *args: fin_rst + ''.join([self.final_color_coding[f'<={tagstr}=>'] for tagstr in list(args)]))

        chain_tags = '<=green=><=bold=>'
        chain_values = f"{fin('green','bold')}"

        tests = {
            'nothing': (
                f"",
                f""),
            'no_tag': (  # see that text with no tags is left alone  # TODO
                f"a b c d e F g h i j k lmnop",
                f"a b c d e F g h i j k lmnop"),
            'one_word': (
                f"<=bold=><=green=>AAAAA<=reset=>",
                f"{fin('bold', 'green')}AAAAA{fin_rst}"),
            'deceptive_nontag_no_rst': (
                f"<=notapropertag=>AAAAA",
                f"<=notapropertag=>AAAAA"),
            'deceptive_nontag': (
                f"<=notapropertag=>AAAAA<=reset=>",
                f"<=notapropertag=>AAAAA{fin_rst}"),
            'mid_txt': (
                f"aa <=bold=><=italic=><=green=>AAAAA<=reset=>",
                f"aa {fin('bold', 'italic', 'green')}AAAAA{fin_rst}"),
            'mid_text+reset_at_beginning': (  # there might be a reason for that reset at start. Let it stay in result.
                f"aa <=reset=><=bold=><=italic=><=green=>AAAAA<=reset=>",
                f"aa {fin('bold', 'italic', 'green')}AAAAA{fin_rst}"),
            # 'preprocessed': (  # see that past-processed text is left alone  # TODO - currently adds an extra reset at the end...
            #     f"aa {fin_rst}{fin('bold', 'italic', 'green')}AAAAA{fin_rst}"
            #     f"aa {fin_rst}{fin('bold', 'italic', 'green')}AAAAA{fin_rst}"),
            'just_resets': (  # see that multiple consecutive resets are evaluated as one
                f"only one {reset_tag}{reset_tag}{reset_tag}{reset_tag} reset",
                f"only one {fin_rst} reset{fin_rst}"),
            # 'just_several_of_same_color': (  # see that multiple consecutive colors are evaluated as one  # TODO
            #     f"only one <=green=><=green=><=green=><=green=><=green=> color",
            #     f"only one {fin_rst}{fin('green')} color{fin_rst}"),
            # TODO - same color, but some are pre-processed
            'repeating_several_of_same_color': (  # see that multiple consecutive colors are evaluated as one  # TODO
                f"only one <=green=><=blue=><=green=><=blue=><=green=> color",
                f"only one {fin('green', 'blue')} color{fin_rst}"),
            'multi-line': (  # see that reset is added at the end of each line
                f"\n\nline1\n\nline2",
                f"\n\nline1{fin_rst}\n\nline2{fin_rst}"),
            'multi-line_tagged': (  # see that reset is added at the end of each line
                f"\n\n<=red=>line1\n\nline2",
                f"\n\n{fin('red')}line1{fin_rst}\n\nline2{fin_rst}"),
            'switching_styles': (  # switching style with no explicit reset in input
                f"this text is <=red=>red , <=green=>green<=reset=> , regular",
                f"this text is {fin('red')}red , {fin('green')}green{fin_rst} , regular{fin_rst}"),
            'switching_styles2': (  # several tags, has tag right at beginning
                f"<=red=>this text has <=blue=>few tags.",
                f"{fin('red')}this text has {fin('blue')}few tags.{fin_rst}"),
            'switching_styles3': (
                f"<=red=>this text has <=bold=><=blue=>few tags.",
                f"{fin('red')}this text has {fin('bold', 'blue')}few tags.{fin_rst}"),
            'whitespaces': (
                f"this text is has \"<=22WS=>\" 22 whitespaces",
                f"this text is has \"{fin_rst}                      \" 22 whitespaces{fin_rst}"),
            'whitespaces_w_reset': (  # seeing that the reset tag gets merged post spacing
                f"this text is has \"<=reset=><=22WS=>\" 22 whitespaces",
                f"this text is has \"{fin_rst}                      \" 22 whitespaces{fin_rst}"),
            'whitespaces_at_line_start': (
                f"<=2WS=><-2 spaces",
                f"  <-2 spaces{fin_rst}"),
            'persistence': (
                f"<=red=>R <=persist<=green=>this=>G {fin('blue')}B{fin_rst} G\nno_color",
                f"{fin('red')}R {fin('green')}G {fin('blue')}B{fin('green')} G{fin_rst}\nno_color{fin_rst}"),
        }

        for k, v in tests.items():
            print(f"running test \"{k}\"")
            self.asrt(input_str=v[0], expected_output_str=v[1])




        # self.asrt(input_str=f"<=red=>R <=persist{chain_tags}this=>G <=blue=><=dark=>B<=reset=> G\nno_color",
        #           outpt_str=f"{fin('red')}R {fin_rst}{chain_values}G {fin_rst}{fin('blue', 'dark')}B{fin_rst}{chain_values} G{fin_rst}\nno_color{fin_rst}")
        # self.asrt(input_str=f"<=persist<=bold=><=green=>this=>aaa {fin('blue')}BBBBBB{fin_rst} ccc",
        #           outpt_str=f"{fin('bold', 'green')}aaa {fin_rst}{fin('blue')}BBBBBB{fin_rst}{fin('bold', 'green')} ccc{fin_rst}")
        # self.asrt(input_str=f"<=persist<=bold=><=green=>this=>aaa {fin('blue')}bbb{fin_rst} ccc<=reset=>",
        #           outpt_str=f"{fin('bold', 'green')}aaa {fin_rst}{fin('blue')}bbb{fin_rst}{fin('bold', 'green')} ccc{fin_rst}")
        # self.asrt(input_str=f"unnecessary color at end <=bold=>",
        #           outpt_str=f"unnecessary color at end {fin_rst}")
        # self.asrt(input_str=f"<=green=>*<=reset=> ip addr  <=persist<=yellow=>this=># display own networking interfaces",
        #           outpt_str=f"{fin('green')}*{fin_rst} ip addr  {fin_rst}{fin('yellow')}# display own networking interfaces{fin_rst}")

