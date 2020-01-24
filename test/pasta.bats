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
    [[ "$out" =~ ^"Usage: ".*" save " ]]
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
  text_data="data"
  echo "$text_data" > "$text_file"

  # Test if overwriting text.
  # Check if choosing not to overwrite opens the editor.
  run bash -c "echo n | ${PASTA} insert ${pasta_name}"
  [[ "$status" -eq 3 ]]
  # Contents should be the same because it was not overwritten.
  [[ -f "$text_file" ]]
  [[ "$text_data" == "$(< "$text_file")" ]]
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
    [[ "$out" =~ ^"Usage: ".*" insert " ]]
    check_no_pastas
  done
  CLEANUP=1
}

@test "pasta insert calls the default editor when EDITOR is not set" {
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
  diff "$PASTA_SETTINGS" "$pasta_file"
  CLEANUP=1
}

@test "pasta insert rejects sneaky directory traversal names" {
  setup_sneaky_paths_test write
  mock_command vi
  for sneaky_name in "${sneaky_names[@]}"
  do
    ERROR_MSG="testing 'pasta insert' on sneaky path '${sneaky_name}'"
    run "$PASTA" insert "$sneaky_name"
    [[ "$status" -eq 2 ]]
    clean_output
    [[ "$out" =~ "is an invalid pasta name" ]]
    ! mock_called vi
    check_no_pastas
  done
  CLEANUP=1
}

@test "pasta edit calls the editor" {
  # Replace the default editor with cp to simulate writing something to the file.
  export EDITOR="cp ${PASTA_SETTINGS}"
  pasta_name="edit_test"
  pasta_file="${PASTA_DIR}/${pasta_name}.txt"
  echo "existing data" > "$pasta_file"
  run "$PASTA" edit $pasta_name
  [[ "$status" -eq 0 ]]
  [[ -f "$pasta_file" ]]
  diff -q "$pasta_file" "$PASTA_SETTINGS"
  CLEANUP=1
}

@test "pasta edit calls the default editor when EDITOR is not set" {
  mock_command vi
  pasta_name="edit_test"
  pasta_file="${PASTA_DIR}/${pasta_name}.txt"
  echo "existing data" > "$pasta_file"
  run "$PASTA" edit $pasta_name
  [[ "$status" -eq 0 ]]
  [[ -f "$pasta_file" ]]
  mock_called vi vi_arg
  [[ "$vi_arg" -ef "$pasta_file" ]]
  CLEANUP=1
}

@test "pasta edit accepts names with slashes and spaces" {
  # Replace the default editor with cp to simulate writing something to the file.
  export EDITOR="cp ${PASTA_SETTINGS}"
  pasta_name='edit/slashes/and spaces/in name'
  pasta_file="${PASTA_DIR}/${pasta_name}.txt"
  ensure_parent_dirs "$pasta_file"
  echo "existing data" > "$pasta_file"
  run "$PASTA" edit $pasta_name
  [[ "$status" -eq 0 ]]
  [[ -f "$pasta_file" ]]
  diff "$PASTA_SETTINGS" "$pasta_file"
  CLEANUP=1
}

@test "pasta edit deletes a pasta if the editor makes it empty" {
  # Replace the default editor with truncate to simulate deleting the contents of the file
  export EDITOR="truncate -s0"
  pasta_name="pasta_name"
  echo "existing data" > "${PASTA_DIR}/${pasta_name}.txt"
  run "$PASTA" edit "$pasta_name"
  [[ "$status" -eq 0 ]]
  clean_output
  [[ "$out" =~ ^"Deleted empty text pasta" ]]
  check_no_pastas
  CLEANUP=1
}

@test "pasta edit deletes a pasta and empty parent directories if the edit makes it empty" {
  # Replace the default editor with truncate to simulate deleting the contents of the file
  export EDITOR="truncate -s0"
  pasta_name="dir/pasta_name"
  pasta_file="${PASTA_DIR}/${pasta_name}.txt"
  ensure_parent_dirs "$pasta_file"
  echo "existing data" > "$pasta_file"
  run "$PASTA" edit "$pasta_name"
  [[ "$status" -eq 0 ]]
  clean_output
  [[ "$out" =~ ^"Deleted empty text pasta" ]]
  check_no_pastas
  CLEANUP=1
}

@test "pasta edit rejects sneaky directory traversal names" {
  setup_sneaky_paths_test read
  mock_command vi
  for sneaky_name in "${sneaky_names[@]}"
  do
    ERROR_MSG="testing 'pasta insert' on sneaky path '${sneaky_name}'"
    run "$PASTA" edit "$sneaky_name"
    [[ "$status" -eq 2 ]]
    clean_output
    [[ "$out" =~ "is an invalid pasta name" ]]
    ! mock_called vi
  done
  CLEANUP=1
}

@test "pasta edit fails with no arguments" {
  mock_command vi
  run "$PASTA" edit
  [[ "$status" -eq 2 ]]
  clean_output
  [[ "$out" =~ ^"Usage: ".*" edit " ]]
  ! mock_called vi
  check_no_pastas
  CLEANUP=1
}

@test "pasta edit fails when a nonexistent pasta is specified" {
  mock_command vi
  run "$PASTA" edit nonexistent
  [[ "$status" -eq 2 ]]
  clean_output
  [[ "$out" =~ "does not exist" ]]
  ! mock_called vi
  check_no_pastas
  CLEANUP=1
}

@test "pasta edit fails when given a non-text pasta" {
  mock_command vi
  img_pasta="image_pasta"
  img_file="${PASTA_DIR}/${img_pasta}.png"
  create_white_img "$img_file"
  run "$PASTA" edit "$img_pasta"
  [[ "$status" -eq 2 ]]
  clean_output
  [[ "$out" =~ ^"Error: cannot edit image pasta" ]]
  ! mock_called vi

  dir_name="my_dir"
  pasta_dir="${PASTA_DIR}/${dir_name}"
  mkdir "$pasta_dir"
  echo data > "${pasta_dir}/text_pasta.txt"
  run "$PASTA" edit "$dir_name"
  [[ "$status" -eq 2 ]]
  clean_output
  [[ "$out" =~ ^"Error: cannot edit directory" ]]
  ! mock_called vi
  CLEANUP=1
}

@test "pasta import saves a text file" {
  text_file="${TMP_DIR}/textfile.txt"
  pasta_name="textdata"
  echo "text data" >"$text_file"
  run "$PASTA" import "$text_file" $pasta_name
  [[ "$status" -eq 0 ]]
  pasta_file="${PASTA_DIR}/${pasta_name}.txt"
  [[ -f "$pasta_file" ]]
  diff "$text_file" "$pasta_file"
  CLEANUP=1
}

@test "pasta import saves a PNG file" {
  image_file="${TMP_DIR}/image.png"
  pasta_name="png"
  create_white_img "$image_file"
  run "$PASTA" import "$image_file" $pasta_name
  [[ "$status" -eq 0 ]]
  pasta_file="${PASTA_DIR}/${pasta_name}.png"
  [[ -f "$pasta_file" ]]
  diff "$image_file" "$pasta_file"
  CLEANUP=1
}

@test "pasta import saves a JPG file" {
  image_file="${TMP_DIR}/image.jpg"
  pasta_name="jpg"
  create_white_img "$image_file"
  run "$PASTA" import "$image_file" $pasta_name
  [[ "$status" -eq 0 ]]
  pasta_file="${PASTA_DIR}/${pasta_name}.png"
  [[ -f "$pasta_file" ]]
  [[ "$(file --mime-type -b "$pasta_file")" == "image/png" ]]
  imgdiff "$image_file" "$pasta_file"
  CLEANUP=1
}

