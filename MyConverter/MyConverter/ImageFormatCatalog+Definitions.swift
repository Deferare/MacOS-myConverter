import Foundation

extension ImageFormatCatalog {
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
}
