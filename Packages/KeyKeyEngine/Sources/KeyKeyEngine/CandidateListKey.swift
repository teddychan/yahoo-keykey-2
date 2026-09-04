// Identity of ONE candidate list, and one candidate's usage within it.
//
// Adaptive ordering counts how often each candidate is committed *in its own list*, so the
// identity of that list is what the counts hang off. It is an enum with associated values
// rather than a joined string on purpose: the cases carry different fields (an association
// list has no table version, a 拼音 list has neither table nor code), and Swift's structural
// equality makes two different lists unable to collide the way `"cangjie:5:a"` can be reached
// from more than one set of components. Nothing here is ever concatenated to form a key.
//
// The table version is part of the identity wherever there is one, because 三代 and 五代 hand
// the same code different characters — the same `a` is a different list in each.
public enum CandidateListKey: Hashable, Sendable {
    /// A finished 倉頡 code, e.g. `("5", "ojmn")`. Only the exact code's own list.
    case cangjie(tableVersion: String, code: String)
    /// A 倉頡 code containing the `*` wildcard, keyed by the pattern the user actually typed
    /// (`h*i` for 竹*戈). The pattern is the list: `h*i` and `h*e` match different characters,
    /// and neither is the exact-code list for `hi`.
    case cangjieWildcard(tableVersion: String, pattern: String)
    /// A 速成 code — one or two radicals, e.g. `("5", "a")` for 日/曰.
    case simplex(tableVersion: String, code: String)
    /// One node of a 拼音 composition, keyed by the reading key the language model itself
    /// indexes that node's candidates under (`ㄋㄧ-ㄏㄠ`). That key IS the list: two nodes with
    /// the same reading key are handed the same candidates, and no other key reaches them.
    case pinyin(readingKey: String)
    /// A 聯想字詞 list, keyed by the character that triggered it. Deliberately carries neither
    /// the input mode nor the code that produced the trigger: 倉頡 and 速成 show the same
    /// semantic list after the same character, so they must share one set of counts.
    case association(trigger: Character)
}

// Field projection, used by CandidateUsageStore for persistence and for deterministic
// eviction order. These are NOT identity — the enum above is — which is why they are
// internal and why nothing reconstructs a key by parsing them back out of one string.
extension CandidateListKey {
    var scopeName: String {
        switch self {
        case .cangjie: return "cangjie"
        case .cangjieWildcard: return "cangjieWildcard"
        case .simplex: return "simplex"
        case .pinyin: return "pinyin"
        case .association: return "association"
        }
    }

    var tableVersionField: String? {
        switch self {
        case .cangjie(let v, _), .cangjieWildcard(let v, _), .simplex(let v, _): return v
        case .pinyin, .association: return nil
        }
    }

    var codeField: String? {
        switch self {
        case .cangjie(_, let c), .cangjieWildcard(_, let c), .simplex(_, let c): return c
        case .pinyin(let k): return k
        case .association: return nil
        }
    }

    var triggerField: String? {
        switch self {
        case .association(let t): return String(t)
        case .cangjie, .cangjieWildcard, .simplex, .pinyin: return nil
        }
    }

    /// Rebuild a key from persisted fields, or nil when they do not describe one — an unknown
    /// scope, or a scope missing a field it requires. Returning nil (rather than substituting a
    /// default) is what keeps a malformed record from being loaded as some *other* list's counts.
    static func make(scope: String, tableVersion: String?, code: String?, trigger: String?) -> CandidateListKey? {
        switch scope {
        case "cangjie":
            guard let tableVersion, let code else { return nil }
            return .cangjie(tableVersion: tableVersion, code: code)
        case "cangjieWildcard":
            guard let tableVersion, let code else { return nil }
            return .cangjieWildcard(tableVersion: tableVersion, pattern: code)
        case "simplex":
            guard let tableVersion, let code else { return nil }
            return .simplex(tableVersion: tableVersion, code: code)
        case "pinyin":
            guard let code else { return nil }
            return .pinyin(readingKey: code)
        case "association":
            guard let trigger, trigger.count == 1, let ch = trigger.first else { return nil }
            return .association(trigger: ch)
        default:
            return nil
        }
    }
}

/// One candidate to credit in one list. Produced by an engine BEFORE it commits (the commit
/// clears the code that identifies the list), and handed to `CandidateUsageStore.record`.
public struct CandidateUsage: Equatable, Sendable {
    public let list: CandidateListKey
    public let candidate: String
    public init(list: CandidateListKey, candidate: String) {
        self.list = list
        self.candidate = candidate
    }
}
