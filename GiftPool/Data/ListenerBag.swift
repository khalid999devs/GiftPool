import Foundation
import FirebaseFirestore

// Keeps the Firestore listeners a view model has started, grouped by a key (usually a pool id).
// When the view model goes away, the bag goes too and every listener is removed.
class ListenerBag {
    private var listeners: [String: [ListenerRegistration]] = [:]

    var isEmpty: Bool {
        listeners.isEmpty
    }

    func add(_ listener: ListenerRegistration, key: String = "main") {
        listeners[key, default: []].append(listener)
    }

    func replace(_ listener: ListenerRegistration, key: String) {
        remove(key: key)
        add(listener, key: key)
    }

    func remove(key: String) {
        for listener in listeners[key] ?? [] {
            listener.remove()
        }
        listeners[key] = nil
    }

    deinit {
        for group in listeners.values {
            for listener in group {
                listener.remove()
            }
        }
    }
}
