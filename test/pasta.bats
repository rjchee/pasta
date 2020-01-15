#!/usr/bin/env bats

set -euo pipefail

load test_helper

setup() {
  TMP_DIR="$(mktemp -d -p "$BATS_TMPDIR" bats_pasta_test.XXX)"
  PASTA_DIR="${TMP_DIR}/pastas"
  export PASTA_SETTINGS="${TMP_DIR}/settings"
  export DEBUG=true
  PASTA="$(realpath "${BATS_TEST_DIRNAME}/../pasta")"
  run "$PASTA" init "$PASTA_DIR"
  [[ "$status" -eq 0 ]]
  $clear_clip
  CLEANUP=0
  # make the environment in a known state
  unset EDITOR
}

teardown() {
  [[ "$CLEANUP" -eq 0 ]] && echo "$output" > "${TMP_DIR}/run_output.txt" && echo "# test case run in ${TMP_DIR}" || rm -rf "${TMP_DIR}"
  $clear_clip
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
  create_random_img "$image_file"
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
  create_random_img "$image_file"
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
  # clipboard should be cleared from the setup() function
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

@test "pasta save with no arguments should fail" {
  run "$PASTA" save
  [[ "$status" -eq 2 ]]
  clean_output
  [[ "$out" =~ "Usage: " ]]
  check_no_pastas
  CLEANUP=1
}

@test "pasta save works as expected when the pasta name is duplicated" {
  text1="first text data"
  argcopy "$text1"
  pasta_name="textdata"
  run "$PASTA" save $pasta_name
  [[ "$status" -eq 0 ]]
  pasta_file="${PASTA_DIR}/${pasta_name}.txt"
  [[ -f "$pasta_file" ]]
  [[ "$text1" == "$(< "$pasta_file")" ]]
  text2="second data version"
  argcopy "$text2"
  # check behavior when no is given
  run bash -c "echo n | ${PASTA} save ${pasta_name}"
  [[ "$status" -eq 3 ]]
  # data should be the same
  [[ "$text1" == "$(< "$pasta_file")" ]]
  # check behavior when yes is given
  run bash -c "echo y | ${PASTA} save ${pasta_name}"
  [[ "$status" -eq 0 ]]
  # data should be updated
  [[ -f "$pasta_file" ]]
  [[ "$text2" == "$(< "$pasta_file")" ]]
  CLEANUP=1
}

@test "pasta insert calls the editor" {
  # replace the default editor with cp to simulate writing something to the file
  export EDITOR="cp ${PASTA_SETTINGS}"
  pasta_name="insert_test"
  run "$PASTA" insert $pasta_name
  [[ "$status" -eq 0 ]]
  pasta_file="${PASTA_DIR}/${pasta_name}.txt"
  [[ -f "$pasta_file" ]]
  CLEANUP=1
}

@test "pasta insert works when overwriting" {
  # replace the default editor with cp to simulate writing something to the file
  export EDITOR="cp ${PASTA_SETTINGS}"
  pasta_name="overwrite_test"
  run "$PASTA" insert $pasta_name
  [[ "$status" -eq 0 ]]
  # store the value of the file's access time for checking if it was touched
  pasta_file="${PASTA_DIR}/${pasta_name}.txt"
  [[ -f "$pasta_file" ]]
  access_time="$(stat -c '%.Y' "$pasta_file")"
  # check if choosing not to overwrite opens the editor
  run bash -c "echo n | ${PASTA} insert ${pasta_name}"
  [[ "$status" -eq 3 ]]
  # check whether touch was called, modifying the access time
  [[ "$access_time" == "$(stat -c '%.Y' "$pasta_file")" ]]
  # check if choosing to overwrite opens the editor
  run bash -c "echo y | ${PASTA} insert ${pasta_name}"
  # if the command succeeds, the editor was run on a file which already exists, which is what we want"
  [[ "$status" -eq 0 ]]
  # check whether touch was called, modifying the access time
  [[ "$access_time" != "$(stat -c '%.Y' "$pasta_file")" ]]
  CLEANUP=1
}

@test "pasta insert without writing anything should fail" {
  # replace the default editor with true to simulate a no-op
  export EDITOR=true
  run "$PASTA" insert pasta_name
  [[ "$status" -eq 3 ]]
  clean_output
  [[ "$out" == "Pasta not created." ]]
  check_no_pastas
  CLEANUP=1
}

@test "pasta insert with no arguments should fail" {
  # replace the default editor with cp to simulate writing something to the file
  export EDITOR="cp ${PASTA_SETTINGS}"
  run "$PASTA" insert
  [[ "$status" -eq 2 ]]
  clean_output
  [[ "$out" =~ ^"Usage: " ]]
  check_no_pastas
  CLEANUP=1
}

@test "pasta insert works when the editor is not set" {
  # create a temporary vi executable to replace the existing vi
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
  # replace the default editor with cp to simulate writing something to the file
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
  # replace the default editor with cp to simulate writing something to the file
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
  get_random_text >"$text_file"
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
  create_random_img "$image_file"
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
  create_random_img "$image_file"
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
  get_random_text >"$text_file"
  run "$PASTA" file "$text_file" $pasta_name
  [[ "$status" -eq 0 ]]
  pasta_file="${PASTA_DIR}/${pasta_name}.txt"
  [[ -f "$pasta_file" ]]
  diff "$text_file" "$pasta_file"
  CLEANUP=1
}

@test "pasta file fails when given too few arguments" {
  text_file="${TMP_DIR}/textfile.txt"
  get_random_text >"$text_file"
  run "$PASTA" file "$text_file"
  [[ "$status" -eq 2 ]]
  clean_output
  [[ "$out" =~ "Usage: " ]]
  check_no_pastas
  # check if 0 arguments are given
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
  # sanity check to make sure this file is not detected as an image or text
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
  get_random_text >"$text_file"

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
