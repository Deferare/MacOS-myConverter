import Foundation

extension VideoConversionEngine {
    nonisolated static func isFFmpegFormatSupported(_ format: VideoFormatOption, introspection: FFmpegIntrospection) -> Bool {
        if format.ffmpegRequiredMuxers.isEmpty {
            return format.avFileType != nil
        }

        let hasMuxer = format.ffmpegRequiredMuxers.contains(where: { introspection.muxers.contains($0) })
        guard hasMuxer else { return false }
        guard hasCompatibleVideoEncoder(format, introspection: introspection) else { return false }
        return hasCompatibleAudioEncoder(for: format, introspection: introspection)
    }

    nonisolated static func isFFmpegAudioFormatSupported(_ format: AudioFormatOption, introspection: FFmpegIntrospection) -> Bool {
        if format.ffmpegRequiredMuxers.isEmpty {
            return hasCompatibleAudioEncoder(format, introspection: introspection)
        }

        let hasMuxer = format.ffmpegRequiredMuxers.contains(where: { introspection.muxers.contains($0) })
        guard hasMuxer else { return false }
        return hasCompatibleAudioEncoder(format, introspection: introspection)
    }

    nonisolated static func ffmpegDiscoveredFormats(from introspection: FFmpegIntrospection) -> [VideoFormatOption] {
        VideoFormatOption.deduplicatedAndSorted(
            FFmpegParsingSupport.discoveredFormats(
                from: introspection,
                includeExtension: VideoFormatOption.isLikelyVideoFileExtension(_:),
                makeFormat: VideoFormatOption.fromFFmpegExtension(_:muxer:)
            )
        )
    }

    nonisolated static func ffmpegDiscoveredAudioFormats(from introspection: FFmpegIntrospection) -> [AudioFormatOption] {
        AudioFormatOption.deduplicatedAndSorted(
            FFmpegParsingSupport.discoveredFormats(
                from: introspection,
                includeExtension: AudioFormatOption.isLikelyAudioFileExtension(_:),
                makeFormat: AudioFormatOption.fromFFmpegExtension(_:muxer:)
            )
        )
    }

    nonisolated static func hasCompatibleAudioEncoder(_ format: AudioFormatOption, introspection: FFmpegIntrospection) -> Bool {
        AudioEncoderOption.allCases.contains { option in
            guard option != .auto else { return false }
            guard option.isCompatible(with: format) else { return false }
            return option.codecCandidates.contains(where: { introspection.audioEncoders.contains($0) })
        }
    }

    nonisolated static func hasCompatibleVideoEncoder(_ format: VideoFormatOption, introspection: FFmpegIntrospection) -> Bool {
        if !format.supportsVideoEncoderSelection {
            return format.allowsFFmpegAutomaticVideoCodec
        }

        return VideoEncoderOption.allCases.contains { option in
            guard option != .auto else { return false }
            guard option.isCompatible(with: format) else { return false }
            return option.codecCandidates.contains(where: { introspection.videoEncoders.contains($0) })
        }
    }

    nonisolated static func hasCompatibleAudioEncoder(for format: VideoFormatOption, introspection: FFmpegIntrospection) -> Bool {
        guard format.supportsAudioTrack else { return true }

        return AudioEncoderOption.allCases.contains { option in
            guard option != .auto else { return false }
            guard option.isCompatible(with: format) else { return false }
            return option.codecCandidates.contains(where: { introspection.audioEncoders.contains($0) })
        }
    }

    nonisolated static func isLikelyVideoMuxer(_ descriptor: FFmpegMuxerDescriptor) -> Bool {
        let name = descriptor.name.lowercased()
        let description = descriptor.description.lowercased()

        let explicitVideoMuxers: Set<String> = [
            "3gp", "avi", "flv", "gif", "ipod", "matroska", "mov", "mp4", "mpeg", "mpegts", "ogg", "webm"
        ]
        if explicitVideoMuxers.contains(name) {
            return true
        }

        let keywords = [
            "video", "quicktime", "matroska", "webm", "mpeg", "movie", "avi", "flv", "ogg", "gif", "animation"
        ]
        return keywords.contains(where: { description.contains($0) })
    }

    nonisolated static func isLikelyAudioMuxer(_ descriptor: FFmpegMuxerDescriptor) -> Bool {
        let name = descriptor.name.lowercased()
        let description = descriptor.description.lowercased()

        let explicitAudioMuxers: Set<String> = [
            "aac", "ac3", "adts", "aiff", "caf", "flac", "ipod", "matroska", "mp3", "ogg", "opus", "wav"
        ]
        if explicitAudioMuxers.contains(name) {
            return true
        }

        let keywords = [
            "audio", "sound", "aac", "mp3", "wave", "wav", "flac", "opus", "ogg", "aiff", "caf"
        ]
        return keywords.contains(where: { description.contains($0) })
    }
}
