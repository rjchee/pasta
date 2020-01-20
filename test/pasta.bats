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
    echo "# test case run in ${TMP_DIR}" >&3
    echo "$output" > "${TMP_DIR}/run_output.txt"
    if [[ -n "${ERROR_MSG:+x}" ]]
    then
      echo "# ${ERROR_MSG}" >&3
    fi
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
    ERROR_MSG="testing 'pasta save' on sneaky path '${sneaky_name}'"
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
  for force_flag in "" "-f" "--force"
  do
    ERROR_MSG="testing 'pasta save ${force_flag}'"
    run "$PASTA" save $force_flag
    [[ "$status" -eq 2 ]]
    clean_output
    [[ "$out" =~ ^"Usage: " ]]
    check_no_pastas
  done
  CLEANUP=1
}

@test "pasta save works when overwriting" {
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

@test "pasta save with the force flag doesn't ask for overwrite" {
  old_data="old data"
  pasta_name="pasta_name"
  pasta_file="${PASTA_DIR}/${pasta_name}.txt"
  new_data="new data"
  for force_flag in '-f' '--force'
  do
    echo "$old_data" > "$pasta_file"
    argcopy "$new_data"
    # Echo no to pasta which should be ignored.
    run bash -c "echo n | ${PASTA} save ${force_flag} $pasta_name"
    [[ "$status" -eq 0 ]]
    [[ -f "$pasta_file" ]]
    [[ "$new_data" == "$(< "$pasta_file")" ]]
    rm "$pasta_file"
  done
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
  diff -q "$pasta_file" "$PASTA_SETTINGS"
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

@test "pasta insert with the force flag doesn't ask for overwrite" {
  pasta_name="pasta_name"
  pasta_file="${PASTA_DIR}/${pasta_name}.txt"
  export EDITOR="cp ${PASTA_SETTINGS}"
  for force_flag in '-f' '--force'
  do
    echo "different from pasta settings" > "$pasta_file"
    # Echo no to pasta which should be ignored.
    run bash -c "echo n | ${PASTA} insert ${force_flag} $pasta_name"
    [[ "$status" -eq 0 ]]
    [[ -f "$pasta_file" ]]
    diff -q "$pasta_file" "$PASTA_SETTINGS"
    rm "$pasta_file"
  done
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

@test "pasta insert fails with no arguments" {
  # Replace the default editor with cp to simulate writing something to the file.
  export EDITOR="cp ${PASTA_SETTINGS}"
  for force_flag in "" "-f" "--force"
  do
    ERROR_MSG="testing 'pasta insert $force_flag'"
    run "$PASTA" insert $force_flag
    [[ "$status" -eq 2 ]]
    clean_output
    [[ "$out" =~ ^"Usage: " ]]
    check_no_pastas
  done
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
    ERROR_MSG="testing 'pasta insert' on sneaky path '${sneaky_name}'"
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
  [[ "$(file --mime-type -b "$pasta_file")" == "image/png" ]]
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
  for force_flag in "" "-f" "--force"
  do
    for text_file in "" "$text_file"
    do
      ERROR_MSG="testing 'pasta file ${force_flag} ${text_file}'"
      # Check when no pasta name is given.
      run "$PASTA" file $force_flag $text_file
      [[ "$status" -eq 2 ]]
      clean_output
      [[ "$out" =~ ^"Usage: " ]]
      check_no_pastas
    done
  done
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
    ERROR_MSG="testing 'pasta file' on sneaky path '${sneaky_name}'"
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

@test "pasta file with the force flag doesn't ask for overwrite" {
  text_file="${TMP_DIR}/textfile.txt"
  echo "new data" > "$text_file"
  pasta_name="pasta_name"
  pasta_file="${PASTA_DIR}/${pasta_name}.txt"
  for force_flag in '-f' '--force'
  do
    echo "old data" > "$pasta_file"
    # Echo no to pasta which should be ignored.
    run bash -c "echo n | ${PASTA} file ${force_flag} ${text_file} $pasta_name"
    [[ "$status" -eq 0 ]]
    [[ -f "$pasta_file" ]]
    diff "$pasta_file" "$text_file"
    rm "$pasta_file"
  done
  CLEANUP=1
}

@test "pasta load loads text on the clipboard" {
  pasta_name="textdata"
  text_file="${PASTA_DIR}/${pasta_name}.txt"
  echo "text data" > "$text_file"

  for load_cmd in "" "load"
  do
    ERROR_MSG="testing 'pasta ${load_cmd}'"
    run "$PASTA" $load_cmd "$pasta_name"
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

  for load_cmd in "" "load"
  do
    ERROR_MSG="testing 'pasta ${load_cmd}'"
    run "$PASTA" $load_cmd "$pasta_name"
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

  for load_cmd in "" "load"
  do
    ERROR_MSG="testing 'pasta ${load_cmd}'"
    run "$PASTA" $load_cmd "$pasta_name"
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

  for load_cmd in "" "load"
  do
    for sneaky_name in "${sneaky_names[@]}"
    do
      ERROR_MSG="testing 'pasta ${load_cmd}' on sneaky path '${sneaky_name}'"
      run "$PASTA" $load_cmd "$sneaky_name"
      [[ "$status" -eq 2 ]]
      clean_output
      [[ "$out" =~ "is an invalid pasta name" ]]
      clipboard_is_empty
    done
  done
  CLEANUP=1
}

@test "pasta load fails when a nonexistent pasta is specified" {
  run "$PASTA" nonexistent_pasta
  [[ "$status" -eq 2 ]]
  clean_output
  [[ "$out" =~ "does not exist" ]]
  clipboard_is_empty
  CLEANUP=1
}

@test "pasta show displays a text pasta" {
  text_data="my data"
  pasta_name="textdata"
  pasta_file="${PASTA_DIR}/${pasta_name}.txt"
  echo "$text_data" > "$pasta_file"

  for cmd in "show" "inspect"
  do
    ERROR_MSG="testing 'pasta ${cmd}'"
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
    ERROR_MSG="testing 'pasta ${cmd}'"
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
    ERROR_MSG="testing 'pasta ${show_cmd}'"
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
    ERROR_MSG="testing 'pasta ${cmd}'"
    run "$PASTA" "$cmd" "$pasta_name"
    [[ "$status" -eq 0 ]]
    clean_output
    [[ "$out" == "$text_data" ]]
  done
  CLEANUP=1
}

@test "pasta show rejects sneaky directory traversal names" {
  setup_sneaky_paths_test read

  for sneaky_name in "${sneaky_names[@]}"
  do
    ERROR_MSG="testing 'pasta show' on sneaky path '${sneaky_name}'"
    run "$PASTA" show "$sneaky_name"
    [[ "$status" -eq 2 ]]
    clean_output
    [[ "$out" =~ "is an invalid pasta name" ]]
  done
  CLEANUP=1
}

@test "pasta show fails when a nonexistent pasta is specified" {
  run "$PASTA" inspect nonexistent_pasta
  [[ "$status" -eq 2 ]]
  clean_output
  [[ "$out" =~ "does not exist" ]]
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
  for list_cmd in "list" "ls" "" "load" "show"
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
    ERROR_MSG="testing 'pasta ${list_cmd}'"
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

  for sneaky_name in "${sneaky_names[@]}"
  do
    ERROR_MSG="testing 'pasta ls' on sneaky path '${sneaky_name}'"
    run "$PASTA" ls "$sneaky_name"
    [[ "$status" -eq 2 ]]
    clean_output
    [[ "$out" =~ "is an invalid pasta name" ]]
    [[ ! "$out" =~ "$pasta_name" ]]
  done
  CLEANUP=1
}

@test "pasta list fails when a nonexistent directory is specified" {
  nonexistent_name="nonexistent"
  run "$PASTA" list "$nonexistent_name"
  [[ "$status" -eq 2 ]]
  clean_output
  [[ "$out" =~ "does not exist" ]]
  [[ "$out" =~ "$nonexistent_name" ]]
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

  for list_all_cmd in "" "list" "ls"
  do
    run "$PASTA" $list_all_cmd
    [[ "$status" -eq 0 ]]
    clean_output
    [[ "$out" =~ "$text_dir" ]]
    [[ "$out" =~ "$image_dir" ]]
  done
  CLEANUP=1
}

@test "pasta cp copies a text pasta to the given location" {
  source_name="text_pasta"
  source_file="${PASTA_DIR}/${source_name}.txt"
  echo "text data" > "$source_file"
  dest_name="destination"
  run "$PASTA" cp "$source_name" "$dest_name"
  [[ "$status" -eq 0 ]]
  clean_output
  [[ "$out" =~ ^"Text pasta" ]]
  dest_file="${PASTA_DIR}/${dest_name}.txt"
  [[ -f "$dest_file" ]]
  diff "$source_file" "$dest_file"
  CLEANUP=1
}

@test "pasta cp copies an image pasta to the given location" {
  source_name="image_pasta"
  source_file="${PASTA_DIR}/${source_name}.png"
  create_white_img "$source_file"
  dest_name="destination"
  run "$PASTA" cp "$source_name" "$dest_name"
  [[ "$status" -eq 0 ]]
  clean_output
  [[ "$out" =~ ^"Image pasta" ]]
  dest_file="${PASTA_DIR}/${dest_name}.png"
  [[ -f "$dest_file" ]]
  diff "$source_file" "$dest_file"
  CLEANUP=1
}

@test "pasta cp accepts names with slashes and spaces" {
  source_name="source/text pasta"
  source_file="${PASTA_DIR}/${source_name}.txt"
  ensure_parent_dirs "$source_file"
  echo "text data" > "$source_file"
  dest_name="destination/text pasta"
  run "$PASTA" cp "$source_name" $dest_name
  [[ "$status" -eq 0 ]]
  clean_output
  [[ "$out" =~ ^"Text pasta" ]]
  dest_file="${PASTA_DIR}/${dest_name}.txt"
  [[ -f "$dest_file" ]]
  diff "$source_file" "$dest_file"
  CLEANUP=1
}

@test "pasta cp copies to the destination directory" {
  source_name="text_pasta"
  source_file="${PASTA_DIR}/${source_name}.txt"
  echo "text data" > "$source_file"
  dest_name="directory"
  dummy_path="${PASTA_DIR}/${dest_name}/file.txt"
  ensure_parent_dirs "$dummy_path"
  echo "dummy data" > "$dummy_path"
  run "$PASTA" cp "$source_name" "$dest_name"
  [[ "$status" -eq 0 ]]
  clean_output
  [[ "$out" =~ ^"Text pasta" ]]
  dest_file="${PASTA_DIR}/${dest_name}/${source_name}.txt"
  [[ -f "$dest_file" ]]
  diff "$source_file" "$dest_file"
  CLEANUP=1
}

@test "pasta cp does not overwrite data when the source is a directory" {
  source_name="my_dir"
  source_dir="${PASTA_DIR}/${source_name}"
  mkdir "$source_dir"
  inner_name="foobar"
  inner_file="${source_dir}/${inner_name}.txt"
  echo "some data" > "$inner_file"
  dest_name="my_destination"
  text_file="${PASTA_DIR}/${dest_name}.txt"
  echo "more data" > "$text_file"
  text_backup="${TMP_DIR}/backup.txt"
  cp "$text_file" "$text_backup"
  for recurse_flag in "-r" "--recursive"
  do
    # Echo no to pasta which should be ignored.
    run bash -c "echo n | ${PASTA} cp ${recurse_flag} ${source_name} ${dest_name}"
    [[ "$status" -eq 0 ]]
    clean_output
    [[ "$out" =~ ^Directory ]]
    # Check that the new data was copied over.
    dest_file="${PASTA_DIR}/${dest_name}/${inner_name}.txt"
    [[ -f "$dest_file" ]]
    diff "$dest_file" "$inner_file"
    # Check that the existing text file was not changed.
    [[ -f "$text_file" ]]
    diff "$text_file" "$text_backup"
    rm -r "${PASTA_DIR}/${dest_name}"
  done
  CLEANUP=1
}

@test "pasta cp fails when copying a directory without the recursive flag" {
  dir_name="dir"
  dir_file="${PASTA_DIR}/${dir_name}/file.txt"
  ensure_parent_dirs "$dir_file"
  echo "data" > "$dir_file"
  dest_name="destination"
  run "$PASTA" cp "$dir_name" "$dest_name"
  [[ "$status" -eq 2 ]]
  clean_output
  [[ "$out" =~ "is a directory. Please use the --recursive flag"$ ]]
  [[ ! -e "${PASTA_DIR}/${dest_name}" ]]
  CLEANUP=1
}

@test "pasta cp rejects sneaky directory traversal names" {
  setup_sneaky_paths_test write
  pasta_name="text_pasta"
  pasta_file="${PASTA_DIR}/${pasta_name}.txt"
  for sneaky_name in "${sneaky_names[@]}"
  do
    echo "text data" > "$pasta_file"
    ERROR_MSG="testing 'pasta cp' when destination is sneaky path '${sneaky_name}'"
    run "$PASTA" cp "$pasta_name" "$sneaky_name"
    [[ "$status" -eq 2 ]]
    clean_output
    [[ "$out" =~ "is an invalid pasta name" ]]
    [[ ! -f "${PASTA_DIR}/${sneaky_name}.txt" ]]
    rm "$pasta_file"
    check_no_pastas
  done
  setup_sneaky_paths_test read
  for sneaky_name in "${sneaky_names[@]}"
  do
    ERROR_MSG="testing 'pasta cp' when source is sneaky path '${sneaky_name}'"
    run "$PASTA" cp "$sneaky_name" "$pasta_name"
    [[ "$status" -eq 2 ]]
    clean_output
    [[ "$out" =~ "is an invalid pasta name" ]]
    [[ ! -f "$pasta_file" ]]
  done
  CLEANUP=1
}

@test "pasta cp fails when given too few arguments" {
  source_name="source_name"
  echo data > "${PASTA_DIR}/${source_name}.txt"
  for flags in "" "-f" "--force" "-r" "--recursive" "-v" "--verbose" "-f -r" "--recursive -v -f --"
  do
    for pos_arg in "" "$source_name"
    do
      ERROR_MSG="testing 'pasta cp ${flags} ${pos_arg}'"
      run "$PASTA" cp $flags $pos_arg
      [[ "$status" -eq 2 ]]
      clean_output
      [[ "$out" =~ ^"Usage: " ]]
    done
  done
  CLEANUP=1
}

@test "pasta cp fails when a nonexistent source pasta is specified" {
  run "$PASTA" cp nonexistent destination
  [[ "$status" -eq 2 ]]
  clean_output
  [[ "$out" =~ "does not exist" ]]
  CLEANUP=1
}

@test "pasta cp fails when the source is the destination" {
  pasta_name="same_pasta"
  pasta_file="${PASTA_DIR}/${pasta_name}.txt"
  pasta_data="data"
  echo "$pasta_data" > "${PASTA_DIR}/${pasta_name}.txt"
  run "$PASTA" cp "$pasta_name" "$pasta_name"
  [[ "$status" -eq 2 ]]
  clean_output
  [[ "$out" =~ "are the same pasta"$ ]]
  [[ -f "$pasta_file" ]]
  [[ "$pasta_data" == "$(< "$pasta_file")" ]]

  dir_name="my_dir"
  pasta_dir="${PASTA_DIR}/${dir_name}"
  mkdir "$pasta_dir"
  inner_file="${pasta_dir}/something.txt"
  inner_data="something"
  echo "$inner_data" > "$inner_file"
  run "$PASTA" cp --recursive "$dir_name" "$dir_name"
  [[ "$status" -eq 2 ]]
  clean_output
  [[ "$out" =~ ^"Error: cannot cp directory" ]]
  [[ -f "$inner_file" ]]
  [[ "$inner_data" == "$(< "$inner_file")" ]]
  CLEANUP=1
}

@test "pasta cp works when overwriting" {
  source_text="source_text"
  source_text_file="${PASTA_DIR}/${source_text}.txt"
  echo data > "$source_text_file"
  source_img="source_img"
  source_img_file="${PASTA_DIR}/${source_img}.png"
  source_img2="source_img_2"
  source_img2_file="${PASTA_DIR}/${source_img2}.png"
  create_white_img "$source_img_file" 32 32
  create_white_img "$source_img2_file" 36 36

  overwritten_name="overwritten_pasta"
  overwritten_text="${PASTA_DIR}/${overwritten_name}.txt"
  overwritten_img="${PASTA_DIR}/${overwritten_name}.png"
  echo "different data" > "$overwritten_text"
  overwritten_backup="${TMP_DIR}/backup.txt"
  cp "$overwritten_text" "$overwritten_backup"

  # Test overwriting text with text.
  # Check behavior when no is given.
  run bash -c "echo n | ${PASTA} cp ${source_text} ${overwritten_name}"
  [[ "$status" -eq 3 ]]
  # Data should be the same.
  [[ -f "$overwritten_text" ]]
  diff "$overwritten_text" "$overwritten_backup"
  # Check behavior when yes is given.
  run bash -c "echo y | ${PASTA} cp ${source_text} ${overwritten_name}"
  [[ "$status" -eq 0 ]]
  # Data should be updated.
  [[ -f "$overwritten_text" ]]
  diff "$overwritten_text" "$source_text_file"

  # Test overwriting text with image.
  # Check behavior when no is given.
  run bash -c "echo n | ${PASTA} cp ${source_img} ${overwritten_name}"
  # User rejected overwriting, so data should still be text.
  [[ "$status" -eq 3 ]]
  # Data should be the same.
  [[ -f "$overwritten_text" ]]
  [[ ! -f "$overwritten_img" ]]
  diff "$overwritten_text" "$source_text_file"
  # Check behavior when yes is given.
  run bash -c "echo y | ${PASTA} cp ${source_img} ${overwritten_name}"
  [[ "$status" -eq 0 ]]
  # Data should be updated.
  [[ -f "$overwritten_img" ]]
  [[ ! -f "$overwritten_text" ]]
  diff "$overwritten_img" "$source_img_file"

  # Test overwriting image with image.
  # Check behavior when no is given.
  run bash -c "echo n | ${PASTA} cp ${source_img2} ${overwritten_name}"
  # User rejected overwriting, so data should still be the same.
  [[ "$status" -eq 3 ]]
  # Data should be the same.
  [[ -f "$overwritten_img" ]]
  diff "$overwritten_img" "$source_img_file"
  # Check behavior when yes is given.
  run bash -c "echo y | ${PASTA} cp ${source_img2} ${overwritten_name}"
  [[ "$status" -eq 0 ]]
  # Data should be updated.
  [[ -f "$overwritten_img" ]]
  diff "$overwritten_img" "$source_img2_file"

  # Test overwriting image with text.
  # Check behavior when no is given.
  run bash -c "echo n | ${PASTA} cp ${source_text} ${overwritten_name}"
  # User rejected overwriting, so data should still be image.
  [[ "$status" -eq 3 ]]
  # data Should be the same.
  [[ -f "$overwritten_img" ]]
  [[ ! -f "$overwritten_text" ]]
  diff "$overwritten_img" "$source_img2_file"
  # Check behavior when yes is given.
  run bash -c "echo y | ${PASTA} cp ${source_text} ${overwritten_name}"
  [[ "$status" -eq 0 ]]
  # Data should be updated.
  [[ -f "$overwritten_text" ]]
  [[ ! -f "$overwritten_img" ]]
  diff "$overwritten_text" "$source_text_file"
  CLEANUP=1
}

@test "pasta cp with the force flag doesn't ask for overwrite" {
  source_name="textfile"
  source_file="${PASTA_DIR}/${source_name}.txt"
  echo "new data" > "$source_file"
  dest_name="dest_name"
  dest_file="${PASTA_DIR}/${dest_name}.txt"
  for force_flag in '-f' '--force'
  do
    ERROR_MSG="testing 'pasta cp ${force_flag}'"
    echo "old data" > "$dest_file"
    # Echo no to pasta which should be ignored.
    run bash -c "echo n | ${PASTA} cp ${force_flag} ${source_name} $dest_name"
    [[ "$status" -eq 0 ]]
    [[ -f "$dest_file" ]]
    diff "$dest_file" "$source_file"
    rm "$dest_file"
  done
  CLEANUP=1
}

@test "pasta mv renames a text pasta to the given location" {
  source_name="text_pasta"
  source_file="${PASTA_DIR}/${source_name}.txt"
  source_data="text data"
  dest_name="destination"
  for mv_cmd in "mv" "rename"
  do
    ERROR_MSG="testing 'pasta ${mv_cmd}'"
    echo "$source_data" > "$source_file"
    run "$PASTA" "$mv_cmd" "$source_name" "$dest_name"
    [[ "$status" -eq 0 ]]
    clean_output
    [[ "$out" =~ ^"Text pasta" ]]
    [[ ! -f "$source_file" ]]
    dest_file="${PASTA_DIR}/${dest_name}.txt"
    [[ -f "$dest_file" ]]
    [[ "$source_data" == "$(< "$dest_file")" ]]
    rm "$dest_file"
  done
  CLEANUP=1
}

@test "pasta mv renames an image pasta to the given location" {
  source_name="image_pasta"
  source_file="${PASTA_DIR}/${source_name}.png"
  backup_file="${TMP_DIR}/backup.png"
  dest_name="destination"
  for mv_cmd in "mv" "rename"
  do
    create_white_img "$source_file"
    cp "$source_file" "$backup_file"
    run "$PASTA" "$mv_cmd" "$source_name" "$dest_name"
    [[ "$status" -eq 0 ]]
    clean_output
    [[ "$out" =~ ^"Image pasta" ]]
    [[ ! -f "$source_file" ]]
    dest_file="${PASTA_DIR}/${dest_name}.png"
    [[ -f "$dest_file" ]]
    diff "$dest_file" "$backup_file"
    rm "$dest_file"
  done
  CLEANUP=1
}

@test "pasta mv accepts names with slashes and spaces" {
  source_name="source/text pasta"
  source_file="${PASTA_DIR}/${source_name}.txt"
  source_data="text data"
  dest_name="destination/text pasta"
  for mv_cmd in "mv" "rename"
  do
    ensure_parent_dirs "$source_file"
    echo "$source_data" > "$source_file"
    run "$PASTA" mv "$source_name" $dest_name
    [[ "$status" -eq 0 ]]
    clean_output
    [[ "$out" =~ ^"Text pasta" ]]
    [[ ! -f "$source_file" ]]
    [[ ! -d "$(dirname "$source_file")" ]]
    dest_file="${PASTA_DIR}/${dest_name}.txt"
    [[ -f "$dest_file" ]]
    [[ "$source_data" == "$(< "$dest_file")" ]]
    rm -r "$(dirname "$dest_file")"
  done
  CLEANUP=1
}

@test "pasta mv renames to the destination directory" {
  source_name="text_pasta"
  source_file="${PASTA_DIR}/${source_name}.txt"
  source_data="text data"
  echo "$source_data" > "$source_file"
  dest_name="directory"
  dummy_path="${PASTA_DIR}/${dest_name}/file.txt"
  ensure_parent_dirs "$dummy_path"
  echo "dummy data" > "$dummy_path"
  run "$PASTA" mv "$source_name" "$dest_name"
  [[ "$status" -eq 0 ]]
  clean_output
  [[ "$out" =~ ^"Text pasta" ]]
  [[ ! -f "$source_file" ]]
  dest_file="${PASTA_DIR}/${dest_name}/${source_name}.txt"
  [[ -f "$dest_file" ]]
  [[ "$source_data" == "$(< "$dest_file")" ]]
  CLEANUP=1
}

@test "pasta mv does not overwrite data when the source is a directory" {
  source_name="my_dir"
  source_dir="${PASTA_DIR}/${source_name}"
  mkdir "$source_dir"
  inner_name="foobar"
  inner_file="${source_dir}/${inner_name}.txt"
  inner_data="some data"
  echo "$inner_data" > "$inner_file"
  dest_name="my_destination"
  text_file="${PASTA_DIR}/${dest_name}.txt"
  text_data="more data"
  echo "$text_data" > "$text_file"
  # Echo no to pasta which should be ignored.
  run bash -c "echo n | ${PASTA} mv ${source_name} ${dest_name}"
  [[ "$status" -eq 0 ]]
  clean_output
  [[ "$out" =~ ^Directory ]]
  [[ ! -d "$source_dir" ]]
  # Check that the new data was copied over.
  dest_file="${PASTA_DIR}/${dest_name}/${inner_name}.txt"
  [[ -f "$dest_file" ]]
  [[ "$inner_data" == "$(< "$dest_file")" ]]
  # Check that the existing text file was not changed.
  [[ -f "$text_file" ]]
  [[ "$text_data" == "$(< "$text_file")" ]]
  CLEANUP=1
}

@test "pasta mv rejects sneaky directory traversal names" {
  setup_sneaky_paths_test write
  pasta_name="text_pasta"
  pasta_file="${PASTA_DIR}/${pasta_name}.txt"
  for sneaky_name in "${sneaky_names[@]}"
  do
    echo "text data" > "$pasta_file"
    ERROR_MSG="testing 'pasta mv' when destination is sneaky path '${sneaky_name}'"
    run "$PASTA" mv "$pasta_name" "$sneaky_name"
    [[ "$status" -eq 2 ]]
    clean_output
    [[ "$out" =~ "is an invalid pasta name" ]]
    [[ -f "$pasta_file" ]]
    [[ ! -f "${PASTA_DIR}/${sneaky_name}.txt" ]]
    rm "$pasta_file"
    check_no_pastas
  done
  setup_sneaky_paths_test read
  for sneaky_name in "${sneaky_names[@]}"
  do
    ERROR_MSG="testing 'pasta mv' when source is sneaky path '${sneaky_name}'"
    run "$PASTA" mv "$sneaky_name" "$pasta_name"
    [[ "$status" -eq 2 ]]
    clean_output
    [[ "$out" =~ "is an invalid pasta name" ]]
    [[ ! -f "$pasta_file" ]]
  done
  CLEANUP=1
}

@test "pasta mv fails when given too few arguments" {
  source_name="source_name"
  source_file="${PASTA_DIR}/${source_name}.txt"
  echo data > "$source_file"
  for flags in "" "-f" "--force" "-v" "--verbose" "-f -v" "--verbose --force --"
  do
    for pos_arg in "" "$source_name"
    do
      ERROR_MSG="testing 'pasta mv ${flags} ${pos_arg}'"
      run "$PASTA" mv $flags $pos_arg
      [[ "$status" -eq 2 ]]
      clean_output
      [[ "$out" =~ ^"Usage: " ]]
      [[ -f "$source_file" ]]
    done
  done
  CLEANUP=1
}

@test "pasta mv fails when a nonexistent source pasta is specified" {
  run "$PASTA" mv nonexistent destination
  [[ "$status" -eq 2 ]]
  clean_output
  [[ "$out" =~ "does not exist" ]]
  CLEANUP=1
}

@test "pasta mv fails when the source is the destination" {
  pasta_name="same_pasta"
  pasta_file="${PASTA_DIR}/${pasta_name}.txt"
  pasta_data="data"
  echo "$pasta_data" > "$pasta_file"
  run "$PASTA" mv "$pasta_name" "$pasta_name"
  [[ "$status" -eq 2 ]]
  clean_output
  [[ "$out" =~ "are the same pasta"$ ]]
  [[ -f "$pasta_file" ]]
  [[ "$pasta_data" == "$(< "$pasta_file")" ]]

  dir_name="my_dir"
  pasta_dir="${PASTA_DIR}/${dir_name}"
  mkdir "$pasta_dir"
  inner_file="${pasta_dir}/something.txt"
  inner_data="something"
  echo "$inner_data" > "$inner_file"
  run "$PASTA" mv "$dir_name" "$dir_name"
  [[ "$status" -eq 2 ]]
  clean_output
  [[ "$out" =~ ^"Error: cannot mv directory" ]]
  [[ -f "$inner_file" ]]
  [[ "$inner_data" == "$(< "$inner_file")" ]]
  CLEANUP=1
}

@test "pasta mv works when overwriting" {
  source_text="source_text"
  source_text_file="${PASTA_DIR}/${source_text}.txt"
  source_text_data="data"
  echo "$source_text_data" > "$source_text_file"
  source_text2="source_text_2"
  source_text2_file="${PASTA_DIR}/${source_text2}.txt"
  source_text2_data="different data"
  echo "$source_text2_data" > "$source_text2_file"
  source_img="source_img"
  source_img_file="${PASTA_DIR}/${source_img}.png"
  source_img2="source_img_2"
  source_img2_file="${PASTA_DIR}/${source_img2}.png"
  create_white_img "$source_img_file" 32 32
  source_img_backup="${TMP_DIR}/backup1.png"
  cp "$source_img_file" "$source_img_backup"
  create_white_img "$source_img2_file" 36 36
  source_img2_backup="${TMP_DIR}/backup2.png"
  cp "$source_img2_file" "$source_img2_backup"

  overwritten_name="overwritten_pasta"
  overwritten_text="${PASTA_DIR}/${overwritten_name}.txt"
  overwritten_img="${PASTA_DIR}/${overwritten_name}.png"
  overwritten_text_data="different data"
  echo "$overwritten_text_data" > "$overwritten_text"

  # Test overwriting text with text.
  # Check behavior when no is given.
  run bash -c "echo n | ${PASTA} mv ${source_text} ${overwritten_name}"
  [[ "$status" -eq 3 ]]
  # Data should be the same.
  [[ -f "$source_text_file" ]]
  [[ -f "$overwritten_text" ]]
  [[ "$overwritten_text_data" == "$(< "$overwritten_text")" ]]
  # Check behavior when yes is given.
  run bash -c "echo y | ${PASTA} mv ${source_text} ${overwritten_name}"
  [[ "$status" -eq 0 ]]
  # Data should be updated.
  [[ ! -f "$source_text_file" ]]
  [[ -f "$overwritten_text" ]]
  [[ "$source_text_data" == "$(< "$overwritten_text")" ]]

  # Test overwriting text with image.
  # Check behavior when no is given.
  run bash -c "echo n | ${PASTA} mv ${source_img} ${overwritten_name}"
  # User rejected overwriting, so data should still be text.
  [[ "$status" -eq 3 ]]
  # Data should be the same.
  [[ -f "$source_img_file" ]]
  [[ -f "$overwritten_text" ]]
  [[ ! -f "$overwritten_img" ]]
  [[ "$source_text_data" == "$(< "$overwritten_text")" ]]
  # Check behavior when yes is given.
  run bash -c "echo y | ${PASTA} mv ${source_img} ${overwritten_name}"
  [[ "$status" -eq 0 ]]
  # Data should be updated.
  [[ ! -f "$source_img_file" ]]
  [[ -f "$overwritten_img" ]]
  [[ ! -f "$overwritten_text" ]]
  diff "$overwritten_img" "$source_img_backup"

  # Test overwriting image with image.
  # Check behavior when no is given.
  run bash -c "echo n | ${PASTA} mv ${source_img2} ${overwritten_name}"
  # User rejected overwriting, so data should still be the same.
  [[ "$status" -eq 3 ]]
  # Data should be the same.
  [[ -f "$source_img2_file" ]]
  [[ -f "$overwritten_img" ]]
  diff "$overwritten_img" "$source_img_backup"
  # Check behavior when yes is given.
  run bash -c "echo y | ${PASTA} mv ${source_img2} ${overwritten_name}"
  [[ "$status" -eq 0 ]]
  # Data should be updated.
  [[ ! -f "$source_img2_file" ]]
  [[ -f "$overwritten_img" ]]
  diff "$overwritten_img" "$source_img2_backup"

  # Test overwriting image with text.
  # Check behavior when no is given.
  run bash -c "echo n | ${PASTA} mv ${source_text2} ${overwritten_name}"
  # User rejected overwriting, so data should still be image.
  [[ "$status" -eq 3 ]]
  # data Should be the same.
  [[ -f "$source_text2_file" ]]
  [[ -f "$overwritten_img" ]]
  [[ ! -f "$overwritten_text" ]]
  diff "$overwritten_img" "$source_img2_backup"
  # Check behavior when yes is given.
  run bash -c "echo y | ${PASTA} mv ${source_text2} ${overwritten_name}"
  [[ "$status" -eq 0 ]]
  # Data should be updated.
  [[ ! -f "$source_text2_file" ]]
  [[ -f "$overwritten_text" ]]
  [[ ! -f "$overwritten_img" ]]
  [[ "$source_text2_data" == "$(< "$overwritten_text")" ]]
  CLEANUP=1
}

@test "pasta mv with the force flag doesn't ask for overwrite" {
  source_name="textfile"
  source_file="${PASTA_DIR}/${source_name}.txt"
  source_data="new data"
  dest_name="dest_name"
  dest_file="${PASTA_DIR}/${dest_name}.txt"
  for force_flag in '-f' '--force'
  do
    ERROR_MSG="testing 'pasta mv ${force_flag}'"
    echo "$source_data" > "$source_file"
    echo "old data" > "$dest_file"
    # Echo no to pasta which should be ignored.
    run bash -c "echo n | ${PASTA} mv ${force_flag} ${source_name} $dest_name"
    [[ "$status" -eq 0 ]]
    [[ -f "$dest_file" ]]
    [[ ! -f "$source_file" ]]
    [[ "$source_data" == "$(< "$dest_file")" ]]
    rm "$dest_file"
  done
  CLEANUP=1
}
