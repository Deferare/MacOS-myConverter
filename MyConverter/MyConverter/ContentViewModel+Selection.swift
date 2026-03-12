import Combine
import Foundation

extension ContentViewModel {
    func assignSelection(_ urls: [URL], for kind: MediaKind) {
        objectWillChange.send()
        synchronizeSourceSecurityScope(for: urls, kind: kind)
        let descriptor = mediaStateDescriptor(for: kind)
        assignPrimaryAndQueuedSources(
            urls,
            primaryKeyPath: descriptor.sourceURL,
            queuedKeyPath: descriptor.queuedSourceURLs
        )
        #if os(iOS)
        let snapshot = mediaStateSnapshot(for: kind)
        let renderState = converterRenderState(for: kind)
        print(
            "[Selection] kind=\(kind.rawValue) sourceURL=\(snapshot.sourceURL?.lastPathComponent ?? "nil") queued=\(snapshot.queuedSourceURLs.count) selectedFileCount=\(renderState.screenState.selectedFileCount) showsSettings=\(renderState.screenState.showsSettings) canConvert=\(renderState.screenState.canConvert) status=\(renderState.inputHeaderState.statusMessage)"
        )
        #endif
    }
}
