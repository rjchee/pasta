#!/usr/bin/env bats

set -euo pipefail

load test_helper

setup() {
  TMP_DIR="$(mktemp -d -p "$BATS_TMPDIR" bats_pasta_test.XXX)"
  CLEANUP=0
  PASTA_DIR="${TMP_DIR}/pastas"
  export PASTA_SETTINGS="${TMP_DIR}/settings"
  export DEBUG=true
  PASTA="$(realpath "${BATS_TEST_DIRNAME}/../pasta")"
  run "$PASTA" init "$PASTA_DIR"
  [[ "$status" -eq 0 ]]
  $clear_clip
  # Make the environment in a known state.
  unset EDITOR
}

teardown() {
  if [[ "$CLEANUP" -eq 0 ]]
  then
    echo "$output" > "${TMP_DIR}/run_output.txt"
    if [[ -n "${ERROR_MSG:+x}" ]]
    then
      echo "# ${ERROR_MSG}"
    fi
    echo "# test case run in ${TMP_DIR}"
  else
    rm -rf "$TMP_DIR"
    $clear_clip
  fi
}

@test "pasta save saves the text on the clipboard" {
  argcopy "$BATS_TEST_DESCRIPTION"
  pasta_name="textdata"
  run "$PASTA" save $pasta_name
  [[ "$status" -eq 0 ]]
  pasta_file="${PASTA_DIR}/${pasta_name}.txt"
  [[ -f "$pasta_file" ]]
  [[ "$BATS_TEST_DESCRIPTION" == "$(< "$pasta_file")" ]]
  CLEANUP=1
}

@test "pasta save saves the PNG image on the clipboard" {
  image_file="${TMP_DIR}/image.png"
  create_white_img "$image_file"
  $copy_img "$image_file"
  pasta_name="imagedata"
  run "$PASTA" save $pasta_name
  [[ "$status" -eq 0 ]]
  pasta_file="${PASTA_DIR}/${pasta_name}.png"
  [[ -f "$pasta_file" ]]
  diff -q "$pasta_file" "$image_file"
  CLEANUP=1
}

@test "pasta save saves the JPG image on the clipboard" {
  image_file="${TMP_DIR}/image.jpg"
  create_white_img "$image_file"
  $copy_img "$image_file"
  pasta_name="imagedata"
  run "$PASTA" save $pasta_name
  [[ "$status" -eq 0 ]]
  pasta_file="${PASTA_DIR}/${pasta_name}.png"
  [[ -f "$pasta_file" ]]
  imgdiff "$pasta_file" "$image_file"
  CLEANUP=1
}

@test "pasta save accepts names with slashes and spaces" {
  argcopy "$BATS_TEST_DESCRIPTION"
  pasta_name='save slashes/and/spaces/in/name'
  run "$PASTA" save $pasta_name
  [[ "$status" -eq 0 ]]
  pasta_file="${PASTA_DIR}/${pasta_name}.txt"
  [[ -f "$pasta_file" ]]
  [[ "$BATS_TEST_DESCRIPTION" == "$(< "$pasta_file")" ]]
  CLEANUP=1
}

@test "pasta save rejects sneaky directory traversal names" {
  setup_sneaky_paths_test write
  for sneaky_name in "${sneaky_names[@]}"
  do
    ERROR_MSG="testing pasta save on sneaky path '${sneaky_name}'"
    argcopy "$BATS_TEST_DESCRIPTION" "$sneaky_name"
    run "$PASTA" save "$sneaky_name"
    [[ "$status" -eq 2 ]]
    clean_output
    [[ "$out" =~ "is an invalid pasta name" ]]
    [[ ! -f "${PASTA_DIR}/${sneaky_name}.txt" ]]
    check_no_pastas
  done

  CLEANUP=1
}

@test "pasta save fails with no data on the clipboard" {
  # Clipboard should be cleared from the setup() function.
  pasta_name="emptydata"
  run "$PASTA" save "$pasta_name"
  [[ "$status" -eq 2 ]]
  clean_output
  [[ "$out" == "Error: the clipboard is empty" ]]
  check_no_pastas
  CLEANUP=1
}

@test "pasta save fails with binary data on the clipboard" {
  get_binary_data | $copy_text
  pasta_name="bindata"
  run "$PASTA" save "$pasta_name"
  [[ "$status" -eq 2 ]]
  clean_output
  [[ "$out" =~ "unknown MIME type" ]]
  check_no_pastas
  CLEANUP=1
}

