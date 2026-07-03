#!/usr/bin/env bash
# Runs on the app VM as the deploy user. Invoked by the Forgejo workflow as:
#   bash /tmp/swap.sh <sha>
#
# Expects /tmp/esther_pictures-<sha>.tar.gz to already be in place (scp'd by the
# workflow). Extracts the new release, migrates, swaps the `current` symlink,
# restarts the service, and prunes old releases.
set -euo pipefail

SHA="${1:?usage: swap.sh <sha>}"
APP_ROOT="/opt/estherpictures"
RELEASES_DIR="${APP_ROOT}/releases"
TARBALL="/tmp/esther_pictures-${SHA}.tar.gz"
TARGET_DIR="${RELEASES_DIR}/${SHA}"
CURRENT_LINK="${APP_ROOT}/current"

if [[ ! -f "${TARBALL}" ]]; then
  echo "tarball not found: ${TARBALL}" >&2
  exit 1
fi

mkdir -p "${TARGET_DIR}"
tar -xzf "${TARBALL}" -C "${TARGET_DIR}" --strip-components=1

# Load runtime env so the migrate binary (which reads DATABASE_PATH,
# SECRET_KEY_BASE, etc.) can start the repo.
set -a
# shellcheck disable=SC1091
source /etc/esther_pictures.env
set +a

# Migrate the NEW release before swapping the symlink, so a failed migration
# aborts the deploy without restarting on a half-migrated DB.
"${TARGET_DIR}/bin/migrate"

ln -sfn "${TARGET_DIR}" "${CURRENT_LINK}"

sudo systemctl restart estherpictures

# Keep the last 5 releases, prune older ones.
ls -1dt "${RELEASES_DIR}"/*/ | tail -n +6 | xargs -r rm -rf

rm -f "${TARBALL}" /tmp/swap.sh

echo "deployed ${SHA}"
