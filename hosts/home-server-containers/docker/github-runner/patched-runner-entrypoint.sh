#!/usr/bin/env bash
# Overlays falcondev-oss's patched actions-runner over the stock binary that
# ships in the myoung34 image, then hands off to myoung34's own entrypoint.
#
# Why: with GitHub cache service v2 the runner learns the cache/results URL from
# the job token, not from an env var, so a stock runner can't be pointed at a
# self-hosted cache. falcondev's fork patches the runner to honour the
# CUSTOM_ACTIONS_RESULTS_URL env var. See https://gha-cache-server.falcondev.io
#
# PATCHED_RUNNER_VERSION MUST match the runner version baked into the myoung34
# image tag in compose.yml (myoung34/github-runner:<version>-ubuntu-noble), and
# DISABLE_AUTO_UPDATE must be set on the container so the patched binary is not
# replaced by an upstream auto-update. Bump both together.
set -euo pipefail

PATCHED_RUNNER_VERSION="2.337.0"
MARKER="/actions-runner/.patched-runner-${PATCHED_RUNNER_VERSION}"

if [[ ! -f "$MARKER" ]]; then
  echo "Overlaying falcondev patched runner v${PATCHED_RUNNER_VERSION}..."
  curl -fsSL -o /tmp/patched-runner.tar.gz \
    "https://github.com/falcondev-oss/github-actions-runner/releases/download/v${PATCHED_RUNNER_VERSION}/actions-runner-linux-x64-${PATCHED_RUNNER_VERSION}.tar.gz"
  tar xzf /tmp/patched-runner.tar.gz -C /actions-runner
  rm -f /tmp/patched-runner.tar.gz
  touch "$MARKER"
fi

exec /entrypoint.sh "$@"
