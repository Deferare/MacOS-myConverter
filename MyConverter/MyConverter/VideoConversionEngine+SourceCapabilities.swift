import AVFoundation
import Foundation

extension VideoConversionEngine {
    private static func makeVideoCapabilities(
        availableOutputFormats: [VideoFormatOption],
        warningMessage: String? = nil,
        errorMessage: String? = nil
    ) -> VideoSourceCapabilities {
        VideoSourceCapabilities(
            availableOutputFormats: availableOutputFormats,
            warningMessage: warningMessage,
            errorMessage: errorMessage
        )
    }

    private static func makeAudioCapabilities(
        availableOutputFormats: [AudioFormatOption],
        warningMessage: String? = nil,
        errorMessage: String? = nil
    ) -> AudioSourceCapabilities {
        AudioSourceCapabilities(
            availableOutputFormats: availableOutputFormats,
            warningMessage: warningMessage,
            errorMessage: errorMessage
        )
    }

    static func sourceCapabilitiesForAudio(for inputURL: URL) async -> AudioSourceCapabilities {
        let defaultFormats = defaultAudioOutputFormats()

        guard let ffmpegPath = FFmpegBinaryLocator.findPath() else {
            return makeAudioCapabilities(
                availableOutputFormats: [],
                errorMessage: "Audio conversion requires ffmpeg, but ffmpeg was not found."
            )
        }

        guard !defaultFormats.isEmpty else {
            return makeAudioCapabilities(
                availableOutputFormats: [],
                errorMessage: "No compatible audio output format is available with the current ffmpeg build."
            )
        }

        let asset = AVURLAsset(url: inputURL)
        do {
            try await ensureAssetHasAudioTrack(asset)
            return makeAudioCapabilities(availableOutputFormats: defaultFormats)
        } catch ConversionError.noTracksFound {
            return makeAudioCapabilities(
                availableOutputFormats: [],
                errorMessage: "No audio track found in this source."
            )
        } catch {
            let hasAudioTrack = await ffmpegCanReadMappedStream(
                ffmpegPath: ffmpegPath,
                inputURL: inputURL,
                mapSpecifier: "0:a:0",
                frameArguments: ["-frames:a", "1"]
            )

            if hasAudioTrack {
                return makeAudioCapabilities(availableOutputFormats: defaultFormats)
            }

            return makeAudioCapabilities(
                availableOutputFormats: [],
                errorMessage: "No readable audio track found in this source."
            )
        }
    }

    static func sourceCapabilities(for inputURL: URL) async -> VideoSourceCapabilities {
        let ffmpegPath = FFmpegBinaryLocator.findPath()
        let ffmpegAvailable = ffmpegPath != nil
        let asset = AVURLAsset(url: inputURL)
        let defaultFormats = defaultOutputFormats()

        do {
            try await ensureAssetHasVideoTrack(asset)
            let avSupported = await supportedOutputFormatsWithAVFoundation(for: asset)
            if ffmpegAvailable {
                return makeVideoCapabilities(
                    availableOutputFormats: VideoFormatOption.deduplicatedAndSorted(defaultFormats + avSupported)
                )
            }

            if avSupported.isEmpty {
                return makeVideoCapabilities(
                    availableOutputFormats: [],
                    errorMessage: "No compatible output container is available for this source."
                )
            }

            return makeVideoCapabilities(availableOutputFormats: avSupported)
        } catch ConversionError.noVideoTrackFound {
            return makeVideoCapabilities(
                availableOutputFormats: [],
                errorMessage: "No video track found in this source."
            )
        } catch {
            if let ffmpegPath {
                let hasVideoTrack = await ffmpegCanReadMappedStream(
                    ffmpegPath: ffmpegPath,
                    inputURL: inputURL,
                    mapSpecifier: "0:v:0",
                    frameArguments: ["-frames:v", "1"]
                )

                if !hasVideoTrack {
                    return makeVideoCapabilities(
                        availableOutputFormats: [],
                        errorMessage: "No readable video track found in this source."
                    )
                }

                return makeVideoCapabilities(availableOutputFormats: defaultFormats)
            }

            return makeVideoCapabilities(
                availableOutputFormats: [],
                errorMessage: "This source cannot be opened by AVFoundation and ffmpeg is unavailable."
            )
        }
    }
}