@test "pasta import imports a directory" {
  dir_name="my_dir"
  external_dir="${TMP_DIR}/${dir_name}"
  mkdir "$external_dir"
  text_name="${dir_name}/my_text"
  text_file="${TMP_DIR}/${text_name}.txt"
  echo data > "$text_file"
  jpg_name="my_jpg"
  jpg_file="${TMP_DIR}/${jpg_name}.jpg"
  create_white_img "$jpg_file" 15 15
  inner_dir_name="${dir_name}/inner_dir"
  inner_dir="${TMP_DIR}/${inner_dir_name}"
  mkdir "${inner_dir}"
  png_name="${inner_dir_name}/my_png"
  png_file="${TMP_DIR}/${png_name}.png"
  create_white_img "$png_file" 12 12

  new_dir_name="imported_dir"
  pasta_new_dir="${PASTA_DIR}/${new_dir_name}"
  pasta_text_file="${pasta_new_dir}/${text_name}.txt"
  pasta_jpg_file="${pasta_new_dir}/${jpg_name}.png"
  pasta_dir_path="${pasta_new_dir}/${inner_dir_name}"
  pasta_png_file="${pasta_new_dir}/${png_name}.png"
  for recurse_flag in "-r" "--recursive"
  do
    ERROR_MSG="testing 'pasta import ${recurse_flag}'"
    run "$PASTA" import "$recurse_flag" "$external_dir" "$new_dir_name"
    [[ "$status" -eq 0 ]]
    clean_output
    [[ "$out" =~ "Created text pasta" ]]
    [[ -f "$pasta_text_file" ]]
    diff "$pasta_text_file" "$text_file"
    [[ "$out" =~ "Created image pasta".*"Created image pasta" ]]
    [[ -f "$pasta_jpg_file" ]]
    imgdiff "$pasta_jpg_file" "$jpg_file"
    [[ -d "$pasta_dir_path" ]]
    [[ -f "$pasta_png_file" ]]
    diff "$pasta_png_file" "$png_file"
    rm -r "$pasta_new_dir"
  done
  CLEANUP=1
}

@test "pasta import imports a compressed file" {
  CLEANUP=1
  skip "This functionality has not been implemented yet"
}

@test "pasta import accepts names with slashes and spaces" {
  pasta_name="file/slashes/and spaces/in/name"
  text_file="${TMP_DIR}/textfile.txt"
  echo "text data" >"$text_file"
  run "$PASTA" import "$text_file" $pasta_name
  [[ "$status" -eq 0 ]]
  pasta_file="${PASTA_DIR}/${pasta_name}.txt"
  [[ -f "$pasta_file" ]]
  diff "$text_file" "$pasta_file"
  CLEANUP=1
}

@test "pasta import fails when given too few arguments" {
  text_file="${TMP_DIR}/textfile.txt"
  echo "text data" >"$text_file"
  for force_flag in "" "-f" "--force"
  do
    for recurse_flag in "" "-r" "--recursive"
    do
      ERROR_MSG="testing 'pasta import ${force_flag} ${recurse_flag}'"
      # Check when no pasta name is given.
      run "$PASTA" import $force_flag $recurse_flag
      [[ "$status" -eq 2 ]]
      clean_output
      [[ "$out" =~ ^"Usage: ".*" import " ]]
      check_no_pastas
    done
  done
  CLEANUP=1
}

@test "pasta import assumes the pasta name from the filename if not specified" {
  text_name="my_text"
  text_file="${TMP_DIR}/${text_name}.txt"
  echo "data" > "$text_file"
  run "$PASTA" import "$text_file"
  [[ "$status" -eq 0 ]]
  clean_output
  [[ "$out" =~ ^"Created text pasta" ]]
  pasta_file="${PASTA_DIR}/${text_name}.txt"
  [[ -f "$pasta_file" ]]
  diff "$pasta_file" "$text_file"

  jpg_name="my_jpg"
  jpg_file="${TMP_DIR}/${jpg_name}.jpg"
  create_white_img "$jpg_file" 15 15
  run "$PASTA" import "$jpg_file"
  [[ "$status" -eq 0 ]]
  clean_output
  [[ "$out" =~ ^"Created image pasta" ]]
  pasta_file="${PASTA_DIR}/${jpg_name}.png"
  [[ -f "$pasta_file" ]]
  imgdiff "$pasta_file" "$jpg_file"

  png_name="my_png"
  png_file="${TMP_DIR}/${png_name}.png"
  create_white_img "$png_file" 20 20
  run "$PASTA" import "$png_file"
  [[ "$status" -eq 0 ]]
  clean_output
  [[ "$out" =~ ^"Created image pasta" ]]
  pasta_file="${PASTA_DIR}/${png_name}.png"
  [[ -f "$pasta_file" ]]
  diff "$pasta_file" "$png_file"

  no_extension_name="no extension"
  no_extension_file="${TMP_DIR}/${no_extension_name}"
  echo "more data" > "$no_extension_file"
  run "$PASTA" import "$no_extension_file"
  [[ "$status" -eq 0 ]]
  clean_output
  [[ "$out" =~ ^"Created text pasta" ]]
  pasta_file="${PASTA_DIR}/${no_extension_name}.txt"
  [[ -f "$pasta_file" ]]
  diff "$pasta_file" "$no_extension_file"
  CLEANUP=1
}

@test "pasta import fails when given an empty file" {
  empty_file="${TMP_DIR}/empty.txt"
  touch "$empty_file"
  run "$PASTA" import "${empty_file}" empty_pasta
  [[ "$status" -eq 2 ]]
  clean_output
  [[ "$out" =~ "is empty" ]]
  check_no_pastas
  CLEANUP=1
}

@test "pasta import fails when given an unknown file type" {
  byte_file="${TMP_DIR}/bytes.bin"
  get_binary_data >"$byte_file"
  # Sanity check to make sure this file is not detected as an image or text.
  filetype="$(file --mime-type -b "$byte_file")"
  mimetype="$(echo "$filetype" | cut -d'/' -f1)"
  [[ "$mimetype" != "image" ]] && [[ "$mimetype" != "text" ]] || skip "test invalid because the test file has MIME type '${filetype}'"
  run "$PASTA" import  "$byte_file" bytedata
  [[ "$status" -eq 2 ]]
  clean_output
  [[ "$out" =~ "unknown MIME type" ]]
  check_no_pastas
  CLEANUP=1
}

@test "pasta import rejects unknown file types when importing a directory" {
  dir_name="directory"
  dir_path="${TMP_DIR}/$dir_name"
  mkdir "$dir_path"
  binary_name="${dir_name}/bytefile"
  binary_path="${TMP_DIR}/${binary_name}.bin"
  get_binary_data > "$binary_path"
  text_name="${dir_name}/textfile"
  text_path="${TMP_DIR}/${text_name}.txt"
  echo "some data" > "$text_path"
  empty_name="${dir_name}/empty"
  empty_path="${TMP_DIR}/${empty_name}.file"
  touch "$empty_path"
  run "$PASTA" import "$dir_path"
  [[ "$status" -eq 2 ]]
  clean_output
  # Import should succeed for the text and image files.
  [[ "$out" =~ "Created text pasta" ]]
  text_pasta="${PASTA_DIR}/${text_name}.txt"
  [[ -f "$text_pasta" ]]
  diff "$text_pasta" "$text_path"
  [[ "$out" =~ "Could not import '${binary_path}' because of the following error:"$'\n'"Error: unknown MIME type" ]]
  [[ "$out" =~ "Could not import '${empty_path}' because of the following error:"$'\n'"Error: '${empty_path}' is empty" ]]
  rm "$text_pasta"
  # This should succeed if nothing else was copied into that directory.
  rmdir "${PASTA_DIR}/$dir_name"
  check_no_pastas
  CLEANUP=1
}

