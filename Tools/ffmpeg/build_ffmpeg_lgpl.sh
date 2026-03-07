#!/bin/sh

set -eu

VERSION="${1:-7.1}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUTPUT_BINARY="${SCRIPT_DIR}/ffmpeg"
ARCH="${FFMPEG_ARCH:-arm64}"
JOBS="${FFMPEG_JOBS:-$(sysctl -n hw.ncpu 2>/dev/null || echo 8)}"
ENABLE_MP3_ENCODER="${ENABLE_MP3_ENCODER:-0}"
LAME_VERSION="${LAME_VERSION:-3.100}"
WORK_DIR="${TMPDIR:-/tmp}/myconverter-ffmpeg-${VERSION}-$$"
SRC_ARCHIVE="${WORK_DIR}/ffmpeg-${VERSION}.tar.xz"
SRC_DIR="${WORK_DIR}/ffmpeg-${VERSION}"
INSTALL_DIR="${WORK_DIR}/out"
SOURCE_URL="https://ffmpeg.org/releases/ffmpeg-${VERSION}.tar.xz"
LAME_SOURCE_URL="https://downloads.sourceforge.net/project/lame/lame/${LAME_VERSION}/lame-${LAME_VERSION}.tar.gz"

cleanup() {
  rm -rf "${WORK_DIR}"
}
trap cleanup EXIT INT TERM

mkdir -p "${WORK_DIR}"

echo "Downloading FFmpeg ${VERSION} from ${SOURCE_URL}"
curl -fL "${SOURCE_URL}" -o "${SRC_ARCHIVE}"

echo "Extracting source archive"
tar -xf "${SRC_ARCHIVE}" -C "${WORK_DIR}"

if [ ! -d "${SRC_DIR}" ]; then
  echo "error: Extracted source directory not found: ${SRC_DIR}"
  exit 1
fi

cd "${SRC_DIR}"

echo "Configuring LGPL-only FFmpeg build"
EXTRA_CONFIGURE_ARG=""
EXTRA_CFLAGS=""
EXTRA_LDFLAGS=""

if [ "${ENABLE_MP3_ENCODER}" = "1" ]; then
  LAME_ARCHIVE="${WORK_DIR}/lame-${LAME_VERSION}.tar.gz"
  LAME_SRC_DIR="${WORK_DIR}/lame-${LAME_VERSION}"

  echo "Downloading LAME ${LAME_VERSION} from ${LAME_SOURCE_URL}"
  curl -fL "${LAME_SOURCE_URL}" -o "${LAME_ARCHIVE}"

  echo "Extracting LAME source archive"
  tar -xf "${LAME_ARCHIVE}" -C "${WORK_DIR}"

  if [ ! -d "${LAME_SRC_DIR}" ]; then
    echo "error: Extracted LAME source directory not found: ${LAME_SRC_DIR}"
    exit 1
  fi

  echo "Building static libmp3lame"
  cd "${LAME_SRC_DIR}"
  ./configure \
    --prefix="${INSTALL_DIR}" \
    --disable-shared \
    --enable-static \
    --disable-decoder
  make -j"${JOBS}"
  make install
  cd "${SRC_DIR}"

  if [ ! -f "${INSTALL_DIR}/lib/libmp3lame.a" ]; then
    echo "error: Failed to build static libmp3lame."
    exit 1
  fi

  EXTRA_CONFIGURE_ARG="--enable-libmp3lame"
  EXTRA_CFLAGS="-I${INSTALL_DIR}/include"
  EXTRA_LDFLAGS="-L${INSTALL_DIR}/lib"
  echo "MP3 encoder enabled via libmp3lame."
fi

# shellcheck disable=SC2086
./configure \
  --prefix="${INSTALL_DIR}" \
  --arch="${ARCH}" \
  --cc=/usr/bin/clang \
  --disable-debug \
  --disable-doc \
  --disable-ffplay \
  --disable-ffprobe \
  --disable-network \
  --disable-shared \
  --enable-static \
  --enable-ffmpeg \
  ${EXTRA_CONFIGURE_ARG} \
  ${EXTRA_CFLAGS:+--extra-cflags=${EXTRA_CFLAGS}} \
  ${EXTRA_LDFLAGS:+--extra-ldflags=${EXTRA_LDFLAGS}}

echo "Building FFmpeg with ${JOBS} jobs"
make -j"${JOBS}"

echo "Installing FFmpeg into temporary output"
make install

if [ ! -f "${INSTALL_DIR}/bin/ffmpeg" ]; then
  echo "error: Built ffmpeg binary not found."
  exit 1
fi

cp "${INSTALL_DIR}/bin/ffmpeg" "${OUTPUT_BINARY}"
chmod +x "${OUTPUT_BINARY}"

echo "Verifying license output"
LICENSE_OUTPUT="$("${OUTPUT_BINARY}" -L 2>/dev/null || true)"
VERSION_OUTPUT="$("${OUTPUT_BINARY}" -version 2>/dev/null || true)"
LICENSE_OUTPUT_SINGLE_LINE="$(printf '%s' "${LICENSE_OUTPUT}" | tr '\n' ' ')"

if printf '%s\n' "${VERSION_OUTPUT}" | grep -q -- "--enable-gpl"; then
  echo "error: Build unexpectedly enabled GPL."
  exit 1
fi

if ! printf '%s\n' "${LICENSE_OUTPUT_SINGLE_LINE}" | grep -Eqi "GNU[[:space:]]+Lesser[[:space:]]+General[[:space:]]+Public[[:space:]]+License"; then
  echo "error: Built binary is not reporting LGPL licensing."
  exit 1
fi

echo "Built LGPL-only ffmpeg binary: ${OUTPUT_BINARY}"
"${OUTPUT_BINARY}" -version | head -n 3
"${OUTPUT_BINARY}" -L | sed -n '1,16p'

if [ "${ENABLE_MP3_ENCODER}" = "1" ]; then
  if ! "${OUTPUT_BINARY}" -hide_banner -encoders 2>/dev/null | grep -Eq '(^|[[:space:]])(libmp3lame|mp3)([[:space:]]|$)'; then
    echo "error: MP3 encoder verification failed. libmp3lame/mp3 encoder not found in built binary."
    exit 1
  fi
  echo "MP3 encoder verification passed."
fi
