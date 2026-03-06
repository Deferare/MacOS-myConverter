import Foundation

extension ContentViewModel {
    func videoRuntimeValue<Value>(_ keyPath: KeyPath<VideoRuntimeState, Value>) -> Value {
        videoRuntimeState[keyPath: keyPath]
    }

    func updateVideoRuntime<Value>(
        _ keyPath: WritableKeyPath<VideoRuntimeState, Value>,
        to newValue: Value,
        after updateAction: () -> Void = {}
    ) {
        videoRuntimeState[keyPath: keyPath] = newValue
        updateAction()
    }

    func imageRuntimeValue<Value>(_ keyPath: KeyPath<ImageRuntimeState, Value>) -> Value {
        imageRuntimeState[keyPath: keyPath]
    }

    func updateImageRuntime<Value>(
        _ keyPath: WritableKeyPath<ImageRuntimeState, Value>,
        to newValue: Value,
        after updateAction: () -> Void = {}
    ) {
        imageRuntimeState[keyPath: keyPath] = newValue
        updateAction()
    }

    func audioRuntimeValue<Value>(_ keyPath: KeyPath<AudioRuntimeState, Value>) -> Value {
        audioRuntimeState[keyPath: keyPath]
    }

    func updateAudioRuntime<Value>(
        _ keyPath: WritableKeyPath<AudioRuntimeState, Value>,
        to newValue: Value,
        after updateAction: () -> Void = {}
    ) {
        audioRuntimeState[keyPath: keyPath] = newValue
        updateAction()
    }

    func videoOptionsValue<Value>(_ keyPath: KeyPath<VideoOptionsState, Value>) -> Value {
        videoOptionsState[keyPath: keyPath]
    }

    func updateVideoOptions<Value>(
        _ keyPath: WritableKeyPath<VideoOptionsState, Value>,
        to newValue: Value,
        after updateAction: () -> Void = {}
    ) {
        videoOptionsState[keyPath: keyPath] = newValue
        updateAction()
    }

    func imageOptionsValue<Value>(_ keyPath: KeyPath<ImageOptionsState, Value>) -> Value {
        imageOptionsState[keyPath: keyPath]
    }

    func updateImageOptions<Value>(
        _ keyPath: WritableKeyPath<ImageOptionsState, Value>,
        to newValue: Value,
        after updateAction: () -> Void = {}
    ) {
        imageOptionsState[keyPath: keyPath] = newValue
        updateAction()
    }

    func audioOptionsValue<Value>(_ keyPath: KeyPath<AudioOptionsState, Value>) -> Value {
        audioOptionsState[keyPath: keyPath]
    }

    func updateAudioOptions<Value>(
        _ keyPath: WritableKeyPath<AudioOptionsState, Value>,
        to newValue: Value,
        after updateAction: () -> Void = {}
    ) {
        audioOptionsState[keyPath: keyPath] = newValue
        updateAction()
    }
}
