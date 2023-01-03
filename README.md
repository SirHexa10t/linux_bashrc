# linux_bashrc

A bashrc file with various gimmicks I found or came up with

It's still a work in progress; some features are commented out until they'll be finished

## Compatibility

Some commands utilize packages which you may need to install

This bashrc was written for Linux Mint 21 / 21.1, but should work for the most part with any distro.


## Usage

Beginner-instructions can be found within the file.

User-specific settings can be set at the top of the file, in the appropriate "My settings" section.
Just look-up the variables' names within this same file, you'll see what they're used for.

If you want to work on a bashrc file in a git-project but don't want to debug directly from your modified file
(i.e. you want to keep a copy that could run after you remove the project or its volume), you can add the following
snippet before your bashrc's source of the external file:

```
# You need to make sure the following 2 values are set right.
CUSTOM_BASHRC_FILE="$HOME/custom_bashrc"
CUSTOM_BASHRC_FILE_SOURCE="<path-to-project>/custom_bashrc"

# if the repository's version was updated later, overwrite your default bashrc external file (and touch it to update the modification date)
if test "$CUSTOM_BASHRC_FILE_SOURCE" -nt "$CUSTOM_BASHRC_FILE"; then
    cp "$CUSTOM_BASHRC_FILE_SOURCE" "$CUSTOM_BASHRC_FILE"
    touch "$CUSTOM_BASHRC_FILE"
    echo 'copied-over bashrc file from repository'
fi

# the sourcing of your file
if [ -e "$CUSTOM_BASHRC_FILE" ]; then source "$CUSTOM_BASHRC_FILE"; fi
```


