#!/usr/bin/env bash
# Overlays falcondev-oss's patched actions-runner over the stock binary that
# ships in the myoung34 image, then hands off to myoung34's own entrypoint.
#
# Why: with GitHub cache service v2 the runner learns the cache/results URL from
# the job token, not from an env var, so a stock runner can't be pointed at a
# self-hosted cache. falcondev's fork patches the runner to honour the
# CUSTOM_ACTIONS_RESULTS_URL env var. See https://gha-cache-server.falcondev.io
#
# The patched runner version is read from the runner the base image already
# ships (so it always matches, and tracks base-image bumps automatically).
# DISABLE_AUTO_UPDATE must be set on the container so the patched binary is not
# replaced by an upstream auto-update.
#
# PATCHED_RUNNER_SHA256 pins the integrity of the falcondev asset for that
# version. The fork publishes no checksums, so it is computed from the download.
# When the base image bumps its runner version the download changes, this hash
# stops matching, and the script aborts fail-closed: recompute and update it.
set -euo pipefail

PATCHED_RUNNER_SHA256="15eb334a4e876dea32eb8f133761cba8f29041adb6a95464649a1ab6509bc1c7"

# Version the base image's runner reports (read before overlaying).
RUNNER_VERSION="$(/actions-runner/bin/Runner.Listener --version)"
MARKER="/actions-runner/.patched-runner-${RUNNER_VERSION}"

if [[ ! -f "$MARKER" ]]; then
  echo "Overlaying falcondev patched runner v${RUNNER_VERSION}..."
  curl -fsSL -o /tmp/patched-runner.tar.gz \
    "https://github.com/falcondev-oss/github-actions-runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz"
  if ! echo "${PATCHED_RUNNER_SHA256}  /tmp/patched-runner.tar.gz" | sha256sum -c -; then
    echo "ERROR: patched runner checksum mismatch for v${RUNNER_VERSION}." >&2
    echo "The base image's runner version likely changed; recompute and update PATCHED_RUNNER_SHA256." >&2
    exit 1
  fi
  tar xzf /tmp/patched-runner.tar.gz -C /actions-runner
  rm -f /tmp/patched-runner.tar.gz
  touch "$MARKER"
fi

exec /entrypoint.sh "$@"
