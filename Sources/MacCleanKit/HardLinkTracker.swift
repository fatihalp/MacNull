import Foundation

public struct HardLinkTracker: Sendable {
    public struct Identity: Hashable, Sendable {
        public let device: UInt64
        public let inode: UInt64

        public init(device: UInt64, inode: UInt64) {
            self.device = device
            self.inode = inode
        }
    }

    private var seen: Set<Identity> = []

    public init() {}

    public mutating func firstSighting(of identity: Identity) -> Bool {
        seen.insert(identity).inserted
    }

    public mutating func shouldCount(_ url: URL, linkCount: Int?) -> Bool {
        guard let linkCount, linkCount > 1 else { return true }
        var info = stat()
        guard lstat(url.path(percentEncoded: false), &info) == 0,
              info.st_mode & S_IFMT != S_IFDIR else { return true }
        return firstSighting(of: Identity(device: UInt64(UInt32(bitPattern: info.st_dev)),
                                          inode: UInt64(info.st_ino)))
    }
}
