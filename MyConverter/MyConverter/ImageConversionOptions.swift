import Foundation
import ImageIO
import UniformTypeIdentifiers

struct ImageFormatOption: Identifiable, Hashable, Sendable {
    let id: String
    let displayName: String
    let fileExtension: String
    let imageIOUTTypeIdentifier: String?
    let supportsCompressionQuality: Bool
    let supportsAnimation: Bool
    let supportsPNGCompressionLevel: Bool
    let ffmpegEncoderCandidates: [String]
    let ffmpegRequiredMuxers: [String]
    let preferredFFmpegMuxer: String?
    let allowsFFmpegAutomaticCodec: Bool

    nonisolated var utType: UTType? {
        let identifier = imageIOUTTypeIdentifier ?? id
        return UTType(identifier)
    }

    nonisolated var normalizedID: String {
        id.lowercased()
    }

    nonisolated static func fromImageIOTypeIdentifier(_ identifier: String) -> ImageFormatOption {
        let normalizedIdentifier = identifier.lowercased()
        let profile = ImageFormatProfile.byIdentifier[normalizedIdentifier]
        let utType = UTType(identifier)

        let displayName =
            profile?.displayName ??
            utType?.localizedDescription ??
            prettifyIdentifier(identifier)

        let fileExtension =
            profile?.fileExtension ??
            utType?.preferredFilenameExtension ??
            guessedFileExtension(from: identifier)

        return ImageFormatOption(
            id: normalizedIdentifier,
            displayName: displayName,
            fileExtension: fileExtension,
            imageIOUTTypeIdentifier: identifier,
            supportsCompressionQuality: profile?.supportsCompressionQuality ?? false,
            supportsAnimation: profile?.supportsAnimation ?? false,
            supportsPNGCompressionLevel: profile?.supportsPNGCompressionLevel ?? (normalizedIdentifier == "public.png"),
            ffmpegEncoderCandidates: profile?.ffmpegEncoderCandidates ?? [],
            ffmpegRequiredMuxers: profile?.ffmpegRequiredMuxers ?? [],
            preferredFFmpegMuxer: profile?.preferredFFmpegMuxer,
            allowsFFmpegAutomaticCodec: profile?.allowsFFmpegAutomaticCodec ?? false
        )
    }

    nonisolated static func fromFFmpegExtension(_ fileExtension: String, muxer: String) -> ImageFormatOption {
        let normalizedExtension = normalizedFileExtension(fileExtension)
        let normalizedMuxer = muxer.lowercased()

        let extensionUTType = UTType(filenameExtension: normalizedExtension)
        let identifier = extensionUTType?.identifier.lowercased()
        let profile =
            identifier.flatMap { ImageFormatProfile.byIdentifier[$0] } ??
            ImageFormatProfile.byFileExtension[normalizedExtension]

        let resolvedUTType =
            profile?.imageIOUTTypeIdentifier.flatMap(UTType.init) ??
            extensionUTType

        let resolvedIdentifier =
            profile?.id ??
            resolvedUTType?.identifier.lowercased() ??
            "ffmpeg.\(normalizedExtension)"

        let resolvedDisplayName =
            profile?.displayName ??
            resolvedUTType?.localizedDescription ??
            normalizedExtension.uppercased()

        let resolvedExtension =
            profile?.fileExtension ??
            resolvedUTType?.preferredFilenameExtension ??
            normalizedExtension

        let resolvedRequiredMuxers = uniqueStrings((profile?.ffmpegRequiredMuxers ?? []) + [normalizedMuxer])

        return ImageFormatOption(
            id: resolvedIdentifier,
            displayName: resolvedDisplayName,
            fileExtension: resolvedExtension,
            imageIOUTTypeIdentifier: profile?.imageIOUTTypeIdentifier ?? resolvedUTType?.identifier,
            supportsCompressionQuality: profile?.supportsCompressionQuality ?? false,
            supportsAnimation: profile?.supportsAnimation ?? false,
            supportsPNGCompressionLevel: profile?.supportsPNGCompressionLevel ?? false,
            ffmpegEncoderCandidates: profile?.ffmpegEncoderCandidates ?? [],
            ffmpegRequiredMuxers: resolvedRequiredMuxers,
            preferredFFmpegMuxer: profile?.preferredFFmpegMuxer ?? normalizedMuxer,
            allowsFFmpegAutomaticCodec: profile?.allowsFFmpegAutomaticCodec ?? true
        )
    }

