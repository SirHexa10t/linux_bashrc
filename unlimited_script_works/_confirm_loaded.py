#!/usr/bin/python3

"""
Returns success. Basically just for checking that another script successfully reached and ran this file. Add "-v" as argument for textual success reply
"""

import sys

if "-v" in sys.argv:
    print("success")


exit(0)


