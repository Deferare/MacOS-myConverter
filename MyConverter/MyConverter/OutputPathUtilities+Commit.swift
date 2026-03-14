import Foundation

extension OutputPathUtilities {
    nonisolated static func prepareWorkingOutput(
        for sourceURL: URL,
        destinationURL: URL
    ) -> PreparedWorkingOutput {
        #if os(iOS)
        return PreparedWorkingOutput(
            url: temporaryOutputURL(
                for: sourceURL,
                fileExtension: destinationURL.pathExtension
            ),
            strategy: .workingDirectoryFallback
        )
        #else
        if let destinationAdjacent = destinationAdjacentTemporaryOutputURL(for: destinationURL) {
            return PreparedWorkingOutput(
                url: destinationAdjacent,
                strategy: .destinationAdjacent
            )
        }

        return PreparedWorkingOutput(
            url: temporaryOutputURL(
                for: sourceURL,
                fileExtension: destinationURL.pathExtension
            ),
            strategy: .workingDirectoryFallback
        )
        #endif
    }

    nonisolated static func commitPreparedOutput(
        from sourceURL: URL,
        to destinationURL: URL,
        strategy: WorkingOutputStrategy
    ) throws -> URL {
        let token = PerformanceSignpost.begin("FinalizeOutput", message: destinationURL.lastPathComponent)
        defer {
            PerformanceSignpost.end("FinalizeOutput", token: token, message: destinationURL.lastPathComponent)
        }

        let usesDestinationAdjacentRename =
            strategy == .destinationAdjacent &&
            sourceURL.deletingLastPathComponent().standardizedFileURL ==
            destinationURL.deletingLastPathComponent().standardizedFileURL

        if usesDestinationAdjacentRename {
            return try commitDestinationAdjacentOutput(
                from: sourceURL,
                to: destinationURL
            )
        }

        return try saveConvertedOutput(from: sourceURL, to: destinationURL)
    }

    nonisolated static func destinationAdjacentTemporaryOutputURL(
        for destinationURL: URL
    ) -> URL? {
        let outputDirectoryURL = destinationURL.deletingLastPathComponent()
        guard ensureDirectoryExists(outputDirectoryURL) else {
            return nil
        }

        let tempURL = outputDirectoryURL.appendingPathComponent(
            hiddenWorkingFilename(for: destinationURL)
        )

        do {
            let created = FileManager.default.createFile(
                atPath: tempURL.path,
                contents: Data(),
                attributes: nil
            )
            guard created else {
                return nil
            }
            try removeFileIfExists(at: tempURL)
            return tempURL
        } catch {
            try? removeFileIfExists(at: tempURL)
            return nil
        }
    }

    nonisolated static func commitDestinationAdjacentOutput(
        from sourceURL: URL,
        to destinationURL: URL
    ) throws -> URL {
        let fileManager = FileManager.default
        let originalExists = fileManager.fileExists(atPath: destinationURL.path)

        if originalExists {
            do {
                let replaced = try fileManager.replaceItemAt(
                    destinationURL,
                    withItemAt: sourceURL,
                    backupItemName: nil,
                    options: [.usingNewMetadataOnly]
                )
                return replaced ?? destinationURL
            } catch {
                throw saveOutputError(at: destinationURL, error)
            }
        }

        do {
            return try moveItemOrCopyFallback(
                from: sourceURL,
                to: destinationURL,
                using: fileManager
            )
        } catch {
            throw saveOutputError(at: destinationURL, error)
        }
    }
}
