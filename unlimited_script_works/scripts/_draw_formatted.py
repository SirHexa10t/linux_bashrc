#!/usr/bin/python3

"""
recolors text by replacing color tags with their appropriate color-codes
    "--print_available_colors" - print available tags and exit
    any-args: text to be processed; can be provided via arg, args, stream, pipe. Not as file.
"""


import sys
import re
from collections import deque
from enum import Enum, auto


class Persistence(Enum):
    PERSISTENCE_EOL = ('^^',)
    PERSISTENCE_EOF = ('^^^',)

    def substr(self):
        return self.value[0]

    def apply_to(self, tagging, escaped=False):
        substr = self.substr()
        if escaped:
            substr = re.escape(substr)
        return f"<{substr}{tagging}{substr}>"

    @staticmethod
    def identify_persistence(tagging):
        for persist in reversed(Persistence):  # from end to start
            start = f"<{persist.substr()}"
            end = f"{persist.substr()}>"
            if tagging.startswith(start) and tagging.endswith(end):
                return persist
        return None

    @classmethod
    def strip(cls, tagging):
        """remove the persisting part (like wire stripping)"""
        identified = cls.identify_persistence(tagging)
        if identified:
            substr = identified.substr()
            return tagging.removeprefix(f"<{substr}").removesuffix(f"{substr}>"), identified
        return tagging, None


class TagIndex:

    # used \033 in the past, then moved to \x1b . Not sure if it breaks anything. Can also write instead: 
    color_map = {
        # less standard colors
        '<=orange=>': '\x1b[38;5;208m', '<=brown=>': '\x1b[38;5;130m',
        '<=pink=>': '\x1b[38;5;213m', '<=light_pink=>': '\x1b[38;5;219m', '<=very_light_red=>': '\x1b[38;5;210m',
        '<=skin_light=>': '\x1b[38;5;223m', '<=skin_pink=>': '\x1b[38;5;225m', '<=skin_pink_2=>': '\x1b[38;5;217m',
        '<=dark_brown=>': '\x1b[38;5;58m', '<=dark_brown_2=>': '\x1b[38;5;94m',
        '<=light_grey=>': '\x1b[38;5;254m',
        '<=neon_green=>': '\x1b[38;5;118m', '<=medium_green=>': '\x1b[38;5;77m',
        # colors
        '<=black=>': '\x1b[30m', '<=red=>': '\x1b[31m', '<=green=>': '\x1b[32m', '<=yellow=>': '\x1b[33m',
        '<=blue=>': '\x1b[34m', '<=purple=>': '\x1b[35m', '<=cyan=>': '\x1b[36m', '<=grey=>': '\x1b[37m',
        # bright colors (work like regular when stylized bold)
        '<=b_black=>': '\x1b[90m', '<=b_red=>': '\x1b[91m', '<=b_green=>': '\x1b[92m', '<=b_yellow=>': '\x1b[93m',
        '<=b_blue=>': '\x1b[94m', '<=b_purple=>': '\x1b[95m', '<=b_cyan=>': '\x1b[96m', '<=b_grey=>': '\x1b[97m',
        # highlights / markers (can be switched with text color using 7m).
        # If you want to "hide" text as a solid block of color run the same colors for both (i.e. \x1b[43m\x1b[33m)
        '<=h_black=>': '\x1b[40m', '<=h_red=>': '\x1b[41m', '<=h_green=>': '\x1b[42m', '<=h_yellow=>': '\x1b[43m',
        '<=h_blue=>': '\x1b[44m', '<=h_purple=>': '\x1b[45m', '<=h_cyan=>': '\x1b[46m', '<=h_grey=>': '\x1b[47m',
        # bright backgrounds (highlights)
        '<=bh_black=>': '\x1b[100m', '<=bh_red=>': '\x1b[101m', '<=bh_green=>': '\x1b[102m',
        '<=bh_yellow=>': '\x1b[103m', '<=bh_blue=>': '\x1b[104m', '<=bh_purple=>': '\x1b[105m',
        '<=bh_cyan=>': '\x1b[106m', '<=bh_grey=>': '\x1b[107m',
        # stylizing
        '<=bold=>': '\x1b[1m', '<=dark=>': '\x1b[2m', '<=italic=>': '\x1b[3m', '<=uline=>': '\x1b[4m',
        '<=flicker=>': '\x1b[5m', '<=fast_flicker=>': '\x1b[6m', '<=switch_fg_bg=>': '\x1b[7m', '<=hidden=>': '\x1b[8m',
        '<=crossed=>': '\x1b[9m',
        # partial resets
        '<=bold_reset=>': '\x1b[22m', '<=italics_reset=>': '\x1b[23m',
    }

    resets_map = {  # differently-tagged resets for tag-processing logic
        '<=reset=>': '\x1b[0m',  # regular reset
    }

    reset_tag = list(resets_map.keys())[0]  # get the default value dynamically (no code duplication / magic strings)
    reset_eol_tag = Persistence.PERSISTENCE_EOL.apply_to(reset_tag)
    reset_processed = resets_map[reset_tag]

    @staticmethod
    def _construct_persistent_dict(some_dict):
        return dict(
            **some_dict,
            **{Persistence.PERSISTENCE_EOL.apply_to(key): value for key, value in some_dict.items()},
            **{Persistence.PERSISTENCE_EOF.apply_to(key): value for key, value in some_dict.items()},
        )

    persisting_colors_map = _construct_persistent_dict(color_map)
    resets_map = _construct_persistent_dict(resets_map)
    resets_map[reset_processed] = reset_processed  # adding for the quick lookup...


    @classmethod
    def is_valid_tag(cls, tag: str):
        return tag in cls.persisting_colors_map

    @classmethod
    def is_valid_reset(cls, tag: str):
        return tag in cls.resets_map


