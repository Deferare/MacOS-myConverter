import Foundation

extension ContentViewModel {
    func makeDeferredMainActorTask(
        action: @escaping @MainActor (ContentViewModel) -> Void
    ) -> Task<Void, Never> {
        Task { @MainActor [weak self] in
            await Task.yield()
            guard !Task.isCancelled, let self else { return }
            action(self)
        }
    }

    func makeDebouncedMainActorTask(
        delayNanoseconds: UInt64 = 250_000_000,
        action: @escaping @MainActor (ContentViewModel) -> Void
    ) -> Task<Void, Never> {
        Task { @MainActor [weak self] in
            do {
                try await Task.sleep(nanoseconds: delayNanoseconds)
            } catch {
                return
            }
            guard !Task.isCancelled, let self else { return }
            action(self)
        }
    }

    func scheduleDeferredTask(
        _ taskKeyPath: ReferenceWritableKeyPath<ContentViewModel, Task<Void, Never>?>,
        action: @escaping @MainActor (ContentViewModel) -> Void
    ) {
        self[keyPath: taskKeyPath]?.cancel()
        self[keyPath: taskKeyPath] = makeDeferredMainActorTask(action: action)
    }

    func scheduleDebouncedTask(
        _ taskKeyPath: ReferenceWritableKeyPath<ContentViewModel, Task<Void, Never>?>,
        delayNanoseconds: UInt64 = 250_000_000,
        action: @escaping @MainActor (ContentViewModel) -> Void
    ) {
        self[keyPath: taskKeyPath]?.cancel()
        self[keyPath: taskKeyPath] = makeDebouncedMainActorTask(
            delayNanoseconds: delayNanoseconds,
            action: action
        )
    }
}
