#!/usr/bin/env bash
# Bring a repo's devcontainer up without paying for its build log.
#
# A cold `docker compose up -d --build` streams the whole image build — apt indexes, every pip
# resolution, every BuildKit step — which is thousands of lines an agent reads and almost never
# needs. This wrapper checks whether the work is needed at all, keeps the full build log on disk,
# and prints a few lines. The log path is the way back in when the summary isn't enough.
#
# Three paths, cheapest first:
#   container already running  -> nothing to do, no compose call at all
#   image exists, no container -> `up -d --no-build` (seconds, ~10 lines)
#   no image, or --rebuild     -> `up -d --build`, log to disk, summary only
#
# `--quiet-build` and `--progress quiet` are deliberately NOT used: they also suppress the failing
# step's own stdout, leaving only "failed to solve" and a Dockerfile line number. The log file is
# what keeps a failure diagnosable.
#
# Usage:
#   devcontainer_up.sh <repo>            # repo name under ~/gitroot, or a path
#   devcontainer_up.sh <repo> --rebuild  # force a rebuild even if the image exists

set -uo pipefail

repo_arg="${1:-}"
rebuild="${2:-}"

if [[ -z "${repo_arg}" ]]; then
    echo "Usage: $0 <repo> [--rebuild]" >&2
    exit 64
fi

if [[ -d "${repo_arg}/.devcontainer" ]]; then
    repo_dir="$(cd "${repo_arg}" && pwd)"
else
    repo_dir="${HOME}/gitroot/${repo_arg}"
fi

compose_file="${repo_dir}/.devcontainer/docker-compose.yml"
if [[ ! -f "${compose_file}" ]]; then
    echo "No devcontainer compose file at ${compose_file}" >&2
    exit 66
fi

# Read the image and container names out of the compose file rather than guessing them. The naming
# is not uniform: a repo may build <name>:devcontainer while naming the container something else.
read -r service image container < <(
    docker compose -f "${compose_file}" config --format json 2>/dev/null | python3 -c '
import json, sys
services = json.load(sys.stdin).get("services", {})
if not services:
    sys.exit(1)
name = "devcontainer" if "devcontainer" in services else next(iter(services))
spec = services[name]
print(name, spec.get("image", ""), spec.get("container_name", ""))
'
) || { echo "Could not resolve a service from ${compose_file}" >&2; exit 65; }

if [[ -z "${container}" ]]; then
    echo "Service '${service}' in ${compose_file} has no container_name" >&2
    exit 65
fi

if [[ "${rebuild}" != "--rebuild" ]] && [[ -n "$(docker ps -q --filter "name=^${container}$")" ]]; then
    echo "=== ${container}: already running, nothing to do ==="
    exit 0
fi

# Project name matched to what VS Code's Remote-Containers uses (<repo>-devcontainer), so a container
# started here is the same compose project VS Code would attach to rather than a parallel one with a
# duplicate network. Deriving it from the cwd instead would give "devcontainer" for every repo,
# because the compose file's parent directory is .devcontainer.
project="$(basename "${repo_dir}")-devcontainer"
compose_args=(-p "${project}" -f "${compose_file}")
if [[ "${rebuild}" == "--rebuild" ]]; then
    build_mode="--build"
elif [[ -n "${image}" ]] && docker image inspect "${image}" >/dev/null 2>&1; then
    build_mode="--no-build"
else
    build_mode="--build"
fi

log_dir="$(mktemp -d)"
log_file="${log_dir}/devcontainer-up.log"

# --progress plain so the log is greppable text rather than ANSI redraw sequences.
docker compose "${compose_args[@]}" --progress plain up -d "${build_mode}" \
    >"${log_file}" 2>&1
exit_code=$?

echo "=== ${container}: ${build_mode}, exit code ${exit_code} ==="

if (( exit_code == 0 )); then
    # Compose pads these lines with a trailing space, and repeats each transition; collapse both.
    grep -E "(Container|Image) .* (Started|Running|Built)[[:space:]]*$" "${log_file}" \
        | sed 's/^ *//; s/[[:space:]]*$//' | sort -u || true
else
    # The markers are extracted as well as tailed, because the tail window alone is not reliable: how
    # much of the failing step BuildKit replays depends on cache state, so a noisy step can push
    # "failed to solve" out of the last N lines. These greps always land it.
    echo
    echo "=== error markers ==="
    grep -nE '^#[0-9]+ ERROR|failed to solve|^ > \[|error:' "${log_file}" | tail -n 15 || true
    echo
    echo "=== tail (last 30 lines) ==="
    tail -n 30 "${log_file}"
fi

echo
echo "=== full log: ${log_file} ==="

exit "${exit_code}"