class Matcher:

    @staticmethod
    def _create_w_persist_search(regex_loolup):
        return [
            regex_loolup,
            Persistence.PERSISTENCE_EOL.apply_to(regex_loolup, escaped=True),
            Persistence.PERSISTENCE_EOF.apply_to(regex_loolup, escaped=True),
        ]

    whitespace_regex_raw = r'<=([0-9]+)WS=>'  # for picking out the number in space-tags

    single_tag_regex = r"<=[0-9a-zA-Z_]+=>"
    tag_chain_regexes = _create_w_persist_search(f"({single_tag_regex})+")
    reset_regexes = _create_w_persist_search(TagIndex.reset_tag) + ['\\x1b\\[0m']  # work with already-processed resets

    escaped_reset_processed = re.escape(TagIndex.reset_processed)
    repeating_reset_regex = rf"{escaped_reset_processed}({escaped_reset_processed})+"

    @staticmethod
    def _contain_str_in_list(maybe_string):
        return [maybe_string] if isinstance(maybe_string, str) else maybe_string

    @staticmethod
    def split_by_matches(patterns, text):
        """Splits the text based on matches of the pattern, returning a list of segments."""

        if not text:
            return []

        patterns = Matcher._contain_str_in_list(patterns)  # support multiple patterns by order, but also allow just one

        segments = []
        iter_index = 0
        matches = True  # just here to get the loop started.
        while matches:
            # match all patterns the rest of the text (handled one by one, in case of overlapping substring shenanigans)
            matches = [match for pattern in patterns if (match := re.search(pattern, text[iter_index:])) is not None]
            if matches:  # if found anything, pick the earliest match
                earliest_match = min(matches, key=lambda m: m.start())
                if text_before_match := text[iter_index:iter_index + earliest_match.start()]:  # could be ''
                    segments.append(text_before_match)
                segments.append(earliest_match.group())  # Add the matched text
                iter_index += earliest_match.end()  # for next iteration

        segments.append(text[iter_index:])  # Add the remains after last match

        return segments

    @staticmethod
    def exact_match(patterns, text):
        patterns = Matcher._contain_str_in_list(patterns)  # support multiple patterns by order, but also allow just one
        return any(re.fullmatch(pattern, text) for pattern in patterns)


