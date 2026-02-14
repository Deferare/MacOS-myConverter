# Bundled ffmpeg

`MyConverter` copies `Tools/ffmpeg/ffmpeg` into the app bundle at build time:

- `MyConverter.app/Contents/Resources/ffmpeg`

Notes:

- Keep the filename exactly `ffmpeg`.
- Ensure it has execute permission (`chmod +x Tools/ffmpeg/ffmpeg`).
- The current binary is `ffmpeg 7.1` for `arm64`.
- Replace this binary with your own build if you need different codec/licensing policy.
