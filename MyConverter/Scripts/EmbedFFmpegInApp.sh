#!/bin/sh

set -eu

resolve_first_existing_file() {
  for candidate in "$@"; do
    if [ -n "${candidate}" ] && [ -f "${candidate}" ]; then
      echo "${candidate}"
      return 0
    fi
  done
  return 1
}

SRCROOT_DIR="${SRCROOT:-${PROJECT_DIR:-}}"
if [ -z "${SRCROOT_DIR}" ]; then
  echo "error: SRCROOT/PROJECT_DIR are not set."
  exit 1
fi

FFMPEG_SOURCE=""
if [ -n "${FFMPEG_SOURCE_OVERRIDE:-}" ]; then
  FFMPEG_SOURCE="$(resolve_first_existing_file "${FFMPEG_SOURCE_OVERRIDE}" || true)"
fi

if [ -z "${FFMPEG_SOURCE}" ]; then
  FFMPEG_SOURCE="$(resolve_first_existing_file \
    "${SRCROOT_DIR}/../Tools/ffmpeg/ffmpeg" \
    "${SRCROOT_DIR}/Tools/ffmpeg/ffmpeg" \
    "${SRCROOT_DIR}/../Tools/ffmpeg/ffmpeg-${NATIVE_ARCH_ACTUAL:-}" \
    "${SRCROOT_DIR}/Tools/ffmpeg/ffmpeg-${NATIVE_ARCH_ACTUAL:-}" \
    || true)"
fi

if [ -z "${FFMPEG_SOURCE}" ] && command -v ffmpeg >/dev/null 2>&1; then
  FFMPEG_SOURCE="$(command -v ffmpeg)"
  echo "note: Using system ffmpeg from ${FFMPEG_SOURCE} because bundled binary was not found."
fi

if [ -z "${FFMPEG_SOURCE}" ]; then
  echo "warning: No ffmpeg binary found. Looked for Tools/ffmpeg/ffmpeg near SRCROOT and PATH/system locations."
  exit 0
fi

if [ "${ALLOW_GPL_FFMPEG:-0}" != "1" ]; then
  FFMPEG_VERSION_OUTPUT="$("${FFMPEG_SOURCE}" -version 2>/dev/null || true)"
  FFMPEG_LICENSE_OUTPUT="$("${FFMPEG_SOURCE}" -L 2>/dev/null || true)"

  if [ -n "${FFMPEG_VERSION_OUTPUT}" ] || [ -n "${FFMPEG_LICENSE_OUTPUT}" ]; then
    if printf '%s\n' "${FFMPEG_VERSION_OUTPUT}" | grep -q -- "--enable-gpl"; then
      echo "error: Refusing to embed GPL-enabled ffmpeg binary (${FFMPEG_SOURCE})."
      echo "error: Use an LGPL-only build (remove --enable-gpl and GPL-only external libraries)."
      echo "error: Override only if intentional: set ALLOW_GPL_FFMPEG=1"
      exit 1
    fi

    if printf '%s\n' "${FFMPEG_LICENSE_OUTPUT}" | grep -qi "GNU General Public License" &&
      ! printf '%s\n' "${FFMPEG_LICENSE_OUTPUT}" | grep -qi "GNU Lesser General Public License"; then
      echo "error: Refusing to embed GPL-licensed ffmpeg binary (${FFMPEG_SOURCE})."
      echo "error: Use an LGPL-only build or explicitly set ALLOW_GPL_FFMPEG=1."
      exit 1
    fi
  else
    echo "warning: Could not inspect ffmpeg license output for ${FFMPEG_SOURCE}. Skipping GPL guard."
  fi
fi

FFMPEG_BUNDLE_DIR="${TARGET_BUILD_DIR:?TARGET_BUILD_DIR is required}/${UNLOCALIZED_RESOURCES_FOLDER_PATH:?UNLOCALIZED_RESOURCES_FOLDER_PATH is required}"
FFMPEG_DESTINATION="${FFMPEG_BUNDLE_DIR}/ffmpeg"

mkdir -p "${FFMPEG_BUNDLE_DIR}"
cp "${FFMPEG_SOURCE}" "${FFMPEG_DESTINATION}"
chmod +x "${FFMPEG_DESTINATION}"

echo "Embedded ffmpeg: ${FFMPEG_SOURCE} -> ${FFMPEG_DESTINATION}"
