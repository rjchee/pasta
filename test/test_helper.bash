#!/bin/bash

SYSTEM="$(uname -s)"
case "$SYSTEM" in
  Linux*)
    copy_text="xclip -selection clipboard -i"
    copy_img="xclip -selection clipboard -t image/png -i"
    paste_text="xclip -selection clipboard -o"
    paste_img="xclip -selection clipboard -t image/png -o"
    clear_clip="xsel -bc"
    ;;
  Darwin*)
    echo "MacOS is not supported yet" >&2
    exit 1
    ;;
  *)
    echo "${SYSTEM} is not supported" >&2
    exit 1
    ;;
esac

# Writes binary data to stdout.
get_binary_data () {
  # String of 0 bytes should be detected as an application/octet-stream file
  dd if=/dev/zero bs=1000 count=1 2>/dev/null
}

# Writes a random image to the given filename. If the width and height are not given, they default to 32.
# Usage: create_random_img FILENAME [WIDTH] [HEIGHT]
create_white_img () {
  local file="$1"
  local w="${2:-32}"
  local h="${3:-32}"
  convert -size "${w}x${h}" xc:white "$file"
}

# Takes the given arguments and copies it to the clipboard as space separated text.
argcopy() {
  $copy_text <<< "$*"
}

# Diff but for images.
# Usage: imgdiff IMAGE_1 IMAGE_2 [DIFF_FILE_SUFFIX]
imgdiff() {
  compare -metric AE "$1" "$2" "${TMP_DIR}/diff${3:-}.png"
}

check_no_pastas() {
  [[ -z "$(ls -A "$PASTA_DIR")" ]]
}

# Removes the debug prints for set -x when checking an output.
clean_output() {
  out="$(grep -v '^\+* ' <<< "$output")"
}

# Tests that the clipboard is empty (only works on Linux as of now).
clipboard_is_empty() {
  [[ "$SYSTEM" =~ ^"Linux" ]]
  run $paste_text
  [[ "$status" -ne 0 ]]
  [[ "$output" == "Error: target STRING not available" ]]
}

# Ensures that all of the parent dirs for a file exist so that the file can be written.
ensure_parent_dirs() {
  mkdir -p "$(dirname "$1")"
}