class TagChain:
    """
    Represents an ordered chain of tags (string enclosed in '<=' and '=>'),
    allowing efficient addition of unique tags and conversion to/from string.
    """

    def __init__(self, tag_string):
        self.tag_queue = deque()
        self.rejects_queue = deque()  # tag-like but not tags  TODO - better finding, rather than rejecting late-stage
        _tag_set = set()  # Private, added for efficient lookup/retrieval

        stripped, persist = Persistence.strip(tag_string)
        tags = re.findall(f"({Matcher.single_tag_regex})", stripped)
        for tag in tags:
            if tag not in _tag_set:
                if TagIndex.is_valid_tag(tag):
                    self.tag_queue.append(tag)
                    _tag_set.add(tag)
                else:
                    self.rejects_queue.append(tag)
        self.persist = persist
        self.encoded = ''.join([TagIndex.color_map.get(key, "") for key in self.tag_queue])


class TagNodeType(Enum):
    PLAIN_TEXT = auto()
    VALID_TAG = auto()
    PREPROCESSED_TAG = auto()
    RESET = auto()


class TagNode:

    def __init__(self, actual_text, node_type, persistence=None):
        self.actual_text = actual_text
        self.node_type = node_type
        self.persistence = persistence


# A "singleton" session
class ChainsStack:

    def __init__(self):
        self.stack: deque[TagChain] = deque()

    def append_and_get_signature(self, chain_string):
        self.stack.append(TagChain(chain_string))
        return self.current_signature_or_empty()

    def _peek_stack(self):
        if self.stack:
            return self.stack[-1]
        return None

    def _current_not_persisting(self):
        return self._peek_stack() and not self._peek_stack().persist

    def _is_current_w_persist(self, persistence):
        return self._peek_stack() and self._peek_stack().persist == persistence

    def current_encoded_or_empty(self):
        if self.stack:
            return self.stack[-1].encoded
        return ''

    def current_signature_or_empty(self):
        """get post-process (dropped duplications) signature
        Includes the rejected tags (won't be in effect), and the coded version of the tags,
        preceded by reset for a clean start; so that different styles won't blend (like italics and red-color)"""
        ret_str = ''
        if self.stack and self.stack[-1].rejects_queue:
            ret_str = ''.join(self.stack[-1].rejects_queue)  # whatever it is, have it sent too, don't "swallow" it
        if self.stack and self.stack[-1].tag_queue:
            ret_str = TagIndex.reset_processed + ret_str + self.stack[-1].encoded
        return ret_str

    def persist_on_reset(self, reset_string=None) -> str:
        """get the current reset possibly with persisting tag-chain, according to stack-status and reset type"""
        reset_persist_level = Persistence.identify_persistence(reset_string)

        if reset_persist_level == Persistence.PERSISTENCE_EOF:  # total reset, dump stack, return empty
            self.stack.clear()
        elif reset_persist_level == Persistence.PERSISTENCE_EOL:  # hard-reset; pop until (incl.) first EOL-persistent
            # dump all non-persistent, then one EOL-persistent (if any)
            while self._current_not_persisting():
                self.stack.pop()
            if self._is_current_w_persist(Persistence.PERSISTENCE_EOL):
                self.stack.pop()
        elif reset_string == TagIndex.reset_tag:  # regular reset, doesn't affect persistent chains
            if self._current_not_persisting():  # no persistence - "reset" last (else, any persistence means no change)
                self.stack.pop()
        elif reset_string == TagIndex.reset_processed:  # Other run's reset. Shouldn't affect our stack.
            pass
        # otherwise, no reset was given, no more popping. Return what's relevant.
        return f"{TagIndex.reset_processed}{self.current_encoded_or_empty()}"