@test "pasta save fails with no arguments" {
  run "$PASTA" save
  [[ "$status" -eq 2 ]]
  clean_output
  [[ "$out" =~ "Usage: " ]]
  check_no_pastas
  CLEANUP=1
}

@test "pasta save works as expected when overwriting" {
  text1="first text data"
  argcopy "$text1"
  pasta_name="overwritten_pasta"
  text_file="${PASTA_DIR}/${pasta_name}.txt"
  echo "$text1" > "$text_file"
  text2="second data version"
  argcopy "$text2"

  # Test overwriting text with text.
  # Check behavior when no is given.
  run bash -c "echo n | ${PASTA} save ${pasta_name}"
  [[ "$status" -eq 3 ]]
  # Data should be the same.
  [[ -f "$text_file" ]]
  [[ "$text1" == "$(< "$text_file")" ]]
  # Check behavior when yes is given.
  run bash -c "echo y | ${PASTA} save ${pasta_name}"
  [[ "$status" -eq 0 ]]
  # Data should be updated.
  [[ -f "$text_file" ]]
  [[ "$text2" == "$(< "$text_file")" ]]

  # Test overwriting text with image.
  image_data="${TMP_DIR}/image.png"
  image_file="${PASTA_DIR}/${pasta_name}.png"
  create_white_img "${image_data}" 32 32
  $copy_img "$image_data"
  # Check behavior when no is given.
  run bash -c "echo n | ${PASTA} save ${pasta_name}"
  # User rejected overwriting, so data should still be text.
  [[ "$status" -eq 3 ]]
  # Data should be the same.
  [[ -f "$text_file" ]]
  [[ ! -f "$image_file" ]]
  [[ "$text2" == "$(< "$text_file")" ]]
  # Check behavior when yes is given.
  run bash -c "echo y | ${PASTA} save ${pasta_name}"
  [[ "$status" -eq 0 ]]
  # Data should be updated.
  [[ -f "$image_file" ]]
  [[ ! -f "$text_file" ]]
  diff "$image_file" "$image_data"

  # Test overwriting image with image.
  image_data_2="${TMP_DIR}/image2.png"
  # Create an image with a different size.
  create_white_img "${image_data_2}" 34 30
  $copy_img "$image_data_2"
  # Check behavior when no is given.
  run bash -c "echo n | ${PASTA} save ${pasta_name}"
  # User rejected overwriting, so data should still be the same.
  [[ "$status" -eq 3 ]]
  # Data should be the same.
  [[ -f "$image_file" ]]
  diff "$image_file" "$image_data"
  # Check behavior when yes is given.
  run bash -c "echo y | ${PASTA} save ${pasta_name}"
  [[ "$status" -eq 0 ]]
  # Data should be updated.
  [[ -f "$image_file" ]]
  diff "$image_file" "$image_data_2"

  # Test overwriting image with text.
  argcopy "$text1"
  # Check behavior when no is given.
  run bash -c "echo n | ${PASTA} save ${pasta_name}"
  # User rejected overwriting, so data should still be image.
  [[ "$status" -eq 3 ]]
  # Data should be the same.
  [[ -f "$image_file" ]]
  [[ ! -f "$text_file" ]]
  diff "$image_file" "$image_data_2"
  # Check behavior when yes is given.
  run bash -c "echo y | ${PASTA} save ${pasta_name}"
  [[ "$status" -eq 0 ]]
  # Data should be updated.
  [[ -f "$text_file" ]]
  [[ ! -f "$image_file" ]]
  [[ "$text1" == "$(< "$text_file")" ]]
  CLEANUP=1
}

@test "pasta insert calls the editor" {
  # Replace the default editor with cp to simulate writing something to the file.
  export EDITOR="cp ${PASTA_SETTINGS}"
  pasta_name="insert_test"
  run "$PASTA" insert $pasta_name
  [[ "$status" -eq 0 ]]
  pasta_file="${PASTA_DIR}/${pasta_name}.txt"
  [[ -f "$pasta_file" ]]
  CLEANUP=1
}