    nonisolated static func isLikelyImageFileExtension(_ fileExtension: String) -> Bool {
        let normalizedExtension = normalizedFileExtension(fileExtension)
        guard !normalizedExtension.isEmpty else { return false }

        if let utType = UTType(filenameExtension: normalizedExtension), utType.conforms(to: .image) {
            return true
        }

        return ImageFormatProfile.byFileExtension[normalizedExtension] != nil
    }

    nonisolated static var ffmpegKnownFormats: [ImageFormatOption] {
        ImageFormatProfile.ffmpegOnlyProfiles.map { profile in
            ImageFormatOption(
                id: profile.id,
                displayName: profile.displayName,
                fileExtension: profile.fileExtension,
                imageIOUTTypeIdentifier: profile.imageIOUTTypeIdentifier,
                supportsCompressionQuality: profile.supportsCompressionQuality,
                supportsAnimation: profile.supportsAnimation,
                supportsPNGCompressionLevel: profile.supportsPNGCompressionLevel,
                ffmpegEncoderCandidates: profile.ffmpegEncoderCandidates,
                ffmpegRequiredMuxers: profile.ffmpegRequiredMuxers,
                preferredFFmpegMuxer: profile.preferredFFmpegMuxer,
                allowsFFmpegAutomaticCodec: profile.allowsFFmpegAutomaticCodec
            )
        }
    }

    nonisolated static func deduplicatedAndSorted(_ formats: [ImageFormatOption]) -> [ImageFormatOption] {
        var byID: [String: ImageFormatOption] = [:]

        for format in formats {
            let key = format.normalizedID
            if let existing = byID[key] {
                byID[key] = existing.merged(with: format)
            } else {
                byID[key] = format
            }
        }

        return byID.values.sorted { lhs, rhs in
            lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
        }
    }

    nonisolated func merged(with other: ImageFormatOption) -> ImageFormatOption {
        ImageFormatOption(
            id: id,
            displayName: displayName.count >= other.displayName.count ? displayName : other.displayName,
            fileExtension: fileExtension,
            imageIOUTTypeIdentifier: imageIOUTTypeIdentifier ?? other.imageIOUTTypeIdentifier,
            supportsCompressionQuality: supportsCompressionQuality || other.supportsCompressionQuality,
            supportsAnimation: supportsAnimation || other.supportsAnimation,
            supportsPNGCompressionLevel: supportsPNGCompressionLevel || other.supportsPNGCompressionLevel,
            ffmpegEncoderCandidates: Self.uniqueStrings(ffmpegEncoderCandidates + other.ffmpegEncoderCandidates),
            ffmpegRequiredMuxers: Self.uniqueStrings(ffmpegRequiredMuxers + other.ffmpegRequiredMuxers),
            preferredFFmpegMuxer: preferredFFmpegMuxer ?? other.preferredFFmpegMuxer,
            allowsFFmpegAutomaticCodec: allowsFFmpegAutomaticCodec || other.allowsFFmpegAutomaticCodec
        )
    }

    nonisolated private static func uniqueStrings(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []

        for value in values {
            guard !value.isEmpty else { continue }
            if seen.insert(value).inserted {
                result.append(value)
            }
        }

        return result
    }

    nonisolated private static func prettifyIdentifier(_ identifier: String) -> String {
        let token = identifier
            .split(separator: ".")
            .last
            .map(String.init) ?? identifier

        return token
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .uppercased()
    }

