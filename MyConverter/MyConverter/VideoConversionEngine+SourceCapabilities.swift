import AVFoundation
import Foundation

extension VideoConversionEngine {
    private static func makeSourceCapabilityCacheKey(for inputURL: URL, ffmpegPath: String?) -> String {
        let standardizedURL = inputURL.standardizedFileURL
        let resourceValues = try? standardizedURL.resourceValues(
            forKeys: [.contentModificationDateKey, .fileSizeKey]
        )
        let fileSize = resourceValues?.fileSize ?? -1
        let modificationInterval = resourceValues?.contentModificationDate?.timeIntervalSinceReferenceDate ?? -1
        return "\(standardizedURL.path)|\(fileSize)|\(modificationInterval)|\(ffmpegPath ?? "none")"
    }

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
        let ffmpegPath = FFmpegBinaryLocator.findPath()
        let cacheKey = makeSourceCapabilityCacheKey(for: inputURL, ffmpegPath: ffmpegPath)
        if let cached = sourceCapabilityCacheQueue.sync(execute: { audioSourceCapabilitiesCache[cacheKey] }) {
            return cached
        }

        let resolved = await Task.detached(priority: .userInitiated) {
            await resolveAudioSourceCapabilities(for: inputURL, ffmpegPath: ffmpegPath)
        }.value

        sourceCapabilityCacheQueue.sync {
            audioSourceCapabilitiesCache[cacheKey] = resolved
        }
        return resolved
    }

    private static func resolveAudioSourceCapabilities(
        for inputURL: URL,
        ffmpegPath: String?
    ) async -> AudioSourceCapabilities {
        guard let ffmpegPath else {
            return makeAudioCapabilities(
                availableOutputFormats: [],
                errorMessage: "Audio conversion requires ffmpeg, but ffmpeg was not found."
            )
        }

        let defaultFormats = defaultAudioOutputFormats()
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
        let cacheKey = makeSourceCapabilityCacheKey(for: inputURL, ffmpegPath: ffmpegPath)
        if let cached = sourceCapabilityCacheQueue.sync(execute: { videoSourceCapabilitiesCache[cacheKey] }) {
            return cached
        }

        let resolved = await Task.detached(priority: .userInitiated) {
            await resolveVideoSourceCapabilities(for: inputURL, ffmpegPath: ffmpegPath)
        }.value

        sourceCapabilityCacheQueue.sync {
            videoSourceCapabilitiesCache[cacheKey] = resolved
        }
        return resolved
    }

    private static func resolveVideoSourceCapabilities(
        for inputURL: URL,
        ffmpegPath: String?
    ) async -> VideoSourceCapabilities {
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