@test "pasta insert works when overwriting" {
  # Replace the default editor with cp to simulate writing something to the file.
  export EDITOR="cp ${PASTA_SETTINGS}"
  pasta_name="overwrite_test"
  text_file="${PASTA_DIR}/${pasta_name}.txt"
  echo data > "$text_file"
  text_backup="${TMP_DIR}/backup.txt"
  cp "$text_file" "$text_backup"

  # Test if overwriting text.
  # Check if choosing not to overwrite opens the editor.
  run bash -c "echo n | ${PASTA} insert ${pasta_name}"
  [[ "$status" -eq 3 ]]
  # Contents should be the same because it was not overwritten.
  [[ -f "$text_file" ]]
  diff "$text_file" "$text_backup"
  # Check if choosing to overwrite opens the editor.
  run bash -c "echo y | ${PASTA} insert ${pasta_name}"
  # If the command succeeds, the PASTA_SETTINGS file was copied over.
  [[ "$status" -eq 0 ]]
  [[ -f "$text_file" ]]
  diff -q "$text_file" "$PASTA_SETTINGS"

  # Test if overwriting image.
  rm "$text_file"
  image_file="${PASTA_DIR}/${pasta_name}.png"
  create_white_img "$image_file"
  image_backup="${TMP_DIR}/backup.png"
  cp "$image_file" "$image_backup"

  # Check if choosing not to overwrite opens the editor.
  run bash -c "echo n | ${PASTA} insert ${pasta_name}"
  [[ "$status" -eq 3 ]]
  # Nothing was overwritten so the image file should still be there.
  [[ -f "$image_file" ]]
  [[ ! -f "$text_file" ]]
  diff "$image_file" "$image_backup"
  # Check if choosing to overwrite opens the editor.
  run bash -c "echo y | ${PASTA} insert ${pasta_name}"
  # If the command succeeds, the PASTA_SETTINGS file was copied over.
  [[ "$status" -eq 0 ]]
  [[ -f "$text_file" ]]
  [[ ! -f "$image_file" ]]
  diff -q "$text_file" "$PASTA_SETTINGS"
  CLEANUP=1
}

@test "pasta insert without writing anything should fail" {
  # Replace the default editor with true to simulate a no-op.
  export EDITOR=true
  run "$PASTA" insert pasta_name
  [[ "$status" -eq 3 ]]
  clean_output
  [[ "$out" == "Pasta not created." ]]
  check_no_pastas
  CLEANUP=1
}

@test "pasta insert with no arguments should fail" {
  # Replace the default editor with cp to simulate writing something to the file.
  export EDITOR="cp ${PASTA_SETTINGS}"
  run "$PASTA" insert
  [[ "$status" -eq 2 ]]
  clean_output
  [[ "$out" =~ ^"Usage: " ]]
  check_no_pastas
  CLEANUP=1
}

@test "pasta insert works when the editor is not set" {
  # Create a temporary vi executable to replace the existing vi.
  mock_command vi 'echo something > "$1"'
  pasta_name="pasta_name"
  run "$PASTA" insert $pasta_name
  [[ "$status" -eq 0 ]]
  pasta_file="${PASTA_DIR}/${pasta_name}.txt"
  # If the mocked vi was called by checking the pasta file should exist.
  [[ -f "$pasta_file" ]]
  mock_called vi
  CLEANUP=1
}

@test "pasta insert accepts names with slashes and spaces" {
  # Replace the default editor with cp to simulate writing something to the file.
  export EDITOR="cp ${PASTA_SETTINGS}"
  pasta_name='insert/slashes and/spaces/in/name'
  run "$PASTA" insert $pasta_name
  [[ "$status" -eq 0 ]]
  pasta_file="${PASTA_DIR}/${pasta_name}.txt"
  [[ -f "$pasta_file" ]]
  diff "${PASTA_SETTINGS}" "$pasta_file"
  CLEANUP=1
}

@test "pasta insert rejects sneaky directory traversal names" {
  setup_sneaky_paths_test write
  # Replace the default editor with cp to simulate writing something to the file.
  export EDITOR="cp ${PASTA_SETTINGS}"
  for sneaky_name in "${sneaky_names[@]}"
  do
    ERROR_MSG="testing pasta insert on sneaky path '${sneaky_name}'"
    argcopy "$BATS_TEST_DESCRIPTION"
    run "$PASTA" save "$sneaky_name"
    [[ "$status" -eq 2 ]]
    clean_output
    [[ "$out" =~ "is an invalid pasta name" ]]
    [[ ! -f "${PASTA_DIR}/${sneaky_name}.txt" ]]
    check_no_pastas
  done
  CLEANUP=1
}

@test "pasta file saves a text file" {
  text_file="${TMP_DIR}/textfile.txt"
  pasta_name="textdata"
  echo "text data" >"$text_file"
  run "$PASTA" file "$text_file" $pasta_name
  [[ "$status" -eq 0 ]]
  pasta_file="${PASTA_DIR}/${pasta_name}.txt"
  [[ -f "$pasta_file" ]]
  diff "$text_file" "$pasta_file"
  CLEANUP=1
}

