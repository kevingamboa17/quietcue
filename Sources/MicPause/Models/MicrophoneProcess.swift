import Foundation

struct MicrophoneProcess: Hashable, Sendable, Identifiable {
    let pid: Int32
    let bundleIdentifier: String?
    let name: String

    var id: Int32 { pid }
}
