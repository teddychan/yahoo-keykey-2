import Foundation

/// A reference-counted, lazily-built holder for a heavy value.
///
/// The value is built by `build` on the first `acquire()` (count 0 → 1) and the
/// strong reference is dropped when the count returns to 0, so the value is
/// resident ONLY while at least one holder has acquired it. Used for the Pinyin
/// language-model index: registering an input method is cheap; only *selecting*
/// Pinyin acquires (and thus builds) the index, and leaving it releases.
///
/// Thread-safe: every operation is guarded by an NSLock. `T` may be a value or
/// reference type; the holder keeps exactly one instance alive across concurrent
/// acquirers.
public final class RefCountedResource<T> {
    private let build: () -> T
    private var value: T?
    private var count = 0
    private let lock = NSLock()

    public init(build: @escaping () -> T) { self.build = build }

    /// Increment the count; build the value on the 0 → 1 transition. Returns the shared value.
    @discardableResult
    public func acquire() -> T {
        lock.lock(); defer { lock.unlock() }
        count += 1
        if let value { return value }
        let built = build()
        value = built
        return built
    }

    /// Decrement the count (never below 0); drop the strong reference at 0.
    public func release() {
        lock.lock(); defer { lock.unlock() }
        guard count > 0 else { return }
        count -= 1
        if count == 0 { value = nil }
    }

    /// The currently-resident value, or nil when nothing holds it. Does not build.
    public var current: T? {
        lock.lock(); defer { lock.unlock() }
        return value
    }

    /// True while the value is resident (count > 0). Does not build.
    public var isLoaded: Bool {
        lock.lock(); defer { lock.unlock() }
        return value != nil
    }
}
