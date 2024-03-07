#!/usr/bin/python3

"""
Compares 2 words and prints the 2nd word while marking (coloring in red) 
the characters that aren't in 1st word (in relative order)
"""

import sys

# # Define ANSI escape codes for colors
RED = '\033[91m'
END = '\033[0m'


def emphasize_unique_to_word2(word1, word2):
    w1_len=len(word1)
    w2_len=len(word2)
    i1=0  # scan until next hit
    i2=0  # scan one by one
    list_is_found=[]
    while i1 < w1_len and i2 < w2_len:
        list_is_found.append(False)
        for temp in range(i1, w1_len):
            if word1[temp] == word2[i2]:
                # found next fitting char
                i1 = temp + 1  # from now on search after last found match (+1 because current is already matched)
                list_is_found[i2] = True
                break
        i2+=1
    last_tracked = len(list_is_found)
    for later_i2 in range(last_tracked, w2_len):  # remaining unscanned are unmatched
        list_is_found.append(False)

    # iterate on indexes and build a colored string
    is_prev_found = True
    built_output=[]
    for i2 in range(w2_len):
        is_current_found = list_is_found[i2]
        if is_prev_found != is_current_found:  # transitioned states
            coloring_transition = RED if is_prev_found else END  # if prev was found by current wasn't, start marking. Otherwise end marking.
            built_output.append(coloring_transition)
            is_prev_found = is_current_found
        built_output.append(word2[i2])  # add the char itself
    
    if not is_prev_found:  # possibly need to close
        built_output.append(END)

    returned_result = ''.join(built_output)  # stringify list
    print(returned_result)

#     return returned_result

# assert emphasize_unique_to_word2("hello", "hello") == "hello"
# assert emphasize_unique_to_word2("hello", "Hello") == f"{RED}H{END}ello"
# assert emphasize_unique_to_word2("helnlo", "hello") == "hello"
# assert emphasize_unique_to_word2("hello", "helnlo") == f"hel{RED}n{END}lo"
# assert emphasize_unique_to_word2("hello", "hellot") == f"hello{RED}t{END}"
# assert emphasize_unique_to_word2("holle", "hello") == f"he{RED}llo{END}"
# assert emphasize_unique_to_word2("herro", "hello") == f"he{RED}ll{END}o"
# assert emphasize_unique_to_word2("hello", "ello") == "ello"
# assert emphasize_unique_to_word2("ello", "hello") == f"{RED}h{END}ello"


emphasize_unique_to_word2(word1=sys.argv[1], word2=sys.argv[2])

