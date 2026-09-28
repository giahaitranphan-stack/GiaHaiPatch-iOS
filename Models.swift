import Foundation

struct PatchManifest: Codable {
    var format: String = "3105"
    var version: Int = 1
    var name: String
    var targets: [String]
    var createdAt: Date = Date()
    var encrypted: Bool = false
}

struct PatchItem: Identifiable, Hashable {
    let id = UUID()
    let url: URL
    var relativePath: String
    var isDirectory: Bool
}
