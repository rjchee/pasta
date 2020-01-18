#!/bin/bash

SYSTEM="$(uname -s)"
case "$SYSTEM" in
  Linux*)
    copy_text="xclip -selection clipboard -i"
    copy_img="xclip -selection clipboard -t image/png -i"
    paste_text="xclip -selection clipboard -o"
    paste_img="xclip -selection clipboard -t image/png -o"
    clear_clip="xsel -bc"
    img_open_cmd="xdg-open"
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

# Sets up a test case for checking sneaky paths. Accepts an argument for
# whether the sneaky names are being used for reading, writing, or as
# directory names. Sneaky names which are read should have data there, and
# if it's for writing, nothing happens since writing should create the
# data. If it's for a directory, the sneaky names will be the names of directories with data inside.
# Usage: setup_sneaky_paths_test (read|write|dir)
setup_sneaky_paths_test() {
  local mode="$1"
  sneaky_names=( ".." "../dot dot in front" "dot dot/in back/.." "dot dot/../../in middle" )
  case "$mode" in
    read)
      echo "sneaky data 1" > "${PASTA_DIR}/${sneaky_names[1]}.txt"
      sneaky_dir_name="${PASTA_DIR}/$(dirname "${sneaky_names[2]}")"
      mkdir -p "$sneaky_dir_name"
      # Make sure the sneaky directory is non-empty because pasta expects
      # directories to have content.
      echo "sneaky data 2" > "${sneaky_dir_name}/text.txt"
      echo "sneaky data 3" > "${PASTA_DIR}/${sneaky_names[3]}.txt"
      ;;
    write) ;; # No-op since no data is expected at these names.
    dir)
      pasta_name="my_pasta"
      local sneaky_name
      for sneaky_name in "${sneaky_names[@]}"
      do
        local sneaky_dir="${PASTA_DIR}/${sneaky_name}"
        mkdir -p "$sneaky_dir"
        echo sneaky data > "${sneaky_dir}/${pasta_name}.txt"
      done
      # also ensure intermediate directories have something in them
      echo sneaky data > "${PASTA_DIR}/$(dirname "${sneaky_names[2]}")/${pasta_name}.txt"
      ;;
  esac
}

# Mocks the given command, optionally taking an argument for any side
# effects the command should run. Users can call the mock_called
# function to determine whether the mocked command was called and which
# arguments it was called with.
# Usage: mock_command COMMAND_NAME [SIDE_EFFECT]
mock_command() {
  local command_name="$1"
  local side_effect="${2:-true}"
  local tmp_bin="${TMP_DIR}/bin"
  [[ -d "$tmp_bin" ]] || mkdir -p "$tmp_bin" && export PATH="${tmp_bin}:$PATH"
  local tmp_cmd="${tmp_bin}/$command_name"
  {
    echo '#!/bin/bash'
    echo 'printf "%s\n" "$@" > '"${TMP_DIR}/${command_name}_called"
    echo "$side_effect"
  } > "$tmp_cmd"
  chmod +x "$tmp_cmd"
}

# Checks if the mocked command was called, and if it was, saves the
# arguments into the given variable names. Assumes the arguments didn't
# have newlines.
# Usage: mock_called COMMAND_NAME [ARGUMENT_1_VAR] [ARGUMENT_2_VAR]...
mock_called() {
  local command_name="$1"
  local argument_file="${TMP_DIR}/${command_name}_called"
  [[ -f "$argument_file" ]]
  [[ "$#" -eq 1 ]] || read "${@:2}" < "$argument_file"
}
