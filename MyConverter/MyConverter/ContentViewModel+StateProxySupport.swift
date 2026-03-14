import Foundation

extension ContentViewModel {
    struct StateProxyDescriptor<State> {
        let stateKeyPath: ReferenceWritableKeyPath<ContentViewModel, State>
    }

    func updateState<State: Equatable>(
        _ stateKeyPath: ReferenceWritableKeyPath<ContentViewModel, State>,
        mutate: (inout State) -> Void,
        after updateAction: () -> Void = {}
    ) {
        var state = self[keyPath: stateKeyPath]
        let original = state
        mutate(&state)
        guard state != original else { return }
        self[keyPath: stateKeyPath] = state
        updateAction()
    }

    func updateState<State, Value: Equatable>(
        _ stateKeyPath: ReferenceWritableKeyPath<ContentViewModel, State>,
        value valueKeyPath: WritableKeyPath<State, Value>,
        to newValue: Value,
        after updateAction: () -> Void = {}
    ) {
        var state = self[keyPath: stateKeyPath]
        guard state[keyPath: valueKeyPath] != newValue else { return }
        state[keyPath: valueKeyPath] = newValue
        self[keyPath: stateKeyPath] = state
        updateAction()
    }

    func stateValue<State, Value>(
        using descriptor: StateProxyDescriptor<State>,
        at valueKeyPath: KeyPath<State, Value>
    ) -> Value {
        self[keyPath: descriptor.stateKeyPath][keyPath: valueKeyPath]
    }

    func updateState<State, Value>(
        _ stateKeyPath: ReferenceWritableKeyPath<ContentViewModel, State>,
        value valueKeyPath: WritableKeyPath<State, Value>,
        to newValue: Value,
        after updateAction: () -> Void = {}
    ) {
        var state = self[keyPath: stateKeyPath]
        state[keyPath: valueKeyPath] = newValue
        self[keyPath: stateKeyPath] = state
        updateAction()
    }

    func updateState<State, Value: Equatable>(
        using descriptor: StateProxyDescriptor<State>,
        value valueKeyPath: WritableKeyPath<State, Value>,
        to newValue: Value,
        after updateAction: () -> Void = {}
    ) {
        updateState(descriptor.stateKeyPath, value: valueKeyPath, to: newValue, after: updateAction)
    }

    func updateState<State, Value>(
        using descriptor: StateProxyDescriptor<State>,
        value valueKeyPath: WritableKeyPath<State, Value>,
        to newValue: Value,
        after updateAction: () -> Void = {}
    ) {
        updateState(descriptor.stateKeyPath, value: valueKeyPath, to: newValue, after: updateAction)
    }

    func updateState<State: Equatable>(
        using descriptor: StateProxyDescriptor<State>,
        mutate: (inout State) -> Void,
        after updateAction: () -> Void = {}
    ) {
        updateState(descriptor.stateKeyPath, mutate: mutate, after: updateAction)
    }
}