@test "pasta file saves a PNG file" {
  image_file="${TMP_DIR}/image.png"
  pasta_name="png"
  create_white_img "$image_file"
  run "$PASTA" file "$image_file" $pasta_name
  [[ "$status" -eq 0 ]]
  pasta_file="${PASTA_DIR}/${pasta_name}.png"
  [[ -f "$pasta_file" ]]
  diff "$image_file" "$pasta_file"
  CLEANUP=1
}

@test "pasta file saves a JPG file" {
  image_file="${TMP_DIR}/image.jpg"
  pasta_name="jpg"
  create_white_img "$image_file"
  run "$PASTA" file "$image_file" $pasta_name
  [[ "$status" -eq 0 ]]
  pasta_file="${PASTA_DIR}/${pasta_name}.png"
  [[ -f "$pasta_file" ]]
  imgdiff "$image_file" "$pasta_file"
  CLEANUP=1
}

@test "pasta file accepts names with slashes and spaces" {
  pasta_name="file/slashes/and spaces/in/name"
  text_file="${TMP_DIR}/textfile.txt"
  echo "text data" >"$text_file"
  run "$PASTA" file "$text_file" $pasta_name
  [[ "$status" -eq 0 ]]
  pasta_file="${PASTA_DIR}/${pasta_name}.txt"
  [[ -f "$pasta_file" ]]
  diff "$text_file" "$pasta_file"
  CLEANUP=1
}

@test "pasta file fails when given too few arguments" {
  text_file="${TMP_DIR}/textfile.txt"
  echo "text data" >"$text_file"
  # Check when no pasta name is given.
  run "$PASTA" file "$text_file"
  [[ "$status" -eq 2 ]]
  clean_output
  [[ "$out" =~ "Usage: " ]]
  check_no_pastas
  # Check when 0 arguments are given.
  run "$PASTA" file
  [[ "$status" -eq 2 ]]
  clean_output
  [[ "$out" =~ "Usage: " ]]
  check_no_pastas
  CLEANUP=1
}

@test "pasta file fails when given an unknown file type" {
  byte_file="${TMP_DIR}/bytes.bin"
  get_binary_data >"$byte_file"
  # Sanity check to make sure this file is not detected as an image or text.
  filetype="$(file --mime-type -b "$byte_file")"
  mimetype="$(echo "$filetype" | cut -d'/' -f1)"
  [[ "$mimetype" != "image" ]] && [[ "$mimetype" != "text" ]] || skip "test invalid because the test file has MIME type '${filetype}'"
  run "$PASTA" file  "$byte_file" bytedata
  [[ "$status" -eq 2 ]]
  clean_output
  [[ "$out" =~ "unknown MIME type" ]]
  check_no_pastas
  CLEANUP=1
}

@test "pasta file fails when given a nonexistent file" {
  run "$PASTA" file "${TMP_DIR}/fake_file.txt" pasta_name
  [[ "$status" -eq 2 ]]
  clean_output
  [[ "$out" =~ "no file".*"exists" ]]
  check_no_pastas
  CLEANUP=1
}

@test "pasta file fails when given an empty file" {
  empty_file="${TMP_DIR}/empty.txt"
  touch "$empty_file"
  run "$PASTA" file "${empty_file}" empty_pasta
  [[ "$status" -eq 2 ]]
  clean_output
  [[ "$out" =~ "is empty" ]]
  check_no_pastas
  CLEANUP=1
}

@test "pasta file fails when given a directory" {
  dir_name="${TMP_DIR}/dir"
  mkdir "$dir_name"
  run "$PASTA" file "$dir_name" pasta_name
  [[ "$status" -eq 2 ]]
  clean_output
  [[ "$out" =~ "is a directory" ]]
  check_no_pastas
  CLEANUP=1
}

@test "pasta file rejects sneaky directory traversal names" {
  setup_sneaky_paths_test write
  text_file="${TMP_DIR}/textfile.txt"
  echo "text data" >"$text_file"
  for sneaky_name in "${sneaky_names[@]}"
  do
    ERROR_MSG="testing pasta file on sneaky path '${sneaky_name}'"
    argcopy "$BATS_TEST_DESCRIPTION"
    run "$PASTA" save "$sneaky_name"
    [[ "$status" -eq 2 ]]
    clean_output
    [[ "$out" =~ "is an invalid pasta name" ]]
    [[ ! -f "${PASTA_DIR}/${sneaky_name}.txt" ]]
    check_no_pastas
  done
  CLEANUP=1
}

