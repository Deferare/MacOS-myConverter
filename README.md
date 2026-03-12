# MyConverter

MKV to MP4 변환기입니다. 일부 MKV는 Apple 기본 프레임워크가 직접 열지 못하므로, 앱은 `ffmpeg`를 보조 변환기로 사용합니다.

현재 프로젝트는 같은 Xcode 프로젝트 안에서 아래 두 앱 타깃을 함께 관리합니다.

- `MyConverter`: macOS 앱. 번들된 `ffmpeg` 실행 파일을 직접 실행합니다.
- `MyConverteriPad`: iPad 앱. `FFmpeg-iOS` 패키지를 통해 앱 프로세스 내부에서 `ffmpeg`를 호출합니다.

## 배포 전략 (사용자 설치 없이)

macOS 앱은 앱 번들에 `ffmpeg` 바이너리를 포함하면 최종 사용자가 별도 설치할 필요가 없습니다.

1. `LGPL` 기반 `ffmpeg` 빌드를 준비합니다.
2. 바이너리 이름을 `ffmpeg`로 두고 실행 권한을 부여합니다.
3. Xcode 타깃 리소스에 추가하여 앱 번들에 포함합니다.
4. 빌드 결과에서 아래 경로 중 하나에 들어가도록 맞춥니다.

- `MyConverter.app/Contents/Resources/ffmpeg`
- `MyConverter.app/Contents/Resources/bin/ffmpeg`
- `MyConverter.app/Contents/MacOS/ffmpeg`

## 인코딩 정책 (GPL 리스크 축소)

앱은 ffmpeg에서 아래 순서로 시도합니다.

1. `h264_videotoolbox + aac`
2. `mpeg4 + aac`

`libx264`는 사용하지 않도록 구성되어 있습니다.  
빠른 리먹스(`-c copy`)는 QuickTime 호환성 이슈(오디오만 재생 등)를 피하기 위해 기본 경로에서 제외했습니다.

## 라이선스 주의

1. ffmpeg 자체는 무료지만, 포함 코덱/옵션에 따라 라이선스 의무가 달라집니다.
2. 앱 배포 시 ffmpeg 라이선스 고지 문서를 함께 포함하세요.
3. 상용/공개 배포 전에는 실제 ffmpeg 빌드 옵션(`--enable-gpl` 여부)을 최종 확인하세요.
4. iPad 앱은 [`FFmpeg-iOS`](https://github.com/kewlbear/FFmpeg-iOS.git)와 [`FFmpeg-iOS-Support`](https://github.com/kewlbear/FFmpeg-iOS-Support.git)에 의존합니다. 둘 다 LGPL 계열이므로 공개 배포 전 라이선스 고지와 소스 제공 요건을 다시 확인하세요.

## 번들 ffmpeg 포함하기 (macOS)

1. 아래 경로에 ffmpeg 바이너리를 넣으세요.
   - `/Users/deferare/Main/MacOS-myConverter/Tools/ffmpeg/ffmpeg`
2. 해당 파일 실행 권한을 줍니다.
   - `chmod +x Tools/ffmpeg/ffmpeg`
3. 빌드하면 스크립트가 위 바이너리를 앱 번들로 복사합니다.
   - `MyConverter.app/Contents/Resources/ffmpeg`
4. 앱은 우선 번들 경로를 검색하고, 없을 때만 PATH/system ffmpeg를 사용합니다.

빌드 스크립트는 `MyConverter/MyConverter.xcodeproj/project.pbxproj`에 있는
`Embed ffmpeg` Build Phase가 수행합니다.

## iPad FFmpeg 브리지

iPad 타깃은 외부 실행 파일을 실행하지 않습니다. 대신 `FFmpeg-iOS` Swift Package가 제공하는 `FFmpegSupport` 브리지를 통해 앱 내부에서 `FFmpeg_main`을 호출합니다.

- 패키지 해상도: `xcodebuild -resolvePackageDependencies -project MyConverter/MyConverter.xcodeproj -scheme MyConverteriPad`
- iPad 빌드: `xcodebuild -project MyConverter/MyConverter.xcodeproj -scheme MyConverteriPad -destination 'generic/platform=iOS Simulator' build`

iPad 빌드 시에는 Swift Package Manager가 FFmpeg iOS 바이너리 아티팩트를 자동으로 내려받습니다.
