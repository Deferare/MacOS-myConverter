#if os(macOS)
import AppKit
import Foundation

@MainActor
final class MacOutputDestinationCoordinator: OutputDestinationCoordinator {
    static let shared = MacOutputDestinationCoordinator()

    private init() {}

    func chooseOutputDestination(
        suggestedDirectory: URL,
        outputLabel: String,
        fileCount: Int
    ) async -> OutputDestinationHandle? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.directoryURL = suggestedDirectory
        panel.prompt = "Choose Folder"
        panel.title = "Choose Output Folder"
        panel.message = fileCount > 1
            ? "Select the folder where converted \(outputLabel.lowercased()) files will be saved. Converted outputs are saved only to this folder using the original file names."
            : "Select the folder where the converted \(outputLabel.lowercased()) file will be saved. The converted file is saved to this folder using the original file name."

        guard panel.runModal() == .OK, let url = panel.url else {
            return nil
        }

        return OutputDestinationHandle(url: url)
    }
}
#endif
