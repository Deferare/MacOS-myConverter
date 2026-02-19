# Bundled ffmpeg

`MyConverter` copies `Tools/ffmpeg/ffmpeg` into the app bundle at build time:

- `MyConverter.app/Contents/Resources/ffmpeg`

Notes:

- Keep the filename exactly `ffmpeg`.
- Ensure it has execute permission (`chmod +x Tools/ffmpeg/ffmpeg`).
- The current binary is `ffmpeg 7.1` for `arm64`.
- The project now targets an LGPL-only FFmpeg profile (no `--enable-gpl`).

## Rebuild (LGPL-only)

Use the helper script:

```sh
Tools/ffmpeg/build_ffmpeg_lgpl.sh
```

Optional version override:

```sh
Tools/ffmpeg/build_ffmpeg_lgpl.sh 7.1
```

Optional MP3 encoder build (`libmp3lame` required):

```sh
brew install lame pkg-config
ENABLE_MP3_ENCODER=1 Tools/ffmpeg/build_ffmpeg_lgpl.sh
```

The script replaces `Tools/ffmpeg/ffmpeg` and validates:

- `-version` does not contain `--enable-gpl`
- `-L` reports `GNU Lesser General Public License`
- GPL-only codec libraries are excluded in this baseline profile

Codec note:

- This baseline build does not bundle external codec libraries (for example `libx264`, `libx265`, `libmp3lame`).
- MP3 conversion requires an FFmpeg build that includes an MP3 encoder (`libmp3lame` or `mp3`).
- The app introspects available encoders at runtime, so unsupported encoder options may be hidden automatically.

## Build-time GPL guard

`MyConverter/Scripts/EmbedFFmpegInApp.sh` now refuses to embed a GPL FFmpeg binary by default.

To bypass intentionally (not recommended for App Store release), set:

```sh
ALLOW_GPL_FFMPEG=1
```
