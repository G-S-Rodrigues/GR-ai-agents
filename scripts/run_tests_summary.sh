#!/usr/bin/env bash
# Run a test command inside a devcontainer and print a condensed summary instead of the
# full log, so an agent reading the result doesn't pay for hundreds of lines of passing-test
# noise. The full output is always preserved on disk; the printed log path is the way back
# into it when the summary isn't enough.
#
# The inner command runs in the workspace directory, not the container's default cwd
# (`bash -lc` starts in $HOME, one level above, where setup.sh does not exist). Override with
# RUN_TESTS_WORKDIR for a repo that mounts its tree somewhere else.
#
# Usage:
#   run_tests_summary.sh <container_name> "<inner command>"
#
# Example:
#   run_tests_summary.sh GR-gnss_devcontainer "source setup.sh && RELEASE=true ./test/setup/run_tests.sh"

set -uo pipefail

if [[ $# -ne 2 ]]; then
    echo "Usage: $0 <container_name> \"<inner command>\"" >&2
    exit 64
fi

container="$1"
inner_command="$2"
workdir="${RUN_TESTS_WORKDIR:-\$HOME/workspace}"

# Matches real failures only. A count-shaped marker must carry a non-zero number, because
# every green Robot run prints "N tests, N passed, 0 failed" and a bare /FAIL/ match on that
# line made the summary shout failure on a passing suite. Uppercase markers are Robot and
# gtest; lowercase "error:" is the compiler. Deliberately not case-insensitive.
failure_pattern='\| (FAIL|ERROR) \||\[ ERROR \]|\[ *FAILED *\]|^FAILED|Traceback \(most recent call last\)|CMake Error|error:|[1-9][0-9]* ([a-z]+ )?(failed|failures|errors)'
context_limit=60

log_dir="$(mktemp -d)"
log_file="${log_dir}/output.log"

docker exec "${container}" bash -lc "cd \"${workdir}\" && ${inner_command}" >"${log_file}" 2>&1
exit_code=$?

echo "=== exit code: ${exit_code} ==="

context="$(grep -nE -B2 -A6 "${failure_pattern}" "${log_file}")"
if [[ -n "${context}" ]]; then
    echo
    echo "=== FAIL/ERROR context ==="
    echo "${context}" | head -n "${context_limit}"
    context_lines="$(echo "${context}" | wc -l)"
    if (( context_lines > context_limit )); then
        echo "... ${context_lines} context lines, ${context_limit} shown — read the full log below."
    fi
elif (( exit_code != 0 )); then
    echo
    echo "=== no failure marker matched, but the run exited ${exit_code} — read the tail and the full log ==="
fi

echo
echo "=== tail (last 40 lines) ==="
tail -n 40 "${log_file}"

echo
echo "=== full log: ${log_file} ==="

exit "${exit_code}"
