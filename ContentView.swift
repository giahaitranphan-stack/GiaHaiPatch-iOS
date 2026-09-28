import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject private var store: PatchStore
    @State private var showNew = false
    @State private var showImport = false
    @State private var showExportPassword = false
    @State private var exportPassword = ""

    var body: some View {
        NavigationStack {
            List {
                Section("Patch") {
                    if let m = store.manifest {
                        LabeledContent("Tên", value: m.name)
                        LabeledContent("Target", value: m.targets.joined(separator: ", "))
                        LabeledContent("Định dạng", value: "3105 v\(m.version)")
                    } else {
                        ContentUnavailableView("Chưa có patch", systemImage: "shippingbox")
                    }
                }

                Section("Workspace") {
                    ForEach(store.items) { item in
                        HStack {
                            Image(systemName: item.isDirectory ? "folder.fill" : "doc")
                            VStack(alignment: .leading) {
                                Text(item.relativePath)
                                    .font(.body)
                                    .lineLimit(2)
                                Text(item.isDirectory ? "Folder" : "File")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if !item.isDirectory {
                                ShareLink(item: item.url)
                            }
                        }
                        .contextMenu {
                            Button(role: .destructive) {
                                store.delete(item)
                            } label: {
                                Label("Xóa", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .navigationTitle("GiaHai Patch")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Menu {
                        Button("Patch mới") { showNew = true }
                        Button("Import .3105") { showImport = true }
                        Button("Export .3105") { showExportPassword = true }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Text(store.status)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(8)
                    .background(.thinMaterial)
            }
            .fileImporter(
                isPresented: $showImport,
                allowedContentTypes: [UTType(filenameExtension: "3105") ?? .data, .zip, .data],
                allowsMultipleSelection: false
            ) { result in
                if case .success(let urls) = result, let url = urls.first {
                    store.importPatch(from: url)
                }
            }
            .sheet(isPresented: $showNew) {
                NewPatchView()
                    .environmentObject(store)
            }
            .sheet(isPresented: $showExportPassword) {
                ExportView(password: $exportPassword)
                    .environmentObject(store)
            }
            .sheet(isPresented: $store.showingImportPassword) {
                ImportPasswordView()
                    .environmentObject(store)
            }
        }
    }
}

struct NewPatchView: View {
    @EnvironmentObject private var store: PatchStore
    @Environment(\.dismiss) private var dismiss
    @State private var name = "My Patch"
    @State private var bundleID = "com.example.app"

    var body: some View {
        NavigationStack {
            Form {
                TextField("Tên patch", text: $name)
                TextField("Bundle ID", text: $bundleID)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            .navigationTitle("Patch mới")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Hủy") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Tạo") {
                        store.newPatch(name: name, bundleID: bundleID)
                        dismiss()
                    }
                    .disabled(name.isEmpty || bundleID.isEmpty)
                }
            }
        }
    }
}

struct ExportView: View {
    @EnvironmentObject private var store: PatchStore
    @Environment(\.dismiss) private var dismiss
    @Binding var password: String

    var body: some View {
        NavigationStack {
            Form {
                Section("Mật khẩu tùy chọn") {
                    SecureField("Để trống nếu không cần", text: $password)
                    Text("Mật khẩu được dùng để mã hóa gói export bằng AES-GCM.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Export .3105")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Hủy") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Export") {
                        store.exportPatch(password: password.isEmpty ? nil : password)
                        password = ""
                        dismiss()
                    }
                }
            }
        }
    }
}


struct ImportPasswordView: View {
    @EnvironmentObject private var store: PatchStore
    @Environment(\.dismiss) private var dismiss
    @State private var password = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Mật khẩu patch") {
                    SecureField("Nhập mật khẩu", text: $password)
                    Text("Gói này được mã hóa. Nhập đúng mật khẩu để mở nội dung.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Mở patch")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Hủy") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Mở") {
                        store.unlockPendingImport(password: password)
                        dismiss()
                    }
                    .disabled(password.isEmpty)
                }
            }
        }
    }
}
