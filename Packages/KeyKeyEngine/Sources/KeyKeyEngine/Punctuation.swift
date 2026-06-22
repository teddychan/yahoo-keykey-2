// Maps an ASCII punctuation key to its Traditional-Chinese full-width form.
// Used by Cangjie/Simplex modes. Pure and stateless.
public enum Punctuation {
    private static let table: [Character: String] = [
        ",": "，",   // FULLWIDTH COMMA (U+FF0C)
        ".": "。",   // IDEOGRAPHIC FULL STOP (U+3002)
        ";": "；",   // FULLWIDTH SEMICOLON (U+FF1B)
        ":": "：",   // FULLWIDTH COLON (U+FF1A)
        "?": "？",   // FULLWIDTH QUESTION MARK (U+FF1F)
        "!": "！",   // FULLWIDTH EXCLAMATION MARK (U+FF01)
        "\\": "、",  // IDEOGRAPHIC COMMA (U+3001)
        "`": "、",   // IDEOGRAPHIC COMMA (U+3001)
        "'": "’",    // RIGHT SINGLE QUOTATION MARK (U+2019)
        "\"": "”",   // RIGHT DOUBLE QUOTATION MARK (U+201D)
        "(": "（",   // FULLWIDTH LEFT PARENTHESIS (U+FF08)
        ")": "）",   // FULLWIDTH RIGHT PARENTHESIS (U+FF09)
        "[": "「",   // LEFT CORNER BRACKET (U+300C)
        "]": "」",   // RIGHT CORNER BRACKET (U+300D)
        "{": "『",   // LEFT WHITE CORNER BRACKET (U+300E)
        "}": "』",   // RIGHT WHITE CORNER BRACKET (U+300F)
        "<": "《",   // LEFT DOUBLE ANGLE BRACKET (U+300A)
        ">": "》",   // RIGHT DOUBLE ANGLE BRACKET (U+300B)
        "~": "～",   // FULLWIDTH TILDE (U+FF5E)
        "@": "＠",   // FULLWIDTH COMMERCIAL AT (U+FF20)
        "#": "＃",   // FULLWIDTH NUMBER SIGN (U+FF03)
        "$": "＄",   // FULLWIDTH DOLLAR SIGN (U+FF04)
        "%": "％",   // FULLWIDTH PERCENT SIGN (U+FF05)
        "^": "＾",   // FULLWIDTH CIRCUMFLEX ACCENT (U+FF3E)
        "&": "＆",   // FULLWIDTH AMPERSAND (U+FF06)
        "*": "＊",   // FULLWIDTH ASTERISK (U+FF0A)
        "-": "－",   // FULLWIDTH HYPHEN-MINUS (U+FF0D)
        "_": "＿",   // FULLWIDTH LOW LINE (U+FF3F)
        "+": "＋",   // FULLWIDTH PLUS SIGN (U+FF0B)
        "=": "＝",   // FULLWIDTH EQUALS SIGN (U+FF1D)
        "/": "／",   // FULLWIDTH SOLIDUS (U+FF0F)
        "|": "｜",   // FULLWIDTH VERTICAL LINE (U+FF5C)
    ]

    /// Returns the Traditional-Chinese full-width punctuation for an ASCII key,
    /// or nil if the key is not a mapped punctuation.
    public static func fullWidth(for key: Character) -> String? {
        return table[key]
    }
}
