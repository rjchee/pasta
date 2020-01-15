#!/usr/bin/env bats

set -euo pipefail

load test_helper

setup() {
  HOME="$(mktemp -d -p "$BATS_TMPDIR" bats_pasta_init.XXX)"
  export DEBUG=true
  PASTA="$(realpath "${BATS_TEST_DIRNAME}/../pasta")"
  CLEANUP=0
}

teardown() {
  [[ "$CLEANUP" -eq 0 ]] && echo "$output" > "${TMP_DIR}/run_output.txt" || rm -rf "$HOME"
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
  [[ "$status" -ne 0 ]]
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
