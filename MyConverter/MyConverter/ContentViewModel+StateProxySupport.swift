import Foundation

extension ContentViewModel {
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
}