@test "pasta file works when overwriting" {
  pasta_name="overwritten_pasta"
  text_pasta="${PASTA_DIR}/${pasta_name}.txt"
  echo "old data" > "$text_pasta"
  text_backup="${TMP_DIR}/backup.txt"
  cp "$text_pasta" "$text_backup"
  new_text="${TMP_DIR}/overwrite.txt"
  echo "new data" > "$new_text"

  # Test overwriting text with text.
  # Check behavior when no is given.
  run bash -c "echo n | ${PASTA} file ${new_text} ${pasta_name}"
  [[ "$status" -eq 3 ]]
  # Data should be the same.
  [[ -f "$text_pasta" ]]
  diff "$text_pasta" "$text_backup"
  # Check behavior when yes is given.
  run bash -c "echo y | ${PASTA} file ${new_text} ${pasta_name}"
  [[ "$status" -eq 0 ]]
  # Data should be updated.
  [[ -f "$text_pasta" ]]
  diff "$text_pasta" "$new_text"

  # Test overwriting text with image.
  image_file="${TMP_DIR}/image.png"
  image_pasta="${PASTA_DIR}/${pasta_name}.png"
  create_white_img "${image_file}" 32 32
  # Check behavior when no is given.
  run bash -c "echo n | ${PASTA} file ${image_file} ${pasta_name}"
  # User rejected overwriting, so data should still be text.
  [[ "$status" -eq 3 ]]
  # Data should be the same.
  [[ -f "$text_pasta" ]]
  [[ ! -f "$image_pasta" ]]
  diff "$text_pasta" "$new_text"
  # Check behavior when yes is given.
  run bash -c "echo y | ${PASTA} file ${image_file} ${pasta_name}"
  [[ "$status" -eq 0 ]]
  # Data should be updated.
  [[ -f "$image_pasta" ]]
  [[ ! -f "$text_pasta" ]]
  diff "$image_pasta" "$image_file"

  # Test overwriting image with image.
  image_file_2="${TMP_DIR}/image2.png"
  create_white_img "${image_file_2}" 30 34
  $copy_img "$image_file_2"
  # Check behavior when no is given.
  run bash -c "echo n | ${PASTA} file ${image_file_2} ${pasta_name}"
  # User rejected overwriting, so data should still be the same.
  [[ "$status" -eq 3 ]]
  # Data should be the same.
  [[ -f "$image_pasta" ]]
  diff "$image_pasta" "$image_file"
  # Check behavior when yes is given.
  run bash -c "echo y | ${PASTA} file ${image_file_2} ${pasta_name}"
  [[ "$status" -eq 0 ]]
  # Data should be updated.
  [[ -f "$image_pasta" ]]
  diff "$image_pasta" "$image_file_2"

  # Test overwriting image with text.
  # Check behavior when no is given.
  run bash -c "echo n | ${PASTA} file ${new_text} ${pasta_name}"
  # User rejected overwriting, so data should still be image.
  [[ "$status" -eq 3 ]]
  # data Should be the same.
  [[ -f "$image_pasta" ]]
  [[ ! -f "$text_pasta" ]]
  diff "$image_pasta" "$image_file_2"
  # Check behavior when yes is given.
  run bash -c "echo y | ${PASTA} file ${new_text} ${pasta_name}"
  [[ "$status" -eq 0 ]]
  # Data should be updated.
  [[ -f "$text_pasta" ]]
  [[ ! -f "$image_pasta" ]]
  diff "$text_pasta" "$new_text"
  CLEANUP=1
}

@test "pasta load loads text on the clipboard" {
  pasta_name="textdata"
  text_file="${PASTA_DIR}/${pasta_name}.txt"
  echo "text data" > "$text_file"

  for load_cmd in "$PASTA" "${PASTA} load"
  do
    ERROR_MSG="testing $load_cmd"
    run $load_cmd "$pasta_name"
    [[ "$status" -eq 0 ]]
    pasted_file="${TMP_DIR}/pasted.txt"
    $paste_text >"$pasted_file"
    diff "$text_file" "$pasted_file"
  done
  CLEANUP=1
}

@test "pasta load loads images on the clipboard" {
  pasta_name="imagedata"
  image_file="${PASTA_DIR}/${pasta_name}.png"
  create_white_img "$image_file"

  for load_cmd in "$PASTA" "${PASTA} load"
  do
    ERROR_MSG="testing $load_cmd"
    run $load_cmd "$pasta_name"
    [[ "$status" -eq 0 ]]
    pasted_file="${TMP_DIR}/pasted.png"
    $paste_text >"$pasted_file"
    diff "$image_file" "$pasted_file"
  done
  CLEANUP=1
}

