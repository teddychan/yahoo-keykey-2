// Identity of ONE candidate list, and one candidate's usage within it.
//
// Adaptive ordering counts how often each candidate is committed *in its own list*, so the
// identity of that list is what the counts hang off. It is an enum with associated values
// rather than a joined string on purpose: the cases carry different fields (an association
// list is keyed by a trigger character with no table version or code), and Swift's structural
// equality makes two different lists unable to collide the way `"cangjie:5:a"` can be reached
// from more than one set of components. Nothing here is ever concatenated to form a key.
//
// The table version is part of the identity wherever there is one, because 三代 and 五代 hand
// the same code different characters — the same `a` is a different list in each.
//
// There is deliberately NO case for 拼音. Its candidate ranking is out of scope for this change
// and keeps working exactly as it did, off the retired per-character store (see UserFrequency);
// adding a case here is what would quietly pull it in.
public enum CandidateListKey: Hashable, Sendable {
    /// A finished 倉頡 code, e.g. `("5", "ojmn")`. Only the exact code's own list.
    case cangjie(tableVersion: String, code: String)
    /// A 倉頡 code containing the `*` wildcard, keyed by the pattern the user actually typed
    /// (`h*i` for 竹*戈). The pattern is the list: `h*i` and `h*e` match different characters,
    /// and neither is the exact-code list for `hi`.
    case cangjieWildcard(tableVersion: String, pattern: String)
    /// A 速成 code — one or two radicals, e.g. `("5", "a")` for 日/曰.
    case simplex(tableVersion: String, code: String)
    /// A 注音 (ㄅ半) reading — one finished syllable including its tone, e.g. `ㄕˋ`. The reading
    /// is the list, and it carries no keyboard layout: 大千 and 倚天 are two ways to type the same
    /// ㄕˋ and must share what they learn about it, exactly as they share the character table.
    case zhuyin(reading: String)
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
        case .zhuyin: return "zhuyin"
        case .association: return "association"
        }
    }

    var tableVersionField: String? {
        switch self {
        case .cangjie(let v, _), .cangjieWildcard(let v, _), .simplex(let v, _): return v
        // 注音 has no table version to carry: one ㄅ半 table ships, and the layout is not part of
        // the list identity (see the case above).
        case .zhuyin, .association: return nil
        }
    }

    var codeField: String? {
        switch self {
        case .cangjie(_, let c), .cangjieWildcard(_, let c), .simplex(_, let c): return c
        case .zhuyin(let reading): return reading
        case .association: return nil
        }
    }

    var triggerField: String? {
        switch self {
        case .association(let t): return String(t)
        case .cangjie, .cangjieWildcard, .simplex, .zhuyin: return nil
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
        case "zhuyin":
            // No tableVersion required, and none accepted into the identity: a record written by
            // a build that stored one still rebuilds as the same reading's list.
            guard let code, !code.isEmpty else { return nil }
            return .zhuyin(reading: code)
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
