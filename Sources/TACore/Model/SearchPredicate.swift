public enum SearchPredicate: Sendable, Equatable {
    case tag(String)
    case phrase(String)
    case word(String)
}

extension SearchPredicate: CustomStringConvertible {
    public var description: String {
        switch self {
        case .tag(let t): return "tag(\(t))"
        case .phrase(let p): return "phrase(\(p))"
        case .word(let w): return "word(\(w))"
        }
    }
}
