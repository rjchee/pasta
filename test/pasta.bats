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
  argcopy "$BATS_TEST_DESCRIPTION"
  run "$PASTA" save ..
  [[ "$status" -eq 2 ]]
  clean_output
  echo "$out" | grep 'is an invalid pasta name'
  check_no_pastas

  run "$PASTA" save "../dot dot in front"
  [[ "$status" -eq 2 ]]
  clean_output
  echo "$out" | grep 'is an invalid pasta name'
  check_no_pastas

  run "$PASTA" save "dot dot in back/.."
  [[ "$status" -eq 2 ]]
  clean_output
  echo "$out" | grep 'is an invalid pasta name'
  check_no_pastas

  run "$PASTA" save "dot dot/../../in middle"
  [[ "$status" -eq 2 ]]
  clean_output
  echo "$out" | grep 'is an invalid pasta name'
  check_no_pastas

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
  echo "$out" | grep 'unknown MIME type'
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
  tmp_bin="${TMP_DIR}/bin"
  mkdir "$tmp_bin"
  tmp_vi="${tmp_bin}/vi"
  {
    echo '#!/bin/bash'
    echo 'set -eu'
    echo 'cp '"${PASTA_SETTINGS}"' "$1"'
  } > "$tmp_vi"
  chmod +x "$tmp_vi"
  export PATH="${tmp_bin}:${PATH}"
  pasta_name="pasta_name"
  run "$PASTA" insert $pasta_name
  [[ "$status" -eq 0 ]]
  pasta_file="${PASTA_DIR}/${pasta_name}.txt"
  [[ -f "$pasta_file" ]]
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
  # Replace the default editor with cp to simulate writing something to the file.
  export EDITOR="cp ${PASTA_SETTINGS}"
  argcopy "$BATS_TEST_DESCRIPTION"
  run "$PASTA" insert ..
  [[ "$status" -eq 2 ]]
  clean_output
  echo "$out" | grep 'is an invalid pasta name'
  check_no_pastas

  run "$PASTA" insert "../dot dot in front"
  [[ "$status" -eq 2 ]]
  clean_output
  echo "$out" | grep 'is an invalid pasta name'
  check_no_pastas

  run "$PASTA" insert "dot dot in back/.."
  [[ "$status" -eq 2 ]]
  clean_output
  echo "$out" | grep 'is an invalid pasta name'
  check_no_pastas

  run "$PASTA" insert "dot dot/../../in middle"
  [[ "$status" -eq 2 ]]
  clean_output
  echo "$out" | grep 'is an invalid pasta name'
  check_no_pastas

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
  echo "$out" | grep 'unknown MIME type'
  check_no_pastas
  CLEANUP=1
}

@test "pasta file fails when given a non-existent file" {
  run "$PASTA" file "${TMP_DIR}/fake_file.txt" pasta_name
  [[ "$status" -eq 2 ]]
  clean_output
  echo "$out" | grep 'no file' | grep 'exists'
  check_no_pastas
  CLEANUP=1
}

@test "pasta file fails when given an empty file" {
  empty_file="${TMP_DIR}/empty.txt"
  touch "$empty_file"
  run "$PASTA" file "${empty_file}" empty_pasta
  [[ "$status" -eq 2 ]]
  clean_output
  echo "$out" | grep 'is empty'
  check_no_pastas
  CLEANUP=1
}

@test "pasta file fails when given a directory" {
  dir_name="${TMP_DIR}/dir"
  mkdir "$dir_name"
  run "$PASTA" file "$dir_name" pasta_name
  [[ "$status" -eq 2 ]]
  clean_output
  echo "$out" | grep 'is a directory'
  check_no_pastas
  CLEANUP=1
}

@test "pasta file rejects sneaky directory traversal names" {
  text_file="${TMP_DIR}/textfile.txt"
  echo "text data" >"$text_file"

  run "$PASTA" file "$text_file" ..
  [[ "$status" -eq 2 ]]
  clean_output
  echo "$out" | grep 'is an invalid pasta name'
  check_no_pastas

  run "$PASTA" file "$text_file" "../dot dot in front"
  [[ "$status" -eq 2 ]]
  clean_output
  echo "$out" | grep 'is an invalid pasta name'
  check_no_pastas

  run "$PASTA" file "$text_file" "dot dot in back/.."
  [[ "$status" -eq 2 ]]
  clean_output
  echo "$out" | grep 'is an invalid pasta name'
  check_no_pastas

  run "$PASTA" file "$text_file" "dot dot/../../in middle"
  [[ "$status" -eq 2 ]]
  clean_output
  echo "$out" | grep 'is an invalid pasta name'
  check_no_pastas

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

  run "$PASTA" load "$pasta_name"
  [[ "$status" -eq 0 ]]
  pasted_file="${TMP_DIR}/pasted.txt"
  $paste_text >"$pasted_file"
  diff "$text_file" "$pasted_file"

  CLEANUP=1
}

@test "pasta load loads images on the clipboard" {
  pasta_name="imagedata"
  image_file="${PASTA_DIR}/${pasta_name}.png"
  create_white_img "$image_file"

  run "$PASTA" load "$pasta_name"
  [[ "$status" -eq 0 ]]
  pasted_file="${TMP_DIR}/pasted.png"
  $paste_text >"$pasted_file"
  diff "$image_file" "$pasted_file"

  CLEANUP=1
}

@test "pasta load works without specifying the first argument" {
  pasta_name="textdata"
  text_file="${PASTA_DIR}/${pasta_name}.txt"
  echo "text_data" > "$text_file"

  run "$PASTA" "$pasta_name"
  [[ "$status" -eq 0 ]]
  pasted_file="${TMP_DIR}/pasted.txt"
  $paste_text >"$pasted_file"
  diff "$text_file" "$pasted_file"

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
  cd "$PASTA_DIR"
  run "$PASTA" load ..
  [[ "$status" -eq 2 ]]
  clean_output
  echo "$out" | grep 'is an invalid pasta name'
  clipboard_is_empty

  sneaky_text_name_1="../dot dot in front"
  echo "sneaky data 1" > "$(pwd)/${sneaky_text_name_1}.txt"
  run "$PASTA" "$sneaky_text_name_1"
  [[ "$status" -eq 2 ]]
  clean_output
  echo "$out" | grep 'is an invalid pasta name'
  clipboard_is_empty

  run "$PASTA" "dot dot in back/.."
  [[ "$status" -eq 2 ]]
  clean_output
  echo "$out" | grep 'is an invalid pasta name'
  clipboard_is_empty

  inner_dir="dot dot"
  mkdir "$inner_dir"
  sneaky_text_name_2="${inner_dir}/../../in middle"
  echo "sneaky data 2" > "$(pwd)/${sneaky_text_name_2}.txt"
  run "$PASTA" load "$sneaky_text_name_2"
  [[ "$status" -eq 2 ]]
  clean_output
  echo "$out" | grep 'is an invalid pasta name'
  clipboard_is_empty

  CLEANUP=1
}

@test "pasta load fails when no name is specified" {
  run "$PASTA" load
  [[ "$status" -eq 2 ]]
  clean_output
  [[ "$out" =~ "Usage: " ]]
  clipboard_is_empty
  CLEANUP=1
}

@test "pasta load fails when a non-existent pasta is specified" {
  run "${PASTA}" nonexistent pasta
  [[ "$status" -eq 2 ]]
  clean_output
  echo "$out" | grep 'does not exist'
  clipboard_is_empty

  CLEANUP=1
}
