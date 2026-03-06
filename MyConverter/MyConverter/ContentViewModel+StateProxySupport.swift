import Foundation

extension ContentViewModel {
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
        in stateKeyPath: KeyPath<ContentViewModel, State>,
        at valueKeyPath: KeyPath<State, Value>
    ) -> Value {
        self[keyPath: stateKeyPath][keyPath: valueKeyPath]
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
}
