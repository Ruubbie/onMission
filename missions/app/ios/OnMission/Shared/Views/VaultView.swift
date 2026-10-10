import SwiftUI
import SwiftData
import PhotosUI
import QuickLook
import UniformTypeIdentifiers

/// The vault: passport, visa, insurance and other papers, on this iPhone and on your own server.
struct VaultView: View {
    @Environment(\.modelContext) private var ctx
    @Query(sort: \Document.title) private var docs: [Document]
    @State private var search = ""
    @State private var importing = false
    @State private var opened: Document?
    @State private var choosingPhoto = false
    @State private var photo: PhotosPickerItem?
    @State private var scanning = false
    @State private var dropTargeted = false

    private var visible: [Document] {
        guard !search.isEmpty else { return docs }
        return docs.filter {
            $0.title.localizedCaseInsensitiveContains(search) || $0.notes.localizedCaseInsensitiveContains(search)
                || $0.fileName.localizedCaseInsensitiveContains(search) || $0.number.localizedCaseInsensitiveContains(search)
        }
    }

    var body: some View {
        List {
            ForEach(DocumentKind.allCases, id: \.self) { kind in
                let inKind = visible.filter { $0.kindValue == kind }
                if !inKind.isEmpty {
                    SectionHeader(kind.title, count: inKind.count, accent: .purple)
                        .brutalRow(top: 14, bottom: 2)
                    ForEach(inKind) { d in
                        CardLink { DocumentDetail(doc: d) } label: { DocumentRow(doc: d) }
                            .brutalRow(top: 4, bottom: 6)
                            .swipeActions {
                                Button("Delete", role: .destructive) { Store.delete(d, in: ctx) }
                            }
                    }
                }
            }
            if docs.isEmpty {
                BrutalEmptyState(symbol: "lock.doc.fill", title: "Your vault is empty",
                                 message: "Add passport scans, your visa, insurance papers and numbers you must not lose.",
                                 accent: .purple)
                    .brutalRow()
            }
            Color.clear.frame(height: 80).brutalRow()
        }
        .brutalList()
        .overlay {
            if dropTargeted {
                RoundedRectangle(cornerRadius: Metrics.radius)
                    .strokeBorder(Accent.purple.color, style: StrokeStyle(lineWidth: 4, dash: [10, 6]))
                    .padding(6)
                    .allowsHitTesting(false)
            }
        }
        // Drag files in from Files or another app (iPad, or iPhone with two apps).
        .dropDestination(for: URL.self) { urls, _ in
            for url in urls { addFile(url) }
            return !urls.isEmpty
        } isTargeted: { dropTargeted = $0 }
        .brutalSearch(text: $search)
        .navigationTitle("Vault")
        .addMenu {
            Button { newDocument() } label: { Label("New item (text or number)", systemImage: "square.and.pencil") }
            Button { importing = true } label: { Label("Add a file…", systemImage: "doc.badge.plus") }
            Button { choosingPhoto = true } label: { Label("Add a photo", systemImage: "photo.badge.plus") }
            if DocumentScanner.isAvailable {
                Button { scanning = true } label: { Label("Scan a document", systemImage: "doc.viewfinder") }
            }
        }
        .navigationDestination(item: $opened) { DocumentDetail(doc: $0) }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.item], allowsMultipleSelection: true) { result in
            if case .success(let urls) = result {
                for url in urls { addFile(url) }
            }
        }
        .photosPicker(isPresented: $choosingPhoto, selection: $photo, matching: .images)
        .onChange(of: photo) { _, picked in
            guard let picked else { return }
            Task { await addPhoto(picked) }
        }
        .fullScreenCover(isPresented: $scanning) {
            DocumentScanner { pdf in
                scanning = false
                guard let pdf else { return }
                let d = Document()
                d.title = "Scan \(Date.now.formatted(date: .numeric, time: .omitted))"
                ctx.insert(d)
                try? DocumentFiles.attach(data: pdf, name: "\(d.title).pdf", to: d)
                opened = d
            }
            .ignoresSafeArea()
        }
    }

    private func newDocument() {
        let d = Document()
        ctx.insert(d)
        opened = d
    }

    private func addFile(_ url: URL) {
        let d = Document()
        d.title = url.deletingPathExtension().lastPathComponent
        ctx.insert(d)
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        do {
            try DocumentFiles.attach(from: url, to: d)
        } catch {
            d.notes = "Could not read the file: \(error.localizedDescription)"
        }
    }

    @MainActor
    private func addPhoto(_ picked: PhotosPickerItem) async {
        defer { photo = nil }
        guard let data = try? await picked.loadTransferable(type: Data.self) else { return }
        let d = Document()
        d.title = "Photo \(Date.now.formatted(date: .numeric, time: .omitted))"
        ctx.insert(d)
        try? DocumentFiles.attach(data: data, name: "\(d.title).jpg", to: d)
        opened = d
    }
}

