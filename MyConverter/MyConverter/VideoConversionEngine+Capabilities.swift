import Foundation

extension VideoConversionEngine {
    nonisolated static func cachedCapabilityValue<Value>(
        readCached: () -> Value?,
        storeCached: (Value) -> Void,
        build: () -> Value
    ) -> Value {
        if let cached = readCached() {
            return cached
        }

        let resolved = build()
        storeCached(resolved)
        return resolved
    }

    nonisolated static func availableEncoderOptions<Option: CaseIterable & Equatable>(
        availableEncoders: Set<String>,
        allowsAutomatic: Bool,
        automaticOption: Option,
        isCompatible: (Option) -> Bool,
        codecCandidates: (Option) -> [String]
    ) -> [Option] {
        let explicitOptions = Array(Option.allCases).filter { option in
            guard option != automaticOption else { return false }
            return isCompatible(option) &&
                codecCandidates(option).contains(where: availableEncoders.contains)
        }

        return resolvedEncoderOptions(
            explicitOptions: explicitOptions,
            allowsAutomatic: allowsAutomatic,
            automaticOption: automaticOption
        )
    }

    nonisolated static func resolvedEncoderOptions<Option: Equatable>(
        explicitOptions: [Option],
        allowsAutomatic: Bool,
        automaticOption: Option
    ) -> [Option] {
        guard allowsAutomatic, !explicitOptions.isEmpty else {
            return explicitOptions
        }
        return [automaticOption] + explicitOptions
    }

    nonisolated static func makeCapabilityCacheKey(path: String, normalizedID: String) -> String {
        "\(path)|\(normalizedID)"
    }
}