def draw_formatted(text: str):

    # handle whitespace-tags (like <=13WS=>)
    text = re.compile(Matcher.whitespace_regex_raw).sub(lambda match: ' ' * int(match.group(1)), text)

    chain_stack = ChainsStack()  # handles persistence
    lines = text.splitlines()
    processed_text = []

    def editing_at_eol(line):
        # add reset at the end of the line, but not in empty lines
        if line and processed_text and processed_text[-1] != TagIndex.reset_processed:
            # line ended, that's basically a EOL reset
            encoded = chain_stack.persist_on_reset(TagIndex.reset_eol_tag)
            processed_text.append(encoded)
        processed_text.append('\n')  # add newlines between lines

    def post_processing_cleanup():
        if processed_text and processed_text[-1] == '\n':  # remove last-added newline
            processed_text.pop()

        # add reset at the end (if it's not there); the marking stops past this function's output (always)
        if len(processed_text) == 0 or (processed_text and processed_text[-1] != TagIndex.reset_processed):
            processed_text.append(TagIndex.reset_processed)

        # TODO - do tag-duplication elimination here

    for current_line in lines:  # formatting is (mostly) per-line, so there's no real reason not to make this separation
        # first separate all the rests, so they won't blend with other adjacent tags within chains
        for reset_segmented in Matcher.split_by_matches(Matcher.reset_regexes, current_line):
            # check here rather than after further separations, for efficiency
            if TagIndex.is_valid_reset(reset_segmented):  # is reset
                processed_text.append(chain_stack.persist_on_reset(reset_segmented))
                continue

            # find coloring/stylizing tags (including chains of them)
            for tag_segmented in Matcher.split_by_matches(Matcher.tag_chain_regexes, reset_segmented):
                if Matcher.exact_match(Matcher.tag_chain_regexes, tag_segmented):  # a bunch of tags (no reset)
                    encoded = chain_stack.append_and_get_signature(tag_segmented)
                    processed_text.append(encoded)
                else:  # some text... nothing to do with it
                    processed_text.append(tag_segmented)

        editing_at_eol(current_line)

    post_processing_cleanup()

    final = ''.join(processed_text)
    # cleaning duplications - reset tags
    final = re.sub(Matcher.repeating_reset_regex, TagIndex.reset_processed, final)

    return final


if __name__ == "__main__":
    def process_text(text):
        text_result = draw_formatted(text)
        print(f'{text_result}')  # "return" result (bash)
        exit(0)  # if you reached past the result printing, it's a success

    if len(sys.argv) >= 2 and sys.argv[1]:  # arg 1 is this file
        if '--print_available_colors' in sys.argv:
            print(*TagIndex.color_map.keys())  # just print the dict
            exit(0)
        else:   # regular run
            process_text('\n'.join(sys.argv[1:]))  # run function on all args, separated by newlines
    elif not sys.stdin.isatty():  # no args, but data is piped in (stdin)
        process_text(sys.stdin.read().strip())

    exit(1)












# Add tests below this line
import unittest

