#!/bin/sh

set -eu

VERSION="${1:-7.1}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUTPUT_BINARY="${SCRIPT_DIR}/ffmpeg"
ARCH="${FFMPEG_ARCH:-arm64}"
JOBS="${FFMPEG_JOBS:-$(sysctl -n hw.ncpu 2>/dev/null || echo 8)}"
WORK_DIR="${TMPDIR:-/tmp}/myconverter-ffmpeg-${VERSION}-$$"
SRC_ARCHIVE="${WORK_DIR}/ffmpeg-${VERSION}.tar.xz"
SRC_DIR="${WORK_DIR}/ffmpeg-${VERSION}"
INSTALL_DIR="${WORK_DIR}/out"
SOURCE_URL="https://ffmpeg.org/releases/ffmpeg-${VERSION}.tar.xz"

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
  --enable-ffmpeg

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

if printf '%s\n' "${VERSION_OUTPUT}" | grep -q -- "--enable-gpl"; then
  echo "error: Build unexpectedly enabled GPL."
  exit 1
fi

if ! printf '%s\n' "${LICENSE_OUTPUT}" | grep -qi "GNU Lesser General Public License"; then
  echo "error: Built binary is not reporting LGPL licensing."
  exit 1
fi

echo "Built LGPL-only ffmpeg binary: ${OUTPUT_BINARY}"
"${OUTPUT_BINARY}" -version | head -n 3
"${OUTPUT_BINARY}" -L | sed -n '1,16p'
