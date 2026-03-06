import Foundation

extension ContentViewModel {
    func makeScheduledMainActorTask(
        delayNanoseconds: UInt64?,
        action: @escaping @MainActor (ContentViewModel) -> Void
    ) -> Task<Void, Never> {
        Task { @MainActor [weak self] in
            if let delayNanoseconds {
                do {
                    try await Task.sleep(nanoseconds: delayNanoseconds)
                } catch {
                    return
                }
            } else {
                await Task.yield()
            }

            guard !Task.isCancelled, let self else { return }
            action(self)
        }
    }

    func replaceScheduledTask(
        _ taskKeyPath: ReferenceWritableKeyPath<ContentViewModel, Task<Void, Never>?>,
        delayNanoseconds: UInt64?,
        action: @escaping @MainActor (ContentViewModel) -> Void
    ) {
        self[keyPath: taskKeyPath]?.cancel()
        self[keyPath: taskKeyPath] = makeScheduledMainActorTask(
            delayNanoseconds: delayNanoseconds,
            action: action
        )
    }

    func scheduleDeferredTask(
        _ taskKeyPath: ReferenceWritableKeyPath<ContentViewModel, Task<Void, Never>?>,
        action: @escaping @MainActor (ContentViewModel) -> Void
    ) {
        replaceScheduledTask(taskKeyPath, delayNanoseconds: nil, action: action)
    }

    func scheduleDebouncedTask(
        _ taskKeyPath: ReferenceWritableKeyPath<ContentViewModel, Task<Void, Never>?>,
        delayNanoseconds: UInt64 = 250_000_000,
        action: @escaping @MainActor (ContentViewModel) -> Void
    ) {
        replaceScheduledTask(taskKeyPath, delayNanoseconds: delayNanoseconds, action: action)
    }
}