class TestYourFunction(unittest.TestCase):

    some_tag = '<=green=>'
    pers_eol = Persistence.PERSISTENCE_EOL
    pers_eof = Persistence.PERSISTENCE_EOF
    eol_str = pers_eol.substr()
    eof_str = pers_eof.substr()

    # calculate final form
    def fin(self, *args) -> str:
        strs = list(args)
        return ''.join([TagIndex.color_map[f'<={tagstr}=>'] for tagstr in strs])

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
        tag_chain = TagChain(test_tag_string)
        self.assertEqual('<=b_blue=><=bold=><=uline=>', ''.join(tag_chain.tag_queue))
        self.assertEqual('\x1b[94m\x1b[1m\x1b[4m', ''.join(tag_chain.encoded))

    def test_persistence_functions(self):

        eol_pers_tag = f"<{self.eol_str}{self.some_tag}{self.eol_str}>"
        eof_pers_tag = f"<{self.eof_str}{self.some_tag}{self.eof_str}>"

        self.assertEqual(eol_pers_tag, self.pers_eol.apply_to(self.some_tag))
        self.assertEqual(eof_pers_tag, self.pers_eof.apply_to(self.some_tag))

        self.assertEqual(self.pers_eol, Persistence.identify_persistence(eol_pers_tag))
        self.assertEqual(self.pers_eof, Persistence.identify_persistence(eof_pers_tag))
        self.assertIsNone(Persistence.identify_persistence(eof_pers_tag + '>'))
        self.assertIsNone(Persistence.identify_persistence(''))
        self.assertIsNone(Persistence.identify_persistence('something'))
        self.assertIsNone(Persistence.identify_persistence(self.some_tag))

        self.assertEqual((self.some_tag, self.pers_eol), Persistence.strip(eol_pers_tag))
        self.assertEqual((self.some_tag, self.pers_eof), Persistence.strip(eof_pers_tag))
        self.assertEqual(('', None), Persistence.strip(''))
        self.assertEqual((self.some_tag, None), Persistence.strip(self.some_tag))

    def test_tag_validation(self):
        def strip_and_validate(tag_str):
            stripped, _ = Persistence.strip(tag_str)
            return TagIndex.is_valid_tag(stripped)

        self.assertTrue(TagIndex.is_valid_tag(self.some_tag))
        self.assertTrue(TagIndex.is_valid_tag(f"<{self.eol_str}{self.some_tag}{self.eol_str}>"))
        self.assertTrue(TagIndex.is_valid_tag(f"<{self.eof_str}{self.some_tag}{self.eof_str}>"))

        self.assertFalse(TagIndex.is_valid_tag(f"{self.some_tag}<=blue=>"))
        self.assertFalse(TagIndex.is_valid_tag(f"{self.some_tag}{self.some_tag}"))
        self.assertFalse(TagIndex.is_valid_tag(f"<{self.eof_str}{self.eof_str}{self.some_tag}{self.eof_str}{self.eof_str}>"))
        self.assertFalse(TagIndex.is_valid_tag(f"<{self.eof_str}{self.some_tag}{self.eol_str}>"))
        self.assertFalse(TagIndex.is_valid_tag(f"<{self.eol_str}{self.some_tag}{self.eof_str}>"))
        self.assertFalse(TagIndex.is_valid_tag('<==red=>'))
        self.assertFalse(TagIndex.is_valid_tag('<==red===>'))
        self.assertFalse(TagIndex.is_valid_tag('<==red==><=blue=>'))

    def test_matcher(self):
        for persist in Persistence:
            literal = persist.apply_to(TagIndex.reset_tag, escaped=False)
            regex = persist.apply_to(TagIndex.reset_tag, escaped=True)
            self.assertTrue(literal in Matcher.split_by_matches(regex, f"aaaa{literal}bbbb"))

        literal = TagIndex.reset_tag
        regex = TagIndex.reset_tag
        self.assertTrue(literal in Matcher.split_by_matches(regex, f"aaaa{literal}bbbb"))

        literal = '\x1b[0m'
        regex = '\x1b\[0m'
        self.assertTrue(literal in Matcher.split_by_matches(regex, f"aaaa{literal}bbbb"))

    def test_formatting(self):
        rst = TagIndex.reset_tag
        fin_rst = TagIndex.reset_processed  # final-form reset
        # get translation of tags (tag chains). starts with reset.
        fin = (lambda *args: ''.join([TagIndex.color_map[f'<={tagstr}=>'] for tagstr in list(args)]))
        rfin = (lambda *args: fin_rst + fin(*args))
        pl = Persistence.PERSISTENCE_EOL.apply_to
        pf = Persistence.PERSISTENCE_EOF.apply_to

        chain_tags = '<=green=><=bold=>'
        chain_encoded = f"{fin('green','bold')}"

        #     TODO - remove tags right before reset-tag
        #           Should start developing a pair-node system (instead of list of strings, list of pairs)
        #           there, the 2nd item would state whether the idem is color-tag, reset, or text
        #               the color-tag enum should be associated with persistence level



        tests = {
            'nothing': (  # default behavior - always end with a return to default style
                f"",
                f"{fin_rst}"),
            'no_tag': (
                f"a b c d e F g h i j k lmnop",
                f"a b c d e F g h i j k lmnop{fin_rst}"),
            'one_word': (
                f"<=bold=><=green=>AAAAA{rst}",
                f"{rfin('bold', 'green')}AAAAA{fin_rst}"),
            'simple_no_reset': (
                f"<=green=>AAAAA",
                f"{rfin('green')}AAAAA{fin_rst}"),
            'previously_scanned': (  # an existing reset in the middle, probably from previous usage of this tool
                f"aa {'<=bold=>'}AAAAA{fin_rst}BBBBB{rst}CCCC",
                f"aa {rfin('bold')}AAAAA{rfin('bold')}BBBBB{fin_rst}CCCC{fin_rst}"),
            'persist_over_previously_scanned': (
                f"aa {pl('<=bold=>')}AAAAA{fin_rst}BBBBB",
                f"aa {rfin('bold')}AAAAA{rfin('bold')}BBBBB{fin_rst}"),
            'deceptive_nontag_no_rst': (
                f"<=notapropertag=>AAAAA",
                f"<=notapropertag=>AAAAA{fin_rst}"),
            'deceptive_nontag': (
                f"<=notapropertag=>AAAAA{rst}",
                f"<=notapropertag=>AAAAA{fin_rst}"),
            'switching_color': (  # make sure that every new styling gets a "clean start"
                f"<=green=> a b c d <=bold=> e f g h <=blue=> i j k l",
                f"{rfin('green')} a b c d {rfin('bold')} e f g h {rfin('blue')} i j k l{fin_rst}",),
            'mid_txt': (
                f"aa <=bold=><=italic=><=green=>AAAAA{rst}",
                f"aa {rfin('bold', 'italic', 'green')}AAAAA{fin_rst}"),
            'mid_text+reset_at_beginning': (  # there might be a reason for that reset at start. Let it stay in result.
                f"aa {rst}<=bold=><=italic=><=green=>AAAAA{rst}",
                f"aa {rfin('bold', 'italic', 'green')}AAAAA{fin_rst}"),
            'color_right_after_reset': (
                f"<=blue=>bla bla{rst}<=red=>bli bli",
                f"{rfin('blue')}bla bla{rfin('red')}bli bli{fin_rst}",),
            'only_a_reset': (
                f"{rst}",
                f"{fin_rst}",),
            'multi_reset': (
                f"aaaa{rst}{rst}{rst}{rst}{rst}{rst}bbbb",
                f"aaaa{fin_rst}bbbb{fin_rst}",),
            'preprocessed': (  # see that past-processed text is left alone, and no extra reset at the end
                f"aa {rfin('bold', 'italic', 'green')}AAAAA{fin_rst}",
                f"aa {rfin('bold', 'italic', 'green')}AAAAA{fin_rst}",),
            'just_resets': (  # see that multiple consecutive resets are evaluated as one
                f"only one {rst}{rst}{rst}{rst} reset",
                f"only one {fin_rst} reset{fin_rst}"),
            'just_several_of_same_color': (  # see that multiple consecutive colors are evaluated as one
                f"only one <=green=><=green=><=green=><=green=><=green=> color",
                f"only one {rfin('green')} color{fin_rst}"),
            # TODO - same color, but some are pre-processed
            'repeating_several_of_same_color': (  # see that multiple consecutive colors are evaluated as one
                f"only one <=green=><=blue=><=green=><=blue=><=green=> color",
                f"only one {rfin('green', 'blue')} color{fin_rst}"),
            'multi-line': (  # see that reset is added at the end of each line
                f"\n\nline1\n\nline2",
                f"\n\nline1{fin_rst}\n\nline2{fin_rst}"),
            'multi-line_tagged': (  # see that reset is added at the end of each line
                f"\n\n<=red=>line1\n\nline2",
                f"\n\n{rfin('red')}line1{fin_rst}\n\nline2{fin_rst}"),
            'switching_styles_and_reset': (  # switching style with no explicit reset in input
                f"this text is <=red=>red , <=green=>green{rst} , regular",
                f"this text is {rfin('red')}red , {rfin('green')}green{rfin('red')} , regular{fin_rst}"),
            'switching_styles2': (  # several tags, has tag right at beginning
                f"<=red=>this text has <=blue=>few tags.",
                f"{rfin('red')}this text has {rfin('blue')}few tags.{fin_rst}"),
            'switching_styles3': (
                f"<=red=>this text has <=bold=><=blue=>few tags.",
                f"{rfin('red')}this text has {rfin('bold', 'blue')}few tags.{fin_rst}"),
            'whitespaces': (
                f"this text is has \"<=22WS=>\" 22 whitespaces",
                f"this text is has \"                      \" 22 whitespaces{fin_rst}"),
            'whitespaces_w_reset': (  # seeing that the reset tag gets merged post spacing
                f"this text is has \"{rst}<=22WS=>\" 22 whitespaces",
                f"this text is has \"{fin_rst}                      \" 22 whitespaces{fin_rst}"),
            'whitespaces_at_line_start': (
                f"<=2WS=><-2 spaces",
                f"  <-2 spaces{fin_rst}"),
            # 'persistence_eol_over_preprocessed': (
            #     f"<=red=>R <^^<=green=>^^>G {rfin('blue')}B{fin_rst} G\nno_color",
            #     f"{rfin('red')}R {rfin('green')}G {rfin('blue')}B{rfin('green')} G{fin_rst}\nno_color{fin_rst}"),
        }
        for k, v in tests.items():
            print(f"running test \"{k}\"")
            self.asrt(input_str=v[0], expected_output_str=v[1])




        # self.asrt(input_str=f"<=red=>R <^^{chain_tags}^^>G <=blue=><=dark=>B{rst} G\nno_color",
        #           outpt_str=f"{fin('red')}R {fin_rst}{chain_values}G {fin_rst}{fin('blue', 'dark')}B{fin_rst}{chain_values} G{fin_rst}\nno_color{fin_rst}")
        # self.asrt(input_str=f"<^^<=bold=><=green=>^^>aaa {fin('blue')}BBBBBB{fin_rst} ccc",
        #           outpt_str=f"{fin('bold', 'green')}aaa {fin_rst}{fin('blue')}BBBBBB{fin_rst}{fin('bold', 'green')} ccc{fin_rst}")
        # self.asrt(input_str=f"<^^<=bold=><=green=>^^>aaa {fin('blue')}bbb{fin_rst} ccc{rst}",
        #           outpt_str=f"{fin('bold', 'green')}aaa {fin_rst}{fin('blue')}bbb{fin_rst}{fin('bold', 'green')} ccc{fin_rst}")
        # self.asrt(input_str=f"unnecessary color at end <=bold=>",
        #           outpt_str=f"unnecessary color at end {fin_rst}")
        # self.asrt(input_str=f"<=green=>*{rst} ip addr  <^^<=yellow=>^^># display own networking interfaces",
        #           outpt_str=f"{fin('green')}*{fin_rst} ip addr  {fin_rst}{fin('yellow')}# display own networking interfaces{fin_rst}")

        # TODO - test hard-reset
        # TODO - test that the chain stack is empty at the end each time


    def test_shell(self):
        import subprocess
        import os

        current_file_path = os.path.abspath(__file__)
        input_string = '<=red=>this is red <=green=>and this is green'
        output_string = '\x1b[0m\x1b[31mthis is red \x1b[0m\x1b[32mand this is green\x1b[0m'

        def cmd_compare(bash_command):
            result = subprocess.run(bash_command, shell=True, capture_output=True, text=True,
                                    executable='/bin/bash').stdout
            result = result.removesuffix('\n')  # the shell subprocess adds a newline via echo; remove it
            self.assertEqual(output_string, result)

        # regular
        cmd_compare(f"'{current_file_path}' '{input_string}'")

        # piped
        cmd_compare(f"echo '{input_string}' | '{current_file_path}'")

        # streamed
        cmd_compare(f"'{current_file_path}' <<< '{input_string}'")

