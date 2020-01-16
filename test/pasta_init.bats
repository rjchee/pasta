#!/usr/bin/env bats

set -euo pipefail

load test_helper

setup() {
  HOME="$(mktemp -d -p "$BATS_TMPDIR" bats_pasta_init.XXX)"
  CLEANUP=0
  export DEBUG=true
  PASTA="$(realpath "${BATS_TEST_DIRNAME}/../pasta")"
}

teardown() {
  if [[ "$CLEANUP" -eq 0 ]]
  then
    echo "$output" > "${HOME}/run_output.txt"
    if [[ -n "${ERROR_MSG:+x}" ]]
    then
      echo "# ${ERROR_MSG}"
    fi
    echo "# test case run in ${HOME}"
  else
    rm -rf "$HOME"
  fi
}

@test "pasta init with no arguments should create a settings file and a pasta directory" {
  run "$PASTA" init
  [[ "$status" -eq 0 ]]
  SETTINGS_FILE="${HOME}/.pasta"
  PASTA_DIR="${HOME}/.pastas"
  [[ -f "$SETTINGS_FILE" ]]
  [[ -d "$PASTA_DIR" ]]
  [[ "$(cat "$SETTINGS_FILE")" -ef "$PASTA_DIR" ]]
  CLEANUP=1
}

@test "pasta init with an argument should create the pasta directory at the given argument" {
  PASTA_DIR="${HOME}/pasta_dir"
  run "$PASTA" init "$PASTA_DIR"
  [[ "$status" -eq 0 ]]
  SETTINGS_FILE="${HOME}/.pasta"
  [[ -f "$SETTINGS_FILE" ]]
  [[ -d "$PASTA_DIR" ]]
  [[ "$(cat "$SETTINGS_FILE")" -ef "$PASTA_DIR" ]]
  CLEANUP=1
}

@test "pasta init with extra arguments should fail" {
  CLEANUP=1
  run "$PASTA" init a b
  [[ "$status" -eq 2 ]]
  clean_output
  [[ "$out" =~ ^"Usage: " ]]
}

@test "pasta init with PASTA_SETTINGS overwritten should create the appropriate settings file" {
  export PASTA_SETTINGS="${HOME}/settings"
  PASTA_DIR="${HOME}/pasta_dir"
  run "$PASTA" init "$PASTA_DIR"
  [[ "$status" -eq 0 ]]
  [[ -f "$PASTA_SETTINGS" ]]
  [[ -d "$PASTA_DIR" ]]
  [[ "$(cat "$PASTA_SETTINGS")" -ef "$PASTA_DIR" ]]
  CLEANUP=1
}

@test "pasta functions should fail when not initialized" {
  prefix="Pasta has not been initialized."
  pasta_name="name"
  file="${HOME}/text.txt"
  echo "text data" >"$file"
  commands=(
    "save ${pasta_name}"
    "insert ${pasta_name}"
    "file  ${file} ${pasta_name}"
    "load ${pasta_name}"
  )
  # Debug output should not be helpful for this test case.
  unset DEBUG
  for cmd in "${commands[@]}"
  do
    ERROR_MSG="Failed with command '$(echo "$cmd" | cut -d' ' -f1)'"
    run "$PASTA" $cmd
    [[ "$status" -eq 2 ]]
    clean_output
    [[ "$out" =~ ^"$prefix" ]]
  done
  CLEANUP=1
}