// MARK: - Row

struct DocumentRow: View {
    let doc: Document

    var body: some View {
        HStack(spacing: Metrics.m) {
            AccentSquareIcon(symbol: doc.kindValue.symbol, accent: .purple, size: 36)
            VStack(alignment: .leading, spacing: 4) {
                Text(doc.displayTitle)
                    .font(Typeface.body(16, weight: .bold))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(2)
                HStack(spacing: 6) {
                    if doc.hasFile {
                        Chip(text: DocumentFiles.sizeText(doc), accent: .lime, symbol: "doc.fill")
                        if DocumentFiles.localURL(doc) == nil {
                            Chip(text: "On server", accent: .grey, symbol: "icloud")
                        }
                    } else {
                        Chip(text: "No file", accent: .sand, symbol: "exclamationmark")
                    }
                    if let exp = doc.expiresAt {
                        Text("Exp. \(longDate(exp))")
                            .font(Typeface.body(12, weight: .semibold))
                            .foregroundStyle(DocumentDetail.expiresSoon(exp) ? Palette.danger : Palette.muted)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(Metrics.m)
        .brutalBox(radius: Metrics.radiusSmall, shadow: Metrics.shadowSmall)
    }
}

// MARK: - Detail

struct DocumentDetail: View {
    @Environment(\.modelContext) private var ctx
    @Bindable var doc: Document
    @State private var replacing = false
    @State private var choosingPhoto = false
    @State private var photo: PhotosPickerItem?
    @State private var scanning = false
    @State private var preview: URL?
    @State private var error: String?
    @State private var downloading = false

    static func expiresSoon(_ d: Date) -> Bool {
        d < (Calendar.current.date(byAdding: .day, value: 90, to: .now) ?? .now)
    }

    var body: some View {
        Form {
            FormHeroRow(fill: Palette.softPink) {
                TextField("Title", text: $doc.title)
                    .font(Typeface.heading(22))
                    .foregroundStyle(Palette.ink)
                HStack(spacing: 6) {
                    Chip(text: doc.kindValue.title, accent: .purple, symbol: doc.kindValue.symbol)
                    if let exp = doc.expiresAt {
                        Chip(text: "Expires \(longDate(exp))", accent: Self.expiresSoon(exp) ? .pink : .lime)
                    }
                }
            }

            fileSection

            Section {
                BrutalSelect("Kind", selection: Binding(get: { doc.kindValue }, set: { doc.kindValue = $0 })) {
                    ForEach(DocumentKind.allCases, id: \.self) { Label($0.title, systemImage: $0.symbol).tag($0) }
                }
                TextField("Number (passport no., policy no.…)", text: $doc.number)
                    .font(.body.monospaced())
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                OptionalDatePicker(title: "Issued", date: $doc.issuedAt)
                OptionalDatePicker(title: "Expires", date: $doc.expiresAt)
            } header: {
                FormHeader("Details")
            } footer: {
                Text("With an expiry date you get a reminder 90 and 30 days before.")
            }

            Section {
                TextField("Addresses, phone numbers, policy details…", text: $doc.notes, axis: .vertical)
                    .lineLimit(3...20)
            } header: {
                FormHeader("Notes")
            } footer: {
                Text("Don't store full passwords here. A hint, or where to find it, is enough.")
            }

            LinksSection(record: .document(doc))
            Section { DeleteRecordButton(item: doc) }
        }
        .brutalForm()
        .navigationTitle(doc.displayTitle)
        .navigationBarTitleDisplayMode(.inline)
        .quickLookPreview($preview)
        .fileImporter(isPresented: $replacing, allowedContentTypes: [.item]) { result in
            guard case .success(let url) = result else { return }
            attach(url)
        }
        .photosPicker(isPresented: $choosingPhoto, selection: $photo, matching: .images)
        .onChange(of: photo) { _, picked in
            guard let picked else { return }
            Task { await attachPhoto(picked) }
        }
        .fullScreenCover(isPresented: $scanning) {
            DocumentScanner { pdf in
                scanning = false
                guard let pdf else { return }
                do { try DocumentFiles.attach(data: pdf, name: "\(doc.displayTitle).pdf", to: doc) } catch { self.error = error.localizedDescription }
            }
            .ignoresSafeArea()
        }
        .brutalDialog("Something went wrong", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } }),
                      message: error ?? "")
    }

    @MainActor @ViewBuilder
    private var fileSection: some View {
        Section {
            if doc.hasFile {
                LabeledContent(doc.fileName.isEmpty ? "File" : doc.fileName, value: DocumentFiles.sizeText(doc))
                if let url = DocumentFiles.localURL(doc) {
                    Button { preview = url } label: { Label("Open", systemImage: "eye.fill") }
                    ShareLink(item: url) { Label("Share or save a copy", systemImage: "square.and.arrow.up") }
                    LabeledContent("On your server", value: doc.uploadedFileID == doc.fileID ? "Yes" : "After the next sync")
                } else {
                    Button {
                        Task { await download() }
                    } label: {
                        HStack {
                            Label("Download to this iPhone", systemImage: "icloud.and.arrow.down")
                            if downloading { Spacer(); BrutalSpinner(size: 16) }
                        }
                    }
                    .disabled(downloading)
                }
                Toggle("Keep on every device", isOn: $doc.offline).tint(Accent.green.color)
                Menu {
                    attachButtons
                } label: {
                    Label("Replace file", systemImage: "arrow.triangle.2.circlepath")
                }
                Button(role: .destructive) { DocumentFiles.detach(doc) } label: {
                    Label("Remove file", systemImage: "minus.circle").foregroundStyle(Palette.danger)
                }
            } else {
                attachButtons
            }
        } header: {
            FormHeader("File")
        } footer: {
            Text("Files with \"Keep on every device\" are downloaded during sync, so you have them offline at the border.")
        }
    }

    @MainActor @ViewBuilder
    private var attachButtons: some View {
        Button { replacing = true } label: { Label("Attach a file…", systemImage: "paperclip") }
        Button { choosingPhoto = true } label: { Label("Attach a photo", systemImage: "photo") }
        if DocumentScanner.isAvailable {
            Button { scanning = true } label: { Label("Scan with the camera", systemImage: "doc.viewfinder") }
        }
    }

    private func attach(_ url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        do {
            try DocumentFiles.attach(from: url, to: doc)
            if doc.title.isEmpty { doc.title = url.deletingPathExtension().lastPathComponent }
        } catch {
            self.error = error.localizedDescription
        }
    }

    @MainActor
    private func attachPhoto(_ picked: PhotosPickerItem) async {
        defer { photo = nil }
        guard let data = try? await picked.loadTransferable(type: Data.self) else { return }
        do { try DocumentFiles.attach(data: data, name: "\(doc.displayTitle).jpg", to: doc) } catch { self.error = error.localizedDescription }
    }

    @MainActor
    private func download() async {
        downloading = true
        defer { downloading = false }
        do { try await DocumentFiles.download(doc) } catch { self.error = error.localizedDescription }
    }
}