@test "pasta import fails when given a nonexistent file" {
  run "$PASTA" import "${TMP_DIR}/fake_file.txt" pasta_name
  [[ "$status" -eq 2 ]]
  clean_output
  [[ "$out" =~ "no file".*"exists" ]]
  check_no_pastas
  CLEANUP=1
}

@test "pasta import fails when importing a directory without the recursive flag" {
  dir_name="dir"
  dir_path="${TMP_DIR}/${dir_name}"
  dir_file="${dir_path}/file.txt"
  ensure_parent_dirs "$dir_file"
  echo "data" > "$dir_file"
  run "$PASTA" import "$dir_path"
  [[ "$status" -eq 2 ]]
  clean_output
  [[ "$out" =~ "is a directory. Please use the --recursive flag"$ ]]
  check_no_pastas
  CLEANUP=1
}

@test "pasta import rejects sneaky directory traversal names" {
  setup_sneaky_paths_test write
  text_file="${TMP_DIR}/textfile.txt"
  echo "text data" >"$text_file"
  for sneaky_name in "${sneaky_names[@]}"
  do
    ERROR_MSG="testing 'pasta import' on sneaky path '${sneaky_name}'"
    run "$PASTA" import "$text_file" "$sneaky_name"
    [[ "$status" -eq 2 ]]
    clean_output
    [[ "$out" =~ "is an invalid pasta name" ]]
    [[ ! -f "${PASTA_DIR}/${sneaky_name}.txt" ]]
    check_no_pastas
  done
  CLEANUP=1
}

@test "pasta import works when overwriting" {
  pasta_name="overwritten_pasta"
  text_pasta="${PASTA_DIR}/${pasta_name}.txt"
  text_data="old data"
  echo "$text_data" > "$text_pasta"
  new_text="${TMP_DIR}/overwrite.txt"
  echo "new data" > "$new_text"

  # Test overwriting text with text.
  # Check behavior when no is given.
  run bash -c "echo n | ${PASTA} import '${new_text}' ${pasta_name}"
  [[ "$status" -eq 3 ]]
  # Data should be the same.
  [[ -f "$text_pasta" ]]
  [[ "$text_data" == "$(< "$text_pasta")" ]]
  # Check behavior when yes is given.
  run bash -c "echo y | ${PASTA} import '${new_text}' ${pasta_name}"
  [[ "$status" -eq 0 ]]
  # Data should be updated.
  [[ -f "$text_pasta" ]]
  diff "$text_pasta" "$new_text"

  # Test overwriting text with image.
  image_file="${TMP_DIR}/image.png"
  image_pasta="${PASTA_DIR}/${pasta_name}.png"
  create_white_img "${image_file}" 32 32
  # Check behavior when no is given.
  run bash -c "echo n | ${PASTA} import '${image_file}' ${pasta_name}"
  # User rejected overwriting, so data should still be text.
  [[ "$status" -eq 3 ]]
  # Data should be the same.
  [[ -f "$text_pasta" ]]
  [[ ! -f "$image_pasta" ]]
  diff "$text_pasta" "$new_text"
  # Check behavior when yes is given.
  run bash -c "echo y | ${PASTA} import '${image_file}' ${pasta_name}"
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
  run bash -c "echo n | ${PASTA} import '${image_file_2}' ${pasta_name}"
  # User rejected overwriting, so data should still be the same.
  [[ "$status" -eq 3 ]]
  # Data should be the same.
  [[ -f "$image_pasta" ]]
  diff "$image_pasta" "$image_file"
  # Check behavior when yes is given.
  run bash -c "echo y | ${PASTA} import '${image_file_2}' ${pasta_name}"
  [[ "$status" -eq 0 ]]
  # Data should be updated.
  [[ -f "$image_pasta" ]]
  diff "$image_pasta" "$image_file_2"

  # Test overwriting image with text.
  # Check behavior when no is given.
  run bash -c "echo n | ${PASTA} import '${new_text}' ${pasta_name}"
  # User rejected overwriting, so data should still be image.
  [[ "$status" -eq 3 ]]
  # data Should be the same.
  [[ -f "$image_pasta" ]]
  [[ ! -f "$text_pasta" ]]
  diff "$image_pasta" "$image_file_2"
  # Check behavior when yes is given.
  run bash -c "echo y | ${PASTA} import '${new_text}' ${pasta_name}"
  [[ "$status" -eq 0 ]]
  # Data should be updated.
  [[ -f "$text_pasta" ]]
  [[ ! -f "$image_pasta" ]]
  diff "$text_pasta" "$new_text"
  CLEANUP=1
}

@test "pasta import with the force flag doesn't ask for overwrite" {
  text_file="${TMP_DIR}/textfile.txt"
  echo "new data" > "$text_file"
  pasta_name="pasta_name"
  pasta_file="${PASTA_DIR}/${pasta_name}.txt"
  for force_flag in '-f' '--force'
  do
    echo "old data" > "$pasta_file"
    # Echo no to pasta which should be ignored.
    run bash -c "echo n | ${PASTA} import ${force_flag} '${text_file}' $pasta_name"
    [[ "$status" -eq 0 ]]
    [[ -f "$pasta_file" ]]
    diff "$pasta_file" "$text_file"
    rm "$pasta_file"
  done
  CLEANUP=1
}

@test "pasta export copies the text pasta to the given location" {
  CLEANUP=1
  skip "pasta export has not been implemented yet"
  pasta_name="text_pasta"
  pasta_file="${PASTA_DIR}/${pasta_name}.txt"
  echo "something" > "$pasta_file"
  text_file="${TMP_DIR}/textfile.out"
  run "$PASTA" export "$pasta_name" "$text_file"
  [[ "$status" -eq 0 ]]
  [[ -f "$text_file" ]]
  diff "$text_file" "$pasta_file"
  CLEANUP=1
}

@test "pasta export copies the image pasta to the given location" {
  CLEANUP=1
  skip "pasta export has not been implemented yet"
  pasta_name="img_pasta"
  pasta_file="${PASTA_DIR}/${pasta_name}.png"
  create_white_img "$pasta_file"
  image_file="${TMP_DIR}/image.png"
  run "$PASTA" export "$pasta_name" "$image_file"
  [[ "$status" -eq 0 ]]
  [[ -f "$image_file" ]]
  diff "$image_file" "$pasta_file"
  CLEANUP=1
}

@test "pasta export converts the image pasta to jpeg" {
  CLEANUP=1
  skip "pasta export has not been implemented yet"
  pasta_name="img_pasta"
  pasta_file="${PASTA_DIR}/${pasta_name}.png"
  create_white_img "$pasta_file"
  image_file="${TMP_DIR}/image.jpg"
  run "$PASTA" export "$pasta_name" "$image_file"
  [[ "$status" -eq 0 ]]
  [[ -f "$image_file" ]]
  [[ "$(file --mime-type -b "$image_file")" == "image/jpeg" ]]
  imgdiff "$image_file" "$pasta_file"
  CLEANUP=1
}

