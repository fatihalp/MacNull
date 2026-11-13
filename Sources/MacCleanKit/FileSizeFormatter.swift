import Foundation

public enum FileSizeFormatter {
    public static func format(_ bytes: some BinaryInteger) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }
}