    nonisolated private static func guessedFileExtension(from identifier: String) -> String {
        let token = identifier
            .split(separator: ".")
            .last
            .map(String.init) ?? "img"

        return normalizedFileExtension(token)
    }

    nonisolated private static func normalizedFileExtension(_ fileExtension: String) -> String {
        var normalized = fileExtension.lowercased()
        if normalized.hasPrefix(".") {
            normalized.removeFirst()
        }

        normalized = normalized
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "_", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return normalized
    }
}

private struct ImageFormatProfile {
    let id: String
    let displayName: String
    let fileExtension: String
    let imageIOUTTypeIdentifier: String?
    let supportsCompressionQuality: Bool
    let supportsAnimation: Bool
    let supportsPNGCompressionLevel: Bool
    let ffmpegEncoderCandidates: [String]
    let ffmpegRequiredMuxers: [String]
    let preferredFFmpegMuxer: String?
    let allowsFFmpegAutomaticCodec: Bool

    nonisolated static let byIdentifier: [String: ImageFormatProfile] = {
        var map: [String: ImageFormatProfile] = [:]

        func add(
            identifier: String,
            displayName: String,
            fileExtension: String,
            supportsCompressionQuality: Bool,
            supportsAnimation: Bool,
            supportsPNGCompressionLevel: Bool,
            ffmpegEncoderCandidates: [String],
            ffmpegRequiredMuxers: [String] = [],
            preferredFFmpegMuxer: String? = nil,
            allowsFFmpegAutomaticCodec: Bool = false
        ) {
            map[identifier.lowercased()] = ImageFormatProfile(
                id: identifier.lowercased(),
                displayName: displayName,
                fileExtension: fileExtension,
                imageIOUTTypeIdentifier: identifier,
                supportsCompressionQuality: supportsCompressionQuality,
                supportsAnimation: supportsAnimation,
                supportsPNGCompressionLevel: supportsPNGCompressionLevel,
                ffmpegEncoderCandidates: ffmpegEncoderCandidates,
                ffmpegRequiredMuxers: ffmpegRequiredMuxers,
                preferredFFmpegMuxer: preferredFFmpegMuxer,
                allowsFFmpegAutomaticCodec: allowsFFmpegAutomaticCodec
            )
        }

        add(
            identifier: "public.png",
            displayName: "PNG",
            fileExtension: "png",
            supportsCompressionQuality: false,
            supportsAnimation: false,
            supportsPNGCompressionLevel: true,
            ffmpegEncoderCandidates: ["png"]
        )
        add(
            identifier: "public.jpeg",
            displayName: "JPEG",
            fileExtension: "jpg",
            supportsCompressionQuality: true,
            supportsAnimation: false,
            supportsPNGCompressionLevel: false,
            ffmpegEncoderCandidates: ["mjpeg", "jpeg"]
        )
        add(
            identifier: "public.heic",
            displayName: "HEIC",
            fileExtension: "heic",
            supportsCompressionQuality: true,
            supportsAnimation: false,
            supportsPNGCompressionLevel: false,
            ffmpegEncoderCandidates: ["hevc_videotoolbox", "hevc", "libx265"],
            ffmpegRequiredMuxers: ["heif", "heic"],
            preferredFFmpegMuxer: "heif"
        )
        add(
            identifier: "com.compuserve.gif",
            displayName: "GIF",
            fileExtension: "gif",
            supportsCompressionQuality: false,
            supportsAnimation: true,
            supportsPNGCompressionLevel: false,
            ffmpegEncoderCandidates: ["gif"]
        )
        add(
            identifier: "public.jpeg-2000",
            displayName: "JPEG 2000",
            fileExtension: "jp2",
            supportsCompressionQuality: true,
            supportsAnimation: false,
            supportsPNGCompressionLevel: false,
            ffmpegEncoderCandidates: ["jpeg2000"]
        )
        add(
            identifier: "org.webmproject.webp",
            displayName: "WebP",
            fileExtension: "webp",
            supportsCompressionQuality: true,
            supportsAnimation: true,
            supportsPNGCompressionLevel: false,
            ffmpegEncoderCandidates: ["libwebp", "webp"],
            ffmpegRequiredMuxers: ["webp"],
            preferredFFmpegMuxer: "webp"
        )
        add(
            identifier: "public.avif",
            displayName: "AVIF",
            fileExtension: "avif",
            supportsCompressionQuality: true,
            supportsAnimation: false,
            supportsPNGCompressionLevel: false,
            ffmpegEncoderCandidates: ["libaom-av1", "svtav1", "rav1e", "av1"],
            ffmpegRequiredMuxers: ["avif"],
            preferredFFmpegMuxer: "avif"
        )
        add(
            identifier: "public.tiff",
            displayName: "TIFF",
            fileExtension: "tiff",
            supportsCompressionQuality: false,
            supportsAnimation: false,
            supportsPNGCompressionLevel: false,
            ffmpegEncoderCandidates: ["tiff"]
        )
        add(
            identifier: "com.microsoft.bmp",
            displayName: "BMP",
            fileExtension: "bmp",
            supportsCompressionQuality: false,
            supportsAnimation: false,
            supportsPNGCompressionLevel: false,
            ffmpegEncoderCandidates: ["bmp"]
        )

        return map
    }()