@test "pasta export accepts names with slashes and spaces" {
  CLEANUP=1
  skip "pasta export has not been implemented yet"
  pasta_name="export/slashes/and/spaces/in name"
  pasta_file="${PASTA_DIR}/${pasta_name}.txt"
  ensure_parent_dirs "$pasta_file"
  echo "some data" > "$pasta_file"
  text_file="${TMP_DIR}/textfile.out"
  run "$PASTA" export "$pasta_name" "$(realpath --relative-to=. "$text_file")"
  [[ "$status" -eq 0 ]]
  [[ -f "$text_file" ]]
  diff "$text_file" "$pasta_file"
  CLEANUP=1
}

@test "pasta export fails when given too few arguments" {
  CLEANUP=1
  skip "pasta export has not been implemented yet"
  pasta_name="a_pasta"
  pasta_file="${PASTA_DIR}/${pasta_name}.txt"
  echo "text data" >"$pasta_file"
  for force_flag in "" "-f" "--force"
  do
    for first_arg in "" "$pasta_file"
    do
      ERROR_MSG="testing 'pasta export ${force_flag} ${first_arg}'"
      # Check when no pasta name is given.
      run "$PASTA" export $force_flag $first_arg
      [[ "$status" -eq 2 ]]
      clean_output
      [[ "$out" =~ ^"Usage: ".*" export " ]]
    done
  done
  CLEANUP=1
}

