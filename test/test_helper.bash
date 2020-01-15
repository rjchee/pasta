#!/bin/bash

SYSTEM="$(uname -s)"
case "$SYSTEM" in
  Linux*)
    copy_text="xclip -selection clipboard -i"
    copy_img="xclip -selection clipboard -t image/png -i"
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

# writes binary data to stdout
get_binary_data () {
  # string of 0 bytes should be detected as an application/octet-stream file
  dd if=/dev/zero bs=1000 count=1 2>/dev/null
}

# writes random text data to stdout
get_random_text () {
  dd if=/dev/urandom bs=20 count=1 2>/dev/null | hexdump
}

# creates a random image and writes it to the given file name
create_random_img () {
  dd if=/dev/urandom bs=3072 count=1 2>/dev/null | convert -depth 8 -size 32x32 RGB:- "$1"
}

# takes the given arguments and copies it to the clipboard as space separated text
argcopy() {
  $copy_text <<< "$*"
}

# diff but for images
# Usage: imgdiff IMAGE_1 IMAGE_2 [DIFF_FILE_SUFFIX]
imgdiff() {
  compare -metric AE "$1" "$2" "${TMP_DIR}/diff${3:-}.png"
}

check_no_pastas() {
  [[ -z "$(ls -A "$PASTA_DIR")" ]]
}

# removes the debug prints for set -x when checking an output
clean_output() {
  out="$(grep -v '^\+* ' <<< "$output")"
}
