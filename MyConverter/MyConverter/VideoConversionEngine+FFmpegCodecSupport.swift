import Foundation

extension VideoConversionEngine {
    static func codecCandidates(
        availableCodecs: [String],
        allowAutomatic: Bool
    ) -> [String?] {
        if availableCodecs.isEmpty {
            return allowAutomatic ? [nil] : []
        }
        return availableCodecs.map(Optional.init)
    }

    static func codecPairs(
        videoCodecs: [String?],
        audioCodecs: [String?]
    ) -> [(video: String?, audio: String?)] {
        var pairs: [(video: String?, audio: String?)] = []
        pairs.reserveCapacity(videoCodecs.count * audioCodecs.count)

        for videoCodec in videoCodecs {
            for audioCodec in audioCodecs {
                pairs.append((video: videoCodec, audio: audioCodec))
            }
        }

        return pairs
    }

    static func audioCodecPairs(_ audioCodecs: [String?]) -> [(video: String?, audio: String?)] {
        audioCodecs.map { (video: nil, audio: $0) }
    }
}