@test "pasta export fails when given a nonexistent pasta" {
  CLEANUP=1
  skip "pasta export has not been implemented yet"
  out_file="${TMP_DIR}/data.out"
  run "$PASTA" export nonexistent "$out_file"
  [[ "$status" -eq 2 ]]
  clean_output
  [[ "$out" =~ "does not exist" ]]
  [[ ! -f "$out_file" ]]
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
  pasta_name="show slashes/and spaces/in/name"
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

@test "pasta alias creates a link to the text pasta at the given location" {
  target_name="text_pasta"
  target_file="${PASTA_DIR}/${target_name}.txt"
  echo "some data" > "$target_file"
  link_name="hard_link"
  link_file="${PASTA_DIR}/${link_name}.txt"
  for alias_cmd in "alias" "ln"
  do
    ERROR_MSG="testing 'pasta ${alias_cmd}'"
    run "$PASTA" "$alias_cmd" "$target_name" "$link_name"
    [[ "$status" -eq 0 ]]
    clean_output
    [[ "$out" =~ ^"Text pasta".*"aliased to" ]]
    [[ -f "$link_file" ]]
    [[ "$target_file" -ef "$link_file" ]]
    rm "$link_file"
  done
  CLEANUP=1
}

@test "pasta alias creates a link to the image pasta at the given location" {
  target_name="image_pasta"
  target_file="${PASTA_DIR}/${target_name}.png"
  create_white_img "$target_file" 15 15
  link_name="hard_link"
  link_file="${PASTA_DIR}/${link_name}.png"
  for alias_cmd in "alias" "ln"
  do
    ERROR_MSG="testing 'pasta ${alias_cmd}'"
    run "$PASTA" "$alias_cmd" "$target_name" "$link_name"
    [[ "$status" -eq 0 ]]
    clean_output
    [[ "$out" =~ ^"Image pasta".*"aliased to" ]]
    [[ -f "$link_file" ]]
    [[ "$target_file" -ef "$link_file" ]]
    rm "$link_file"
  done
  CLEANUP=1
}

@test "pasta alias creates a link to the directory at the given location" {
  target_name="directory"
  target_dir="${PASTA_DIR}/${target_name}"
  mkdir "$target_dir"
  inner_name="text_pasta"
  inner_file="${target_dir}/${inner_name}.txt"
  echo data > "$inner_file"
  link_name="soft_link"
  link_dir="${PASTA_DIR}/${link_name}"
  linked_inner_file="${link_dir}/${inner_name}.txt"
  for alias_cmd in "alias" "ln"
  do
    for symbolic_flag in "-s" "--symbolic"
    do
      ERROR_MSG="testing 'pasta ${alias_cmd} ${symbolic_flag}'"
      run "$PASTA" "$alias_cmd" "$symbolic_flag" "$target_name" "$link_name"
      [[ "$status" -eq 0 ]]
      clean_output
      [[ "$out" =~ ^"Directory".*"aliased to" ]]
      [[ -h "$link_dir" ]]
      [[ "$target_dir" -ef "$(realpath "$link_dir")" ]]
      [[ "$inner_file" -ef "$linked_inner_file" ]]
      unlink "$link_dir"
    done
  done
  CLEANUP=1
}

@test "pasta alias accepts names with slashes and spaces" {
  target_name="target/text pasta"
  target_file="${PASTA_DIR}/${target_name}.txt"
  ensure_parent_dirs "$target_file"
  echo "text data" > "$target_file"
  link_name="link/linked pasta"
  for alias_cmd in "alias" "ln"
  do
    ERROR_MSG="testing 'pasta ${alias_cmd}'"
    run "$PASTA" ln "$target_name" $link_name
    [[ "$status" -eq 0 ]]
    clean_output
    [[ "$out" =~ ^"Text pasta".*"aliased to" ]]
    link_file="${PASTA_DIR}/${link_name}.txt"
    [[ -f "$link_file" ]]
    [[ "$target_file" -ef "$link_file" ]]
    rm "$link_file"
  done
  CLEANUP=1
}

@test "pasta alias creates a link in the given directory" {
  target_name="text_pasta"
  target_file="${PASTA_DIR}/${target_name}.txt"
  echo "text data" > "$target_file"
  dir_name="directory"
  dummy_path="${PASTA_DIR}/${dir_name}/file.txt"
  ensure_parent_dirs "$dummy_path"
  echo "dummy data" > "$dummy_path"
  for alias_cmd in "alias" "ln"
  do
    ERROR_MSG="testing 'pasta ${alias_cmd}'"
    run "$PASTA" ln "$target_name" "$dir_name"
    [[ "$status" -eq 0 ]]
    clean_output
    [[ "$out" =~ ^"Text pasta".*"aliased to" ]]
    link_file="${PASTA_DIR}/${dir_name}/${target_name}.txt"
    [[ -f "$link_file" ]]
    [[ "$target_file" -ef "$link_file" ]]
    rm "$link_file"
  done
  CLEANUP=1
}

@test "Pasta alias does not overwrite the link when the target is a directory" {
  target_name="my_dir"
  target_dir="${PASTA_DIR}/${target_name}"
  mkdir "$target_dir"
  echo "some data" > "${target_dir}/something.txt"
  link_name="existing_name"
  text_file="${PASTA_DIR}/${link_name}.txt"
  text_data="more data"
  echo "$text_data" > "$text_file"
  for symbolic_flag in "-s" "--symbolic"
  do
    ERROR_MSG="testing 'pasta alias ${symbolic_flag}'"
    # Echo no to pasta which should be ignored.
    run bash -c "echo n | ${PASTA} alias ${symbolic_flag} '${target_name}' ${link_name}"
    [[ "$status" -eq 0 ]]
    clean_output
    [[ "$out" =~ ^"Directory".*"aliased to" ]]
    # Check that the link exists at the given name
    link_dir="${PASTA_DIR}/$link_name"
    [[ -h "$link_dir" ]]
    [[ "$target_dir" -ef "$(realpath "$link_dir")" ]]
    # Check that the existing text file was not changed.
    [[ -f "$text_file" ]]
    [[ "$text_data" == "$(< "$text_file")" ]]
    unlink "$link_dir"
  done
  CLEANUP=1
}

@test "pasta alias fails when linking a directory without the symbolic flag" {
  dir_name="dir"
  dir_file="${PASTA_DIR}/${dir_name}/file.txt"
  ensure_parent_dirs "$dir_file"
  echo "data" > "$dir_file"
  link_name="a_link"
  run "$PASTA" alias "$dir_name" "$link_name"
  [[ "$status" -eq 2 ]]
  clean_output
  [[ "$out" =~ "is a directory. Please use the --symbolic flag"$ ]]
  [[ ! -e "${PASTA_DIR}/${link_name}" ]]
  CLEANUP=1
}

@test "pasta alias rejects sneaky directory traversal names" {
  setup_sneaky_paths_test write
  pasta_name="text_pasta"
  pasta_file="${PASTA_DIR}/${pasta_name}.txt"
  for sneaky_name in "${sneaky_names[@]}"
  do
    echo "text data" > "$pasta_file"
    ERROR_MSG="testing 'pasta alias' when link is sneaky path '${sneaky_name}'"
    run "$PASTA" alias "$pasta_name" "$sneaky_name"
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
    ERROR_MSG="testing 'pasta alias' when target is sneaky path '${sneaky_name}'"
    run "$PASTA" alias -s "$sneaky_name" "$pasta_name"
    [[ "$status" -eq 2 ]]
    clean_output
    [[ "$out" =~ "is an invalid pasta name" ]]
    [[ ! -f "$pasta_file" ]]
  done
  CLEANUP=1
}

@test "pasta alias fails when given too few arguments" {
  target_name="target_name"
  echo data > "${PASTA_DIR}/${target_name}.txt"
  for flags in "" "-f" "--force" "-s" "--symbolic" "-v" "--verbose" "-f -s" "--symbolic -v -f --"
  do
    for pos_arg in "" "$target_name"
    do
      ERROR_MSG="testing 'pasta alias ${flags} ${pos_arg}'"
      run "$PASTA" alias $flags $pos_arg
      [[ "$status" -eq 2 ]]
      clean_output
      [[ "$out" =~ ^"Usage: ".*" alias|ln " ]]
    done
  done
  CLEANUP=1
}

@test "pasta alias fails when a nonexistent target pasta is specified" {
  run "$PASTA" alias nonexistent link_name
  [[ "$status" -eq 2 ]]
  clean_output
  [[ "$out" =~ "does not exist" ]]
  CLEANUP=1
}

@test "pasta alias fails when the target is also the link name" {
  pasta_name="same_pasta"
  pasta_file="${PASTA_DIR}/${pasta_name}.txt"
  pasta_data="data"
  echo "$pasta_data" > "${PASTA_DIR}/${pasta_name}.txt"
  run bash -c "echo n | ${PASTA} alias '${pasta_name}' './${pasta_name}'"
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
  run bash -c "echo n | ${PASTA} alias --symbolic '${dir_name}' $dir_name"
  [[ "$status" -eq 2 ]]
  clean_output
  [[ "$out" =~ ^"Error: cannot alias directory".*"to itself"$ ]]
  [[ -f "$inner_file" ]]
  [[ "$inner_data" == "$(< "$inner_file")" ]]
  CLEANUP=1
}

@test "pasta alias works when overwriting" {
  target_text="target_text"
  target_text_file="${PASTA_DIR}/${target_text}.txt"
  echo data > "$target_text_file"
  target_img="target_img"
  target_img_file="${PASTA_DIR}/${target_img}.png"
  target_img2="target_img_2"
  target_img2_file="${PASTA_DIR}/${target_img2}.png"
  create_white_img "$target_img_file" 32 32
  create_white_img "$target_img2_file" 36 36

  overwritten_name="overwritten_pasta"
  overwritten_text="${PASTA_DIR}/${overwritten_name}.txt"
  overwritten_img="${PASTA_DIR}/${overwritten_name}.png"
  overwritten_data="different data"
  echo "$overwritten_data" > "$overwritten_text"

  # Test overwriting text with text.
  # Check behavior when no is given.
  run bash -c "echo n | ${PASTA} alias '${target_text}' ${overwritten_name}"
  [[ "$status" -eq 3 ]]
  # Data should be the same.
  [[ -f "$overwritten_text" ]]
  [[ "$overwritten_data" == "$(< "$overwritten_text")" ]]
  # Check behavior when yes is given.
  run bash -c "echo y | ${PASTA} alias '${target_text}' ${overwritten_name}"
  [[ "$status" -eq 0 ]]
  # Data should be updated.
  [[ -f "$overwritten_text" ]]
  [[ "$overwritten_text" -ef "$target_text_file" ]]

  # Test overwriting text with image.
  # Check behavior when no is given.
  run bash -c "echo n | ${PASTA} alias '${target_img}' ${overwritten_name}"
  # User rejected overwriting, so data should still be text.
  [[ "$status" -eq 3 ]]
  # Data should be the same.
  [[ -f "$overwritten_text" ]]
  [[ ! -f "$overwritten_img" ]]
  [[ "$overwritten_text" -ef "$target_text_file" ]]
  # Check behavior when yes is given.
  run bash -c "echo y | ${PASTA} alias '${target_img}' ${overwritten_name}"
  [[ "$status" -eq 0 ]]
  # Data should be updated.
  [[ -f "$overwritten_img" ]]
  [[ ! -f "$overwritten_text" ]]
  [[ "$overwritten_img" -ef "$target_img_file" ]]

  # Test overwriting image with image.
  # Check behavior when no is given.
  run bash -c "echo n | ${PASTA} alias '${target_img2}' ${overwritten_name}"
  # User rejected overwriting, so data should still be the same.
  [[ "$status" -eq 3 ]]
  # Data should be the same.
  [[ -f "$overwritten_img" ]]
  [[ "$overwritten_img" -ef "$target_img_file" ]]
  # Check behavior when yes is given.
  run bash -c "echo y | ${PASTA} alias '${target_img2}' ${overwritten_name}"
  [[ "$status" -eq 0 ]]
  # Data should be updated.
  [[ -f "$overwritten_img" ]]
  [[ "$overwritten_img" -ef "$target_img2_file" ]]

  # Test overwriting image with text.
  # Check behavior when no is given.
  run bash -c "echo n | ${PASTA} alias '${target_text}' ${overwritten_name}"
  # User rejected overwriting, so data should still be image.
  [[ "$status" -eq 3 ]]
  # data Should be the same.
  [[ -f "$overwritten_img" ]]
  [[ ! -f "$overwritten_text" ]]
  [[ "$overwritten_img" -ef "$target_img2_file" ]]
  # Check behavior when yes is given.
  run bash -c "echo y | ${PASTA} alias '${target_text}' ${overwritten_name}"
  [[ "$status" -eq 0 ]]
  # Data should be updated.
  [[ -f "$overwritten_text" ]]
  [[ ! -f "$overwritten_img" ]]
  [[ "$overwritten_text" -ef "$target_text_file" ]]
  CLEANUP=1
}

@test "pasta alias with force flag doesn't ask for overwrite" {
  target_name="textfile"
  target_file="${PASTA_DIR}/${target_name}.txt"
  echo "new data" > "$target_file"
  link_name="link_name"
  link_file="${PASTA_DIR}/${link_name}.txt"
  for force_flag in '-f' '--force'
  do
    ERROR_MSG="testing 'pasta alias ${force_flag}'"
    echo "old data" > "$link_file"
    # Echo no to pasta which should be ignored.
    run bash -c "echo n | ${PASTA} alias ${force_flag} '${target_name}' $link_name"
    [[ "$status" -eq 0 ]]
    [[ -f "$link_file" ]]
    [[ "$link_file" -ef "$target_file" ]]
    rm "$link_file"
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
  [[ "$out" =~ ^"Text pasta".*"copied to" ]]
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
  [[ "$out" =~ ^"Text pasta".*"copied to" ]]
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
  [[ "$out" =~ ^"Text pasta".*"copied to" ]]
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
  text_data="more data"
  echo "$text_data" > "$text_file"
  for recurse_flag in "-r" "--recursive"
  do
    ERROR_MSG="testing 'pasta cp ${recurse_flag}'"
    # Echo no to pasta which should be ignored.
    run bash -c "echo n | ${PASTA} cp ${recurse_flag} '${source_name}' ${dest_name}"
    [[ "$status" -eq 0 ]]
    clean_output
    [[ "$out" =~ ^"Directory".*"copied to" ]]
    # Check that the new data was copied over.
    dest_file="${PASTA_DIR}/${dest_name}/${inner_name}.txt"
    [[ -f "$dest_file" ]]
    diff "$dest_file" "$inner_file"
    # Check that the existing text file was not changed.
    [[ -f "$text_file" ]]
    [[ "$text_data" == "$(< "$text_file")" ]]
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
    run "$PASTA" cp -r "$sneaky_name" "$pasta_name"
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
      [[ "$out" =~ ^"Usage: ".*" cp " ]]
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

@test "pasta cp fails when the source is also the destination" {
  pasta_name="same_pasta"
  pasta_file="${PASTA_DIR}/${pasta_name}.txt"
  pasta_data="data"
  echo "$pasta_data" > "${PASTA_DIR}/${pasta_name}.txt"
  run bash -c "echo n | ${PASTA} cp '${pasta_name}' './${pasta_name}'"
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
  run bash -c "echo n | ${PASTA} cp --recursive '${dir_name}' $dir_name"
  [[ "$status" -eq 2 ]]
  clean_output
  [[ "$out" =~ ^"Error: cannot cp directory".*"to itself"$ ]]
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
  overwritten_data="different data"
  echo "$overwritten_data" > "$overwritten_text"

  # Test overwriting text with text.
  # Check behavior when no is given.
  run bash -c "echo n | ${PASTA} cp '${source_text}' ${overwritten_name}"
  [[ "$status" -eq 3 ]]
  # Data should be the same.
  [[ -f "$overwritten_text" ]]
  [[ "$overwritten_data" == "$(< "$overwritten_text")" ]]
  # Check behavior when yes is given.
  run bash -c "echo y | ${PASTA} cp '${source_text}' ${overwritten_name}"
  [[ "$status" -eq 0 ]]
  # Data should be updated.
  [[ -f "$overwritten_text" ]]
  diff "$overwritten_text" "$source_text_file"

  # Test overwriting text with image.
  # Check behavior when no is given.
  run bash -c "echo n | ${PASTA} cp '${source_img}' ${overwritten_name}"
  # User rejected overwriting, so data should still be text.
  [[ "$status" -eq 3 ]]
  # Data should be the same.
  [[ -f "$overwritten_text" ]]
  [[ ! -f "$overwritten_img" ]]
  diff "$overwritten_text" "$source_text_file"
  # Check behavior when yes is given.
  run bash -c "echo y | ${PASTA} cp '${source_img}' ${overwritten_name}"
  [[ "$status" -eq 0 ]]
  # Data should be updated.
  [[ -f "$overwritten_img" ]]
  [[ ! -f "$overwritten_text" ]]
  diff "$overwritten_img" "$source_img_file"

  # Test overwriting image with image.
  # Check behavior when no is given.
  run bash -c "echo n | ${PASTA} cp '${source_img2}' ${overwritten_name}"
  # User rejected overwriting, so data should still be the same.
  [[ "$status" -eq 3 ]]
  # Data should be the same.
  [[ -f "$overwritten_img" ]]
  diff "$overwritten_img" "$source_img_file"
  # Check behavior when yes is given.
  run bash -c "echo y | ${PASTA} cp '${source_img2}' ${overwritten_name}"
  [[ "$status" -eq 0 ]]
  # Data should be updated.
  [[ -f "$overwritten_img" ]]
  diff "$overwritten_img" "$source_img2_file"

  # Test overwriting image with text.
  # Check behavior when no is given.
  run bash -c "echo n | ${PASTA} cp '${source_text}' ${overwritten_name}"
  # User rejected overwriting, so data should still be image.
  [[ "$status" -eq 3 ]]
  # data Should be the same.
  [[ -f "$overwritten_img" ]]
  [[ ! -f "$overwritten_text" ]]
  diff "$overwritten_img" "$source_img2_file"
  # Check behavior when yes is given.
  run bash -c "echo y | ${PASTA} cp '${source_text}' ${overwritten_name}"
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
    run bash -c "echo n | ${PASTA} cp ${force_flag} '${source_name}' $dest_name"
    [[ "$status" -eq 0 ]]
    [[ -f "$dest_file" ]]
    diff "$dest_file" "$source_file"
    rm "$dest_file"
  done
  CLEANUP=1
}

@test "pasta rename renames a text pasta to the given location" {
  source_name="text_pasta"
  source_file="${PASTA_DIR}/${source_name}.txt"
  source_data="text data"
  dest_name="destination"
  for rename_cmd in "rename" "mv"
  do
    ERROR_MSG="testing 'pasta ${rename_cmd}'"
    echo "$source_data" > "$source_file"
    run "$PASTA" "$rename_cmd" "$source_name" "$dest_name"
    [[ "$status" -eq 0 ]]
    clean_output
    [[ "$out" =~ ^"Text pasta".*"moved to" ]]
    [[ ! -f "$source_file" ]]
    dest_file="${PASTA_DIR}/${dest_name}.txt"
    [[ -f "$dest_file" ]]
    [[ "$source_data" == "$(< "$dest_file")" ]]
    rm "$dest_file"
  done
  CLEANUP=1
}

@test "pasta rename renames an image pasta to the given location" {
  source_name="image_pasta"
  source_file="${PASTA_DIR}/${source_name}.png"
  backup_file="${TMP_DIR}/backup.png"
  dest_name="destination"
  for rename_cmd in "rename" "mv"
  do
    ERROR_MSG="testing 'pasta ${rename_cmd}'"
    create_white_img "$source_file"
    cp "$source_file" "$backup_file"
    run "$PASTA" "$rename_cmd" "$source_name" "$dest_name"
    [[ "$status" -eq 0 ]]
    clean_output
    [[ "$out" =~ ^"Image pasta".*"moved to" ]]
    [[ ! -f "$source_file" ]]
    dest_file="${PASTA_DIR}/${dest_name}.png"
    [[ -f "$dest_file" ]]
    diff "$dest_file" "$backup_file"
    rm "$dest_file"
  done
  CLEANUP=1
}

@test "pasta rename accepts names with slashes and spaces" {
  source_name="source/text pasta"
  source_file="${PASTA_DIR}/${source_name}.txt"
  source_data="text data"
  dest_name="destination/text pasta"
  for rename_cmd in "rename" "mv"
  do
    ERROR_MSG="testing 'pasta ${rename_cmd}'"
    ensure_parent_dirs "$source_file"
    echo "$source_data" > "$source_file"
    run "$PASTA" "$rename_cmd" "$source_name" $dest_name
    [[ "$status" -eq 0 ]]
    clean_output
    [[ "$out" =~ ^"Text pasta".*"moved to" ]]
    [[ ! -f "$source_file" ]]
    [[ ! -d "$(dirname "$source_file")" ]]
    dest_file="${PASTA_DIR}/${dest_name}.txt"
    [[ -f "$dest_file" ]]
    [[ "$source_data" == "$(< "$dest_file")" ]]
    rm -r "$(dirname "$dest_file")"
  done
  CLEANUP=1
}

@test "pasta rename renames to the destination directory" {
  source_name="text_pasta"
  source_file="${PASTA_DIR}/${source_name}.txt"
  source_data="text data"
  dest_name="directory"
  dummy_path="${PASTA_DIR}/${dest_name}/file.txt"
  ensure_parent_dirs "$dummy_path"
  echo "dummy data" > "$dummy_path"
  for rename_cmd in "rename" "mv"
  do
    ERROR_MSG="testing 'pasta ${rename_cmd}'"
    echo "$source_data" > "$source_file"
    run "$PASTA" "$rename_cmd" "$source_name" "$dest_name"
    [[ "$status" -eq 0 ]]
    clean_output
    [[ "$out" =~ ^"Text pasta".*"moved to" ]]
    [[ ! -f "$source_file" ]]
    dest_file="${PASTA_DIR}/${dest_name}/${source_name}.txt"
    [[ -f "$dest_file" ]]
    [[ "$source_data" == "$(< "$dest_file")" ]]
    rm "$dest_file"
  done
  CLEANUP=1
}

@test "pasta rename does not overwrite data when the source is a directory" {
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
  run bash -c "echo n | ${PASTA} rename '${source_name}' ${dest_name}"
  [[ "$status" -eq 0 ]]
  clean_output
  [[ "$out" =~ ^"Directory".*"moved to" ]]
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

@test "pasta rename rejects sneaky directory traversal names" {
  setup_sneaky_paths_test write
  pasta_name="text_pasta"
  pasta_file="${PASTA_DIR}/${pasta_name}.txt"
  for sneaky_name in "${sneaky_names[@]}"
  do
    echo "text data" > "$pasta_file"
    ERROR_MSG="testing 'pasta rename' when destination is sneaky path '${sneaky_name}'"
    run "$PASTA" rename "$pasta_name" "$sneaky_name"
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
    ERROR_MSG="testing 'pasta rename' when source is sneaky path '${sneaky_name}'"
    run "$PASTA" rename "$sneaky_name" "$pasta_name"
    [[ "$status" -eq 2 ]]
    clean_output
    [[ "$out" =~ "is an invalid pasta name" ]]
    [[ ! -f "$pasta_file" ]]
  done
  CLEANUP=1
}

@test "pasta rename fails when given too few arguments" {
  source_name="source_name"
  source_file="${PASTA_DIR}/${source_name}.txt"
  echo data > "$source_file"
  for flags in "" "-f" "--force" "-v" "--verbose" "-f -v" "--verbose --force --"
  do
    for pos_arg in "" "$source_name"
    do
      ERROR_MSG="testing 'pasta rename ${flags} ${pos_arg}'"
      run "$PASTA" rename $flags $pos_arg
      [[ "$status" -eq 2 ]]
      clean_output
      [[ "$out" =~ ^"Usage: ".*" rename|mv " ]]
      [[ -f "$source_file" ]]
    done
  done
  CLEANUP=1
}

@test "pasta rename fails when a nonexistent source pasta is specified" {
  run "$PASTA" rename nonexistent destination
  [[ "$status" -eq 2 ]]
  clean_output
  [[ "$out" =~ "does not exist" ]]
  CLEANUP=1
}

@test "pasta rename fails when the source is also the destination" {
  pasta_name="same_pasta"
  pasta_file="${PASTA_DIR}/${pasta_name}.txt"
  pasta_data="data"
  echo "$pasta_data" > "$pasta_file"
  run bash -c "echo n | ${PASTA} rename '${pasta_name}' './${pasta_name}'"
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
  run bash -c "echo n | ${PASTA} rename '${dir_name}' $dir_name"
  [[ "$status" -eq 2 ]]
  clean_output
  [[ "$out" =~ ^"Error: cannot rename directory".*"to itself"$ ]]
  [[ -f "$inner_file" ]]
  [[ "$inner_data" == "$(< "$inner_file")" ]]
  CLEANUP=1
}

@test "pasta rename works when overwriting" {
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
  run bash -c "echo n | ${PASTA} rename '${source_text}' ${overwritten_name}"
  [[ "$status" -eq 3 ]]
  # Data should be the same.
  [[ -f "$source_text_file" ]]
  [[ -f "$overwritten_text" ]]
  [[ "$overwritten_text_data" == "$(< "$overwritten_text")" ]]
  # Check behavior when yes is given.
  run bash -c "echo y | ${PASTA} rename '${source_text}' ${overwritten_name}"
  [[ "$status" -eq 0 ]]
  # Data should be updated.
  [[ ! -f "$source_text_file" ]]
  [[ -f "$overwritten_text" ]]
  [[ "$source_text_data" == "$(< "$overwritten_text")" ]]

  # Test overwriting text with image.
  # Check behavior when no is given.
  run bash -c "echo n | ${PASTA} rename '${source_img}' ${overwritten_name}"
  # User rejected overwriting, so data should still be text.
  [[ "$status" -eq 3 ]]
  # Data should be the same.
  [[ -f "$source_img_file" ]]
  [[ -f "$overwritten_text" ]]
  [[ ! -f "$overwritten_img" ]]
  [[ "$source_text_data" == "$(< "$overwritten_text")" ]]
  # Check behavior when yes is given.
  run bash -c "echo y | ${PASTA} rename '${source_img}' ${overwritten_name}"
  [[ "$status" -eq 0 ]]
  # Data should be updated.
  [[ ! -f "$source_img_file" ]]
  [[ -f "$overwritten_img" ]]
  [[ ! -f "$overwritten_text" ]]
  diff "$overwritten_img" "$source_img_backup"

  # Test overwriting image with image.
  # Check behavior when no is given.
  run bash -c "echo n | ${PASTA} rename '${source_img2}' ${overwritten_name}"
  # User rejected overwriting, so data should still be the same.
  [[ "$status" -eq 3 ]]
  # Data should be the same.
  [[ -f "$source_img2_file" ]]
  [[ -f "$overwritten_img" ]]
  diff "$overwritten_img" "$source_img_backup"
  # Check behavior when yes is given.
  run bash -c "echo y | ${PASTA} rename '${source_img2}' ${overwritten_name}"
  [[ "$status" -eq 0 ]]
  # Data should be updated.
  [[ ! -f "$source_img2_file" ]]
  [[ -f "$overwritten_img" ]]
  diff "$overwritten_img" "$source_img2_backup"

  # Test overwriting image with text.
  # Check behavior when no is given.
  run bash -c "echo n | ${PASTA} rename '${source_text2}' ${overwritten_name}"
  # User rejected overwriting, so data should still be image.
  [[ "$status" -eq 3 ]]
  # data Should be the same.
  [[ -f "$source_text2_file" ]]
  [[ -f "$overwritten_img" ]]
  [[ ! -f "$overwritten_text" ]]
  diff "$overwritten_img" "$source_img2_backup"
  # Check behavior when yes is given.
  run bash -c "echo y | ${PASTA} rename '${source_text2}' ${overwritten_name}"
  [[ "$status" -eq 0 ]]
  # Data should be updated.
  [[ ! -f "$source_text2_file" ]]
  [[ -f "$overwritten_text" ]]
  [[ ! -f "$overwritten_img" ]]
  [[ "$source_text2_data" == "$(< "$overwritten_text")" ]]
  CLEANUP=1
}

@test "pasta rename with the force flag doesn't ask for overwrite" {
  source_name="textfile"
  source_file="${PASTA_DIR}/${source_name}.txt"
  source_data="new data"
  dest_name="dest_name"
  dest_file="${PASTA_DIR}/${dest_name}.txt"
  for force_flag in '-f' '--force'
  do
    ERROR_MSG="testing 'pasta rename ${force_flag}'"
    echo "$source_data" > "$source_file"
    echo "old data" > "$dest_file"
    # Echo no to pasta which should be ignored.
    run bash -c "echo n | ${PASTA} rename ${force_flag} '${source_name}' $dest_name"
    [[ "$status" -eq 0 ]]
    [[ -f "$dest_file" ]]
    [[ ! -f "$source_file" ]]
    [[ "$source_data" == "$(< "$dest_file")" ]]
    rm "$dest_file"
  done
  CLEANUP=1
}

@test "pasta delete removes the text pasta" {
  pasta_name="textfile"
  pasta_file="${PASTA_DIR}/${pasta_name}.txt"
  for delete_cmd in "delete" "remove" "rm"
  do
    ERROR_MSG="testing 'pasta ${delete_cmd}'"
    echo data > "$pasta_file"
    run "$PASTA" "$delete_cmd" "$pasta_name"
    [[ "$status" -eq 0 ]]
    clean_output
    [[ "$out" =~ ^"Deleted text pasta" ]]
    check_no_pastas
  done
  CLEANUP=1
}

@test "pasta delete removes the image pasta" {
  pasta_name="imagefile"
  pasta_file="${PASTA_DIR}/${pasta_name}.png"
  for delete_cmd in "delete" "remove" "rm"
  do
    ERROR_MSG="testing 'pasta ${delete_cmd}'"
    create_white_img "$pasta_file"
    run "$PASTA" "$delete_cmd" "$pasta_name"
    [[ "$status" -eq 0 ]]
    clean_output
    [[ "$out" =~ ^"Deleted image pasta" ]]
    check_no_pastas
  done
  CLEANUP=1
}

@test "pasta delete removes the directory" {
  pasta_name="dir"
  pasta_dir="${PASTA_DIR}/${pasta_name}"
  for delete_cmd in "delete" "remove" "rm"
  do
    for recurse_flag in "-r" "--recursive"
    do
      ERROR_MSG="testing 'pasta ${delete_cmd} ${recurse_flag}'"
      mkdir "$pasta_dir"
      echo data > "${pasta_dir}/pasta.txt"
      run "$PASTA" "$delete_cmd" "$recurse_flag" "$pasta_name"
      [[ "$status" -eq 0 ]]
      clean_output
      [[ "$out" =~ ^"Deleted directory" ]]
      check_no_pastas
    done
  done
  CLEANUP=1
}

@test "pasta delete accepts names with slashes and spaces" {
  dir_name="dir"
  first_pasta="${dir_name}/first pasta"
  first_file="${PASTA_DIR}/${first_pasta}.txt"
  second_pasta="${dir_name}/second pasta"
  second_file="${PASTA_DIR}/${second_pasta}.txt"
  for delete_cmd in "delete" "remove" "rm"
  do
    ERROR_MSG="testing 'pasta ${delete_cmd} ${first_pasta}'"
    ensure_parent_dirs "$first_file"
    echo data1 > "$first_file"
    echo data2 > "$second_file"
    run "$PASTA" "$delete_cmd" "$first_pasta"
    [[ "$status" -eq 0 ]]
    clean_output
    [[ "$out" =~ ^"Deleted text pasta" ]]
    [[ ! -f "$first_file" ]]
    # Check that the second file in the same directory is unaffected
    [[ -f "$second_file" ]]
    ERROR_MSG="testing 'pasta ${delete_cmd} ${second_pasta}'"
    run "$PASTA" "$delete_cmd" "$second_pasta"
    [[ "$status" -eq 0 ]]
    clean_output
    [[ "$out" =~ ^"Deleted text pasta" ]]
    check_no_pastas
  done
  CLEANUP=1
}

@test "pasta delete accepts multiple pasta names as arguments" {
  text_pasta="text"
  text_file="${PASTA_DIR}/${text_pasta}.txt"
  image_pasta="image"
  image_file="${PASTA_DIR}/${image_pasta}.png"
  dir_name="dir"
  pasta_dir="${PASTA_DIR}/${dir_name}"
  for delete_cmd in "delete" "remove" "rm"
  do
    for recurse_flag in "-r" "--recursive"
    do
      ERROR_MSG="testing 'pasta ${delete_cmd} ${recurse_flag}'"
      echo "text data" > "$text_file"
      create_white_img "$image_file"
      mkdir "$pasta_dir"
      echo data > "${pasta_dir}/data.txt"
      run "$PASTA" "$delete_cmd" "$recurse_flag" "$text_pasta" "$image_pasta" "$dir_name"
      [[ "$status" -eq 0 ]]
      clean_output
      [[ "$out" =~ ^"Deleted text pasta".*"Deleted image pasta".*"Deleted directory" ]]
      check_no_pastas
    done
  done
  CLEANUP=1
}

@test "pasta delete rejects sneaky directory traversal names" {
  setup_sneaky_paths_test read
  for sneaky_name in "${sneaky_names[@]}"
  do
    ERROR_MSG="testing 'pasta delete' on sneaky path '${sneaky_name}'"
    run "$PASTA" delete -r "$sneaky_name"
    [[ "$status" -eq 2 ]]
    clean_output
    [[ "$out" =~ "is an invalid pasta name" ]]
    # Check that either the directory or text pasta exists
    [[ -d "${PASTA_DIR}/${sneaky_name}" ]] || [[ -f "${PASTA_DIR}/${sneaky_name}.txt" ]]
  done
  CLEANUP=1
}

@test "pasta delete fails with no arguments" {
  for recurse_flag in "" "-r" "--recursive"
  do
    ERROR_MSG="testing 'pasta delete ${recurse_flag}'"
    run "$PASTA" delete $recurse_flag
    [[ "$status" -eq 2 ]]
    clean_output
    [[ "$out" =~ ^"Usage: ".*" delete|remove|rm " ]]
    check_no_pastas
  done
  CLEANUP=1
}

@test "pasta delete fails when trying to delete a directory without the recurse flag" {
  dir_name="dir"
  pasta_dir="${PASTA_DIR}/${dir_name}"
  pasta_file="${pasta_dir}/file.txt"
  text_data="data"
  mkdir "$pasta_dir"
  echo "$text_data" > "$pasta_file"
  run "$PASTA" delete "$dir_name"
  [[ "$status" -eq 2 ]]
  clean_output
  [[ "$out" =~ "is a directory. Please use the --recursive flag"$ ]]
  [[ -f "$pasta_file" ]]
  [[ "$text_data" == "$(< "$pasta_file")" ]]
  CLEANUP=1
}

@test "pasta delete fails when a nonexistent pasta is specified" {
  run "$PASTA" delete nonexistent
  [[ "$status" -eq 2 ]]
  clean_output
  [[ "$out" =~ "does not exist" ]]
  CLEANUP=1
}
