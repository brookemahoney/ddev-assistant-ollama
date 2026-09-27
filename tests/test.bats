#!/usr/bin/env bats

# Bats is a testing framework for Bash
# Documentation https://bats-core.readthedocs.io/en/stable/
# Bats libraries documentation https://github.com/ztombol/bats-docs

# For local tests, install bats-core, bats-assert, bats-file, bats-support
# And run this in the add-on root directory:
#   bats ./tests/test.bats
# To exclude release tests:
#   bats ./tests/test.bats --filter-tags '!release'
# For debugging:
#   bats ./tests/test.bats --show-output-of-passing-tests --verbose-run --print-output-on-failure

setup() {
  set -eu -o pipefail

  # Override this variable for your add-on:
  export GITHUB_REPO=brookemahoney/ddev-assistant-ollama

  TEST_BREW_PREFIX="$(brew --prefix 2>/dev/null || true)"
  export BATS_LIB_PATH="${BATS_LIB_PATH}:${TEST_BREW_PREFIX}/lib:/usr/lib/bats"
  bats_load_library bats-assert
  bats_load_library bats-file
  bats_load_library bats-support

  export DIR="$(cd "$(dirname "${BATS_TEST_FILENAME}")/.." >/dev/null 2>&1 && pwd)"
  export PROJNAME="test-$(basename "${GITHUB_REPO}")"
  # Smallest model in the Ollama library, so the suite can afford to pull it.
  export TEST_MODEL="smollm2:135m"
  mkdir -p "${HOME}/tmp"
  export TESTDIR="$(mktemp -d "${HOME}/tmp/${PROJNAME}.XXXXXX")"
  export DDEV_NONINTERACTIVE=true
  export DDEV_NO_INSTRUMENTATION=true
  ddev delete -Oy "${PROJNAME}" >/dev/null 2>&1 || true
  cd "${TESTDIR}"
  run ddev config --project-name="${PROJNAME}" --project-tld=ddev.site
  assert_success
  run ddev start -y
  assert_success
}

health_checks() {
  # The project itself still works with the add-on installed.
  DDEV_DEBUG=true run ddev launch
  assert_success
  assert_output --partial "FULLURL https://${PROJNAME}.ddev.site"

  # The CLI has to be on $PATH in every shell type, including non-interactive
  # `ddev exec`, so that a project can call it from scripts and hooks.
  run ddev exec "command -v ollama"
  assert_success
  assert_output --partial "/usr/local/bin/ollama"

  run ddev exec "ollama --version"
  assert_success

  # The post-start hook has to leave the server answering when `ddev start` or
  # `ddev restart` returns, not merely running in the background.
  run ddev exec "curl -sf http://localhost:11434/api/version"
  assert_success
  assert_output --partial "\"version\""

  # Models live in the DDEV global cache, shared by every project on the
  # machine, and must be writable by the web user so `ollama pull` works.
  run ddev exec "test -d /mnt/ddev-global-cache/assistant-ollama/models && test -w /mnt/ddev-global-cache/assistant-ollama/models"
  assert_success

  # ddev describe is where the endpoint is advertised.
  run ddev describe
  assert_success
  assert_output --partial "Ollama API"
}

inference_checks() {
  # Actually run a model. The `ollama` binary on its own serves the API and
  # pulls models, so without the runner libraries installed beside it every
  # completion fails at runtime rather than at install time. Pulling one small
  # model is what tells the two apart.
  run ddev exec "ollama pull ${TEST_MODEL}"
  assert_success

  run ddev exec "curl -sf -X POST http://localhost:11434/api/generate -d '{\"model\":\"${TEST_MODEL}\",\"prompt\":\"Say hi\",\"stream\":false,\"options\":{\"num_predict\":5}}'"
  assert_success
  assert_output --partial '"done":true'
}

restart_checks() {
  # The server is started by a hook, so it has to come back on every restart
  # and running the start script again has to be a no-op rather than a second
  # server fighting for the port.
  run ddev restart -y
  assert_success

  run ddev exec "curl -sf http://localhost:11434/api/version"
  assert_success
  assert_output --partial "\"version\""

  run ddev exec "ddev-ollama-start"
  assert_success
  assert_output --partial "already running"
}

teardown() {
  set -eu -o pipefail
  ddev delete -Oy "${PROJNAME}" >/dev/null 2>&1
  # Persist TESTDIR if running inside GitHub Actions. Useful for uploading test result artifacts
  # See example at https://github.com/ddev/github-action-add-on-test#preserving-artifacts
  if [ -n "${GITHUB_ENV:-}" ]; then
    [ -e "${GITHUB_ENV:-}" ] && echo "TESTDIR=${HOME}/tmp/${PROJNAME}" >> "${GITHUB_ENV}"
  else
    [ "${TESTDIR}" != "" ] && rm -rf "${TESTDIR}"
  fi
}

@test "install from directory" {
  set -eu -o pipefail
  echo "# ddev add-on get ${DIR} with project ${PROJNAME} in $(pwd)" >&3
  run ddev add-on get "${DIR}"
  assert_success
  run ddev restart -y
  assert_success
  health_checks
  inference_checks
  restart_checks
}

# bats test_tags=release
@test "install from release" {
  set -eu -o pipefail
  echo "# ddev add-on get ${GITHUB_REPO} with project ${PROJNAME} in $(pwd)" >&3
  run ddev add-on get "${GITHUB_REPO}"
  assert_success
  run ddev restart -y
  assert_success
  health_checks
  inference_checks
  restart_checks
}
