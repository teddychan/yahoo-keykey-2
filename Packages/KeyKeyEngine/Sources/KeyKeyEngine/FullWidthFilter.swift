// Converts ASCII printable characters to their Unicode full-width forms.
// Used for CJK typography. Pure and stateless.
public enum FullWidthFilter {
    public static func convert(_ s: String) -> String {
        var out = ""
        out.reserveCapacity(s.count)
        for scalar in s.unicodeScalars {
            switch scalar.value {
            case 0x20:                    // ASCII space -> IDEOGRAPHIC SPACE
                out.append("\u{3000}")
            case 0x21...0x7E:             // ASCII printable -> full-width
                // 0x21..0x7E + 0xFEE0 = 0xFF01..0xFF5E is always a valid scalar.
                if let full = Unicode.Scalar(scalar.value + 0xFEE0) {
                    out.unicodeScalars.append(full)
                }
            default:
                out.unicodeScalars.append(scalar)
            }
        }
        return out
    }
}