    nonisolated static let byFileExtension: [String: ImageFormatProfile] = {
        var map: [String: ImageFormatProfile] = [:]

        for profile in byIdentifier.values {
            let key = profile.fileExtension.lowercased()
            if map[key] == nil {
                map[key] = profile
            }

            if let identifier = profile.imageIOUTTypeIdentifier,
               let utType = UTType(identifier),
               let preferred = utType.preferredFilenameExtension?.lowercased(),
               map[preferred] == nil {
                map[preferred] = profile
            }
        }

        map["jpeg"] = map["jpeg"] ?? map["jpg"]
        map["tif"] = map["tif"] ?? map["tiff"]
        map["heif"] = map["heif"] ?? map["heic"]
        map["j2k"] = map["j2k"] ?? map["jp2"]

        return map
    }()

    nonisolated static let ffmpegOnlyProfiles: [ImageFormatProfile] = {
        [
            byIdentifier["org.webmproject.webp"],
            byIdentifier["public.avif"],
            byIdentifier["public.heic"]
        ].compactMap { $0 }
    }()
}

enum ImageQualityOption: String, CaseIterable, Identifiable {
    case best = "Best (100%)"
    case high = "High (90%)"
    case medium = "Medium (75%)"
    case low = "Low (60%)"

    nonisolated var id: String { rawValue }

    nonisolated var compressionQuality: Double {
        switch self {
        case .best:
            return 1.0
        case .high:
            return 0.9
        case .medium:
            return 0.75
        case .low:
            return 0.6
        }
    }

    nonisolated var percent: Int {
        Int((compressionQuality * 100).rounded())
    }

    nonisolated static func ffmpegQScale(fromPercent percent: Int) -> Int {
        let clamped = max(1, min(percent, 100))
        return max(2, min(31, 32 - Int((Double(clamped) / 100.0) * 30.0)))
    }

    nonisolated static func ffmpegCRF(fromPercent percent: Int) -> Int {
        let clamped = max(1, min(percent, 100))
        return max(0, min(50, 51 - Int((Double(clamped) / 100.0) * 50.0)))
    }
}

enum PNGCompressionLevelOption: String, CaseIterable, Identifiable {
    case fastest = "Fastest (1)"
    case balanced = "Balanced (6)"
    case smallest = "Smallest File (9)"

    nonisolated var id: String { rawValue }

    nonisolated var level: Int {
        switch self {
        case .fastest:
            return 1
        case .balanced:
            return 6
        case .smallest:
            return 9
        }
    }
}
