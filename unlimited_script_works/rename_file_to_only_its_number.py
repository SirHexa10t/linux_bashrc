#!/usr/bin/python3

"""
Renames files in specified dir (or local dir by default)
from <lots-of-words>-<number>.jpg to <number>.jpg

specifically used for posts from site: www.justpo.st/
"""

import os
import re
import sys

# Set the directory to the current directory by default,
# or to the first command-line argument if specified
directory = sys.argv[1] if len(sys.argv) > 1 else '.'

os.chdir(directory)  # Change to the specified directory

# Define ANSI escape codes for colors
RED = '\033[91m'
GREEN = '\033[92m'
END = '\033[0m'

# For all files in the directory
for filename in os.listdir('.'):
    match = re.match(r'.*-(\d+)\.jpg', filename)  # Extract the number from the filename
    if match:
        # If a match is found, rename the file
        new_filename = match.group(1) + '.jpg'
        # os.rename(filename, new_filename)
        # Print a message with colored filenames
        print(f'Renamed {RED}{filename}{END} to {GREEN}{new_filename}{END}')