@test "pasta load has priority over pasta list when load is specified" {
  pasta_name="textdata"
  overloaded_dir="${PASTA_DIR}/${pasta_name}"
  text_file="${overloaded_dir}.txt"
  echo "text_data" > "$text_file"
  other_pasta_name="extra_name"
  mkdir "$overloaded_dir"
  echo "more data" > "${overloaded_dir}/${other_pasta_name}.txt"

  for load_cmd in "$PASTA" "${PASTA} load"
  do
    ERROR_MSG="testing $load_cmd"
    run $load_cmd "$pasta_name"
    [[ "$status" -eq 0 ]]
    clean_output
    [[ "$out" =~ ^"Loaded" ]]
    [[ ! "$out" =~ "$other_pasta_name" ]]
    pasted_file="${TMP_DIR}/pasted.txt"
    $paste_text >"$pasted_file"
    diff "$text_file" "$pasted_file"
  done
  CLEANUP=1
}

@test "pasta load accepts names with slashes and spaces" {
  pasta_name="load/slashes/and/spaces in/name"
  text_file="${PASTA_DIR}/${pasta_name}.txt"
  ensure_parent_dirs "$text_file"
  echo "text data" > "$text_file"

  run "$PASTA" load "$pasta_name"
  [[ "$status" -eq 0 ]]
  pasted_file="${TMP_DIR}/pasted.txt"
  $paste_text >"$pasted_file"
  diff "$text_file" "$pasted_file"
  CLEANUP=1
}

@test "pasta load rejects sneaky directory traversal names" {
  setup_sneaky_paths_test read

  for load_cmd in "$PASTA" "${PASTA} load"
  do
    for sneaky_name in "${sneaky_names[@]}"
    do
      ERROR_MSG="testing ${load_cmd} on sneaky path '${sneaky_name}'"
      run $load_cmd "$sneaky_name"
      [[ "$status" -eq 2 ]]
      clean_output
      [[ "$out" =~ "is an invalid pasta name" ]]
      clipboard_is_empty
    done
  done
  CLEANUP=1
}

@test "pasta load fails when a nonexistent pasta is specified" {
  for load_cmd in "" "load"
  do
    ERROR_MSG="testing pasta ${load_cmd}"
    run "$PASTA" $load_cmd nonexistent_pasta
    [[ "$status" -eq 2 ]]
    clean_output
    [[ "$out" =~ "does not exist" ]]
    clipboard_is_empty
  done
  CLEANUP=1
}

@test "pasta show displays a text pasta" {
  text_data="my data"
  pasta_name="textdata"
  pasta_file="${PASTA_DIR}/${pasta_name}.txt"
  echo "$text_data" > "$pasta_file"

  for cmd in "show" "inspect"
  do
    ERROR_MSG="testing command 'pasta ${cmd}'"
    run "$PASTA" "$cmd" "$pasta_name"
    [[ "$status" -eq 0 ]]
    clean_output
    [[ "$out" == "$text_data" ]]
  done
  CLEANUP=1
}

@test "pasta show displays an image pasta" {
  pasta_name="imagedata"
  pasta_file="${PASTA_DIR}/${pasta_name}.png"
  create_white_img "$pasta_file"

  mock_command "$img_open_cmd"

  for cmd in "show" "inspect"
  do
    ERROR_MSG="testing command 'pasta ${cmd}'"
    run "$PASTA" "$cmd" "$pasta_name"
    [[ "$status" -eq 0 ]]
    mock_called "$img_open_cmd" image_file
    [[ "$image_file" -ef "$pasta_file" ]]
  done
  CLEANUP=1
}

@test "pasta show has priority over pasta list when show is specified" {
  pasta_name="textdata"
  overloaded_dir="${PASTA_DIR}/${pasta_name}"
  text_data="my text data"
  echo "$text_data" > "${overloaded_dir}.txt"
  mkdir "$overloaded_dir"
  echo "more data" > "${overloaded_dir}/extra name.txt"

  for show_cmd in "show" "inspect"
  do
    ERROR_MSG="testing pasta $show_cmd"
    run "$PASTA" "$show_cmd" "$pasta_name"
    [[ "$status" -eq 0 ]]
    clean_output
    [[ "$out" == "$text_data" ]]
  done
  CLEANUP=1
}

@test "pasta show accepts names with slashes and spaces" {
  text_data="my data"
  pasta_name="show/slashes/and/spaces/in name"
  pasta_file="${PASTA_DIR}/${pasta_name}.txt"
  ensure_parent_dirs "$pasta_file"
  echo "$text_data" > "$pasta_file"

  for cmd in "show" "inspect"
  do
    ERROR_MSG="testing command 'pasta ${cmd}'"
    run "$PASTA" "$cmd" "$pasta_name"
    [[ "$status" -eq 0 ]]
    clean_output
    [[ "$out" == "$text_data" ]]
  done
  CLEANUP=1
}

