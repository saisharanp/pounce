import Foundation

/// Persists the pet state entirely on-device in UserDefaults.
public final class PetStateStore {
    private let defaults: UserDefaults
    private let key = "pet-state"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func load() -> PetState {
        guard let data = defaults.data(forKey: key),
              let state = try? JSONDecoder().decode(PetState.self, from: data) else {
            return PetState()
        }

        return state
    }

    public func save(_ state: PetState) {
        guard let data = try? JSONEncoder().encode(state) else {
            return
        }

        defaults.set(data, forKey: key)
    }
}
