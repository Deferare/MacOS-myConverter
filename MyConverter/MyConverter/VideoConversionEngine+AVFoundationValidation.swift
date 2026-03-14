import AVFoundation
import Foundation

extension VideoConversionEngine {
    static func supportedOutputFormatsWithAVFoundation(for asset: AVURLAsset) async -> [VideoFormatOption] {
        await withTaskGroup(
            of: (Int, VideoFormatOption)?.self,
            returning: [VideoFormatOption].self
        ) { group in
            for (index, format) in VideoFormatOption.avFoundationDefaultFormats.enumerated() {
                guard let fileType = format.avFileType else { continue }
                group.addTask {
                    let isSupported = await hasCompatibleExportPreset(
                        for: asset,
                        preferredPresets: preferredExportPresets,
                        outputFileType: fileType
                    )
                    guard isSupported else { return nil }
                    return (index, format)
                }
            }

            var supported: [(Int, VideoFormatOption)] = []
            for await result in group {
                guard let result else { continue }
                supported.append(result)
            }

            return supported
                .sorted { $0.0 < $1.0 }
                .map(\.1)
        }
    }

    static func ensureAssetReadable(_ asset: AVURLAsset) async throws {
        try await validatePlayableAsset(asset)
        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        let hasMediaTrack = !(videoTracks.isEmpty && audioTracks.isEmpty)
        if !hasMediaTrack {
            throw ConversionError.noTracksFound
        }
    }

    static func validatePlayableAsset(_ asset: AVURLAsset) async throws {
        let isPlayable = try await asset.load(.isPlayable)
        _ = try await asset.load(.duration)
        guard isPlayable else {
            throw ConversionError.unreadableAsset
        }
    }
}