@test "pasta show rejects sneaky directory traversal names" {
  setup_sneaky_paths_test read

  for show_cmd in "show" "inspect"
  do
    for sneaky_name in "${sneaky_names[@]}"
    do
      ERROR_MSG="testing pasta ${show_cmd} on sneaky path '${sneaky_name}'"
      run "$PASTA" "$show_cmd" "$sneaky_name"
      [[ "$status" -eq 2 ]]
      clean_output
      [[ "$out" =~ "is an invalid pasta name" ]]
    done
  done
  CLEANUP=1
}

@test "pasta show fails when a nonexistent pasta is specified" {
  for show_cmd in "show" "inspect"
  do
    ERROR_MSG="testing pasta ${show_cmd}"
    run "$PASTA" "$show_cmd" nonexistent_pasta
    [[ "$status" -eq 2 ]]
    clean_output
    [[ "$out" =~ "does not exist" ]]
  done
  CLEANUP=1
}

@test "pasta list displays only pastas in the target subtree" {
  outside_file="${TMP_DIR}/outside.txt"
  echo outside > "$outside_file"
  text_pastas=( "top_text" "level1/text file" "level1/level2/my_pasta" "foo/mytxt" "extra extension.txt" )
  for text_pasta in "${text_pastas[@]}"
  do
    text_path="${PASTA_DIR}/${text_pasta}.txt"
    ensure_parent_dirs "$text_path"
    echo "$text_pasta" > "$text_path"
  done
  image_pastas=( "top_image" "level1/png" "level1/level2/level3/image_pasta" "extra extension.png" "extra_extension_when_image.txt" )
  for (( i=0 ; i < "${#image_pastas[@]}"; i++ ))
  do
    image_path="${PASTA_DIR}/${image_pastas[i]}.png"
    ensure_parent_dirs "$image_path"
    create_white_img "$image_path" "$i" "$i"
  done

  # Test running pasta list on the whole pasta directory.
  for list_cmd in "list" "ls" "" "load" "show" "inspect"
  do
    for all_path in "" "." "/" "./"
    do
      list_all_cmd="${list_cmd} $all_path"
      ERROR_MSG="testing list all command 'pasta ${list_all_cmd}'"
      run "$PASTA" $list_all_cmd
      [[ "$status" -eq 0 ]]
      clean_output
      [[ "$(echo "$out" | head -n 1)" == "Pasta Store" ]]
      base_error_msg="$ERROR_MSG"
      for text_pasta in "${text_pastas[@]}"
      do
        base_name="$(basename "$text_pasta")"
        ERROR_MSG="when ${base_error_msg}, text pasta '${text_pasta}' did not appear in the results"
        # Check that the text pasta made it into the output.
        text_pasta_line="$(echo "$out" | grep "$base_name")"
        ERROR_MSG="when ${base_error_msg}, the line for text pasta '${text_pasta}' is ${text_pasta_line}"
        # check that the .txt extension is removed from the output
        [[ ! "$text_pasta_line" =~ "${base_name}.txt" ]]
      done
      for image_pasta in "${image_pastas[@]}"
      do
        base_name="$(basename "$image_pasta")"
        ERROR_MSG="when ${base_error_msg}, image pasta '${image_pasta}' did not appear in the results"
        # Check that the image pasta made it into the output.
        image_pasta_line="$(echo "$out" | grep "$base_name")"
        ERROR_MSG="when ${base_error_msg}, the line for image pasta '${image_pasta}' is ${image_pasta_line}"
        # Check that the .png extension is removed from the output.
        [[ ! "$image_pasta_line" =~ "${base_name}.png" ]]
      done
    done

    # Test running pasta list on a subdirectory.
    for subdirectory in "level1" "level1/level2/" "foo/"
    do
      ERROR_MSG="testing list command 'pasta ${list_cmd} ${subdirectory}'"
      run "$PASTA" $list_cmd "${subdirectory}"
      [[ "$status" -eq 0 ]]
      clean_output
      # Check that the first line is the name of the subdirectory without
      # the trailing slash.
      [[ "$(echo "$out" | head -n 1)" == "${subdirectory%/}" ]]
      base_error_msg="$ERROR_MSG"
      for text_pasta in "${text_pastas[@]}"
      do
        base_name="$(basename "$text_pasta")"
        if [[ "$text_pasta" =~ ^"$subdirectory" ]]
        then
          # The pasta should appear in the results.
          ERROR_MSG="when ${base_error_msg}, text pasta '${text_pasta}' did not appear in the results"
          # Check that the text pasta made it into the output.
          text_pasta_line="$(echo "$out" | grep "$base_name")"
          ERROR_MSG="when ${base_error_msg}, the line for text pasta '${text_pasta}' is ${text_pasta_line}"
          # check that the .txt extension is removed from the output
          [[ ! "$text_pasta_line" =~ "${base_name}.txt" ]]
        else
          # The pasta should not appear in the results.
          ERROR_MSG="when ${base_error_msg}, text pasta '${text_pasta}' appeared in the results unexpectedly"
          [[ ! "$out" =~ "$base_name" ]]
        fi
      done
      for image_pasta in "${image_pastas[@]}"
      do
        base_name="$(basename "$image_pasta")"
        if [[ "$image_pasta" =~ ^"$subdirectory" ]]
        then
          # The pasta should appear in the results.
          ERROR_MSG="when ${base_error_msg}, image pasta '${image_pasta}' did not appear in the results"
          # Check that the image pasta made it into the output.
          image_pasta_line="$(echo "$out" | grep "$base_name")"
          ERROR_MSG="when ${base_error_msg}, the line for image pasta '${image_pasta}' is ${image_pasta_line}"
          # check that the .txt extension is removed from the output
          [[ ! "$image_pasta_line" =~ "${base_name}.png" ]]
        else
          # The pasta should not appear in the results.
          ERROR_MSG="when ${base_error_msg}, image pasta '${image_pasta}' appeared in the results unexpectedly"
          [[ ! "$out" =~ "$base_name" ]]
        fi
      done
    done
  done
  CLEANUP=1
}

