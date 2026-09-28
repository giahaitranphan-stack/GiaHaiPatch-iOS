import Foundation
import SwiftUI
import UniformTypeIdentifiers
import ZIPFoundation
import CryptoKit
import Security

@MainActor
final class PatchStore: ObservableObject {
    @Published var workspaceURL: URL?
    @Published var manifest: PatchManifest?
    @Published var items: [PatchItem] = []
    @Published var status = "Sẵn sàng"
    @Published var showingImporter = false
    @Published var showingExporter = false
    @Published var showingImportPassword = false
    @Published var pendingImportURL: URL?

    private let fm = FileManager.default

    func newPatch(name: String, bundleID: String) {
        let base = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent(name, isDirectory: true)
            .appendingPathComponent(bundleID, isDirectory: true)
        do {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
            workspaceURL = dir
            manifest = PatchManifest(name: name, targets: [bundleID])
            try writeManifest()
            refresh()
            status = "Đã tạo patch"
        } catch {
            status = "Lỗi: \(error.localizedDescription)"
        }
    }

    func importPatch(from url: URL, password: String? = nil) {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        do {
            let temp = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try fm.createDirectory(at: temp, withIntermediateDirectories: true)

            let data = try Data(contentsOf: url)
            let archiveData: Data
            if data.starts(with: Data("GHP1".utf8)) {
                guard let password else {
                    pendingImportURL = url
                    showingImportPassword = true
                    status = "Gói được bảo vệ bằng mật khẩu"
                    return
                }
                archiveData = try CryptoBox.decrypt(data, password: password)
            } else {
                archiveData = data
            }

            let zipURL = temp.appendingPathComponent("package.zip")
            try archiveData.write(to: zipURL)
            try fm.unzipItem(at: zipURL, to: temp.appendingPathComponent("package"))

            let package = temp.appendingPathComponent("package")
            let manifestURL = package.appendingPathComponent("manifest.json")
            let decoded = try JSONDecoder().decode(PatchManifest.self, from: Data(contentsOf: manifestURL))

            let destination = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent(decoded.name, isDirectory: true)
            if fm.fileExists(atPath: destination.path) { try fm.removeItem(at: destination) }
            try fm.copyItem(at: package, to: destination)

            workspaceURL = destination
            manifest = decoded
            refresh()
            status = "Đã nhập \(decoded.name)"
        } catch {
            status = "Lỗi import: \(error.localizedDescription)"
        }
    }

    func unlockPendingImport(password: String) {
        guard let url = pendingImportURL else { return }
        pendingImportURL = nil
        showingImportPassword = false
        importPatch(from: url, password: password)
    }

    func exportPatch(password: String? = nil) {
        guard let workspaceURL else { return }
        do {
            try writeManifest()
            let tempZip = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".zip")
            try fm.zipItem(at: workspaceURL, to: tempZip, shouldKeepParent: false)
            let plain = try Data(contentsOf: tempZip)

            let outputData: Data
            if let password, !password.isEmpty {
                outputData = try CryptoBox.encrypt(plain, password: password)
            } else {
                outputData = plain
            }

            let out = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent((manifest?.name ?? "Patch") + ".3105")
            try outputData.write(to: out, options: .atomic)
            try? fm.removeItem(at: tempZip)
            status = "Đã xuất: \(out.lastPathComponent)"
        } catch {
            status = "Lỗi export: \(error.localizedDescription)"
        }
    }

    func addFile(from source: URL, relativePath: String) {
        guard let workspaceURL else { return }
        let accessing = source.startAccessingSecurityScopedResource()
        defer { if accessing { source.stopAccessingSecurityScopedResource() } }
        do {
            let target = workspaceURL.appendingPathComponent(relativePath)
            try fm.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
            if fm.fileExists(atPath: target.path) { try fm.removeItem(at: target) }
            try fm.copyItem(at: source, to: target)
            refresh()
        } catch { status = "Lỗi thêm file: \(error.localizedDescription)" }
    }

    func delete(_ item: PatchItem) {
        do {
            try fm.removeItem(at: item.url)
            refresh()
        } catch { status = "Lỗi xóa: \(error.localizedDescription)" }
    }

    func refresh() {
        guard let root = workspaceURL else { items = []; return }
        var result: [PatchItem] = []
        let e = fm.enumerator(at: root, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])
        while let u = e?.nextObject() as? URL {
            let rel = u.path.replacingOccurrences(of: root.path + "/", with: "")
            let isDir = (try? u.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            if rel != "manifest.json" {
                result.append(PatchItem(url: u, relativePath: rel, isDirectory: isDir))
            }
        }
        items = result.sorted { $0.relativePath.localizedStandardCompare($1.relativePath) == .orderedAscending }
    }

    private func writeManifest() throws {
        guard let workspaceURL, var manifest else { return }
        manifest.createdAt = Date()
        let data = try JSONEncoder().encode(manifest)
        try data.write(to: workspaceURL.appendingPathComponent("manifest.json"), options: .atomic)
        self.manifest = manifest
    }
}

enum PatchError: LocalizedError {
    case passwordRequired
    var errorDescription: String? {
        switch self {
        case .passwordRequired: return "Gói này cần mật khẩu."
        }
    }
}

enum CryptoBox {
    static func key(_ password: String, salt: Data) -> SymmetricKey {
        let base = SymmetricKey(data: SHA256.hash(data: Data(password.utf8)))
        return HKDF<SHA256>.deriveKey(inputKeyMaterial: base, salt: salt, info: Data("GiaHaiPatch".utf8), outputByteCount: 32)
    }

    static func encrypt(_ plain: Data, password: String) throws -> Data {
        var salt = Data(count: 16)
        var nonceBytes = Data(count: 12)
        _ = salt.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, 16, $0.baseAddress!) }
        _ = nonceBytes.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, 12, $0.baseAddress!) }
        let sealed = try AES.GCM.seal(plain, using: key(password, salt: salt), nonce: AES.GCM.Nonce(data: nonceBytes))
        return Data("GHP1".utf8) + salt + nonceBytes + sealed.ciphertext + sealed.tag
    }

    static func decrypt(_ data: Data, password: String) throws -> Data {
        guard data.count > 32, data.prefix(4) == Data("GHP1".utf8) else { throw PatchError.passwordRequired }
        let salt = data.subdata(in: 4..<20)
        let nonce = data.subdata(in: 20..<32)
        let body = data.subdata(in: 32..<data.count)
        let cipher = body.dropLast(16)
        let tag = body.suffix(16)
        let box = try AES.GCM.SealedBox(nonce: AES.GCM.Nonce(data: nonce), ciphertext: cipher, tag: tag)
        return try AES.GCM.open(box, using: key(password, salt: salt))
    }
}