@test "pasta list has priority over pasta load when used on directory names" {
  pasta_name="my_pasta_dir"
  pasta_subdir="${PASTA_DIR}/$pasta_name"
  mkdir "$pasta_subdir"
  pasta_subdir_file_name="my_text"
  echo something > "${pasta_subdir}/${pasta_subdir_file_name}.txt"
  echo "shouldn't be loaded" > "${pasta_subdir}.txt"

  for list_cmd in "list" "ls"
  do
    ERROR_MSG="testing pasta $list_cmd"
    run "$PASTA" "$list_cmd" "$pasta_name"
    [[ "$status" -eq 0 ]]
    clean_output
    [[ "$out" =~ "$pasta_name" ]]
    [[ "$out" =~ "$pasta_subdir_file_name" ]]
    [[ ! "$out" =~ ^"Loaded" ]]
    clipboard_is_empty
  done
  CLEANUP=1
}

@test "pasta list rejects sneaky directory traversal names" {
  setup_sneaky_paths_test dir

  for list_cmd in "list" "ls"
  do
    for sneaky_name in "${sneaky_names[@]}"
    do
      ERROR_MSG="testing pasta ${list_cmd} on sneaky path '${sneaky_name}'"
      run "$PASTA" "$list_cmd" "$sneaky_name"
      [[ "$status" -eq 2 ]]
      clean_output
      [[ "$out" =~ "is an invalid pasta name" ]]
      [[ ! "$out" =~ "$pasta_name" ]]
    done
  done
  CLEANUP=1
}

@test "pasta list fails when a nonexistent directory is specified" {
  nonexistent_name="nonexistent"
  for list_cmd in "list" "ls"
  do
    ERROR_MSG="testing pasta ${list_cmd} on nonexistent path"
    run "$PASTA" "$list_cmd" "$nonexistent_name"
    [[ "$status" -eq 2 ]]
    clean_output
    [[ "$out" =~ "does not exist" ]]
    [[ "$out" =~ "$nonexistent_name" ]]
  done
  CLEANUP=1
}

@test "pasta list only strips file extensions from files and not directories" {
  CLEANUP=1
  skip "This functionality is not implemented yet"

  text_dir="dir.txt"
  text_path="${PASTA_DIR}/$text_dir"
  mkdir "$text_path"
  echo abc > "${text_path}/_.txt"
  image_dir="dir.png"
  image_path="${PASTA_DIR}/$image_dir"
  mkdir "$image_path"
  echo abc > "${image_path}/ignored.txt"

  for list_all_cmd in "$PASTA" "${PASTA} list" "${PASTA} ls"
  do
    run "$PASTA"
    [[ "$status" -eq 0 ]]
    clean_output
    [[ "$out" =~ "$text_dir" ]]
    [[ "$out" =~ "$image_dir" ]]
  done
  CLEANUP=1
}
