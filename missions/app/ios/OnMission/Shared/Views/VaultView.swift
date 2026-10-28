import SwiftUI
import SwiftData
import PhotosUI
import QuickLook
import UniformTypeIdentifiers

// MARK: - Adding files to papers

/// A file, photo or scan to put into a paper (or into a new one when `doc` is nil).
struct AttachRequest: Identifiable {
    enum Source { case file, photo, scan }

    let id = UUID()
    var doc: Document?
    var source: Source
}

private struct Attacher: ViewModifier {
    @Environment(\.modelContext) private var ctx
    @Binding var request: AttachRequest?
    let onDone: (Document) -> Void
    /// The request being handled, kept after the picker clears `request`.
    @State private var pending: AttachRequest?
    @State private var photo: PhotosPickerItem?
    @State private var error: String?

    func body(content: Content) -> some View {
        content
            .onChange(of: request?.id) { _, _ in
                if let request { pending = request }
            }
            .fileImporter(isPresented: shown(.file), allowedContentTypes: [.item]) { result in
                guard case .success(let url) = result else { return }
                attach(url)
            }
            .photosPicker(isPresented: shown(.photo), selection: $photo, matching: .images)
            .onChange(of: photo) { _, picked in
                guard let picked else { return }
                Task { await attachPhoto(picked) }
            }
            .fullScreenCover(isPresented: shown(.scan)) {
                DocumentScanner { pdf in
                    request = nil
                    guard let pdf else { return }
                    let d = target("Scan \(Date.now.formatted(date: .numeric, time: .omitted))")
                    do {
                        try DocumentFiles.attach(data: pdf, name: "\(d.displayTitle).pdf", to: d)
                        onDone(d)
                    } catch { self.error = error.localizedDescription }
                }
                .ignoresSafeArea()
            }
            .notice("Something went wrong", message: $error)
    }

    private func shown(_ source: AttachRequest.Source) -> Binding<Bool> {
        Binding(get: { request?.source == source }, set: { if !$0 && request?.source == source { request = nil } })
    }

    /// The paper the file goes into: the one asked for, or a new one.
    private func target(_ title: String) -> Document {
        if let d = pending?.doc { return d }
        let d = Document()
        d.title = title
        ctx.insert(d)
        return d
    }

    private func attach(_ url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let d = target(url.deletingPathExtension().lastPathComponent)
        do {
            try DocumentFiles.attach(from: url, to: d)
            if d.title.isEmpty { d.title = url.deletingPathExtension().lastPathComponent }
            onDone(d)
        } catch {
            self.error = error.localizedDescription
        }
    }

    @MainActor
    private func attachPhoto(_ picked: PhotosPickerItem) async {
        defer { photo = nil }
        guard let data = try? await picked.loadTransferable(type: Data.self) else { return }
        let d = target("Photo \(Date.now.formatted(date: .numeric, time: .omitted))")
        do {
            try DocumentFiles.attach(data: data, name: "\(d.displayTitle).jpg", to: d)
            onDone(d)
        } catch { self.error = error.localizedDescription }
    }
}

extension View {
    /// Shows the file, photo or scan picker for `request` and puts the result into its paper.
    func attachPicker(_ request: Binding<AttachRequest?>, onDone: @escaping (Document) -> Void = { _ in }) -> some View {
        modifier(Attacher(request: request, onDone: onDone))
    }
}

extension Document {
    /// "Expires March 2031", "AMS → ZQN · 15 Dec"…: the line under a paper.
    var line: String {
        if !hasFile { return number.isEmpty ? "No file yet" : number }
        if let exp = expiresAt {
            return Document.expiresSoon(exp) ? "Expires \(longDate(exp))!" : "Expires \(exp.formatted(.dateTime.month(.wide).year()))"
        }
        return number.isEmpty ? (fileName.isEmpty ? kindValue.title : fileName) : number
    }
}

// MARK: - Vault (handoff §7): papers still missing, scan them in

struct VaultPage: View {
    @Environment(Router.self) private var router
    @Query(sort: \Document.title) private var docs: [Document]
    @State private var request: AttachRequest?
    @State private var stampPlay = 0
    /// The four rows, fixed when the page opens, so a scanned paper stays where it was.
    @State private var pinned: [String] = []

    private var needed: [Document] {
        let byID = Dictionary(docs.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let kept = pinned.compactMap { byID[$0] }
        if !pinned.isEmpty && kept.count == pinned.count { return kept }
        let soon: (Document) -> Bool = { d in d.expiresAt.map(Document.expiresSoon) ?? false }
        let missing = docs.filter { !$0.hasFile }
        let rest = docs.filter(\.hasFile).sorted { soon($0) && !soon($1) }
        return Array((missing + rest).prefix(4))
    }

    var body: some View {
        let missing = docs.filter { !$0.hasFile }.count
        let allIn = missing == 0 && !docs.isEmpty
        let rows = needed
        Screen(posterHeight: 306) {
            Hand(allIn ? "Nice work!" : "Your papers")
                .id(allIn)
                .transition(.opacity)
                .rise(0)
                .at(24, 106)
            Text("\(missing)")
                .type(.disp(184))
                .contentTransition(.numericText(value: Double(missing)))
                .animation(.easeOut(duration: 0.4), value: missing)
                .lineLimit(1)
                .offset(y: FontMetrics.shift(size: 184, lineHeight: 0.78))
                .rise(1)
                .at(18, 136)
            CapLine(allIn ? "Nothing missing.\nYou're set." : (docs.isEmpty ? "Add your first\npaper" : "Papers still\nmissing"))
                .id(allIn)
                .transition(.opacity)
                .rise(2)
                .at(24, 292)
            Picture(.vault, height: 180).rise(3).at(208, 118)
            AllInStamp(play: stampPlay)
                .opacity(allIn ? 1 : 0)
                .at(206 + 124 - 36, 116 + 192 - 36)
        } sheet: {
            SheetScroll {
                SectionHeader("Needed to fly", count: "\(docs.count - missing) of \(docs.count)")
                ForEach(Array(rows.enumerated()), id: \.element.id) { index, d in
                    VaultRow(doc: d, rule: index < rows.count - 1) {
                        request = AttachRequest(doc: d, source: DocumentScanner.isAvailable ? .scan : .file)
                    }
                }
                if docs.isEmpty {
                    EmptyRow(title: "Your vault is empty", message: "Passport, visa, insurance: the papers you must not lose.")
                    ActionRow(title: "Add a paper", icon: .plus) { router.push(.documents) }
                } else {
                    MoreLink(title: "All \(docs.count) papers") { router.push(.documents) }
                }
            }
        }
        .animation(.easeOut(duration: 0.35), value: allIn)
        .attachPicker($request)
        .onAppear { pinned = needed.map(\.id) }
        .onChange(of: missing) { old, new in
            guard new == 0 && old > 0 else { return }
            stampPlay += 1
            router.showToast("All your papers are in the Vault")
        }
        .sensoryFeedback(.impact(weight: .heavy), trigger: stampPlay)
    }
}

/// A paper: a dashed box while it's missing, with Scan. When its file arrives, a line sweeps the box twice,
/// the box turns solid and its check draws.
private struct VaultRow: View {
    @Environment(Router.self) private var router
    let doc: Document
    var rule = true
    let scan: () -> Void
    @State private var sweep = 0
    @State private var got = false
    @State private var justNow = false
    @State private var pop = 0
    @State private var camera = 0

    var body: some View {
        Row(rule: rule) {
            DocBox(icon: doc.kindValue.icon, missing: !doc.hasFile && !got, got: got, trigger: pop)
                .overlay { ScanLine(trigger: sweep) }
                .pop(pop)
            RowText(title: doc.displayTitle, subtitle: justNow ? "Scanned just now" : doc.line)
                .contentShape(Rectangle())
                .onTapGesture { router.push(.record(.document(doc))) }
            if !doc.hasFile {
                Button {
                    camera += 1
                    scan()
                } label: {
                    ButtonLabel(title: "Scan", icon: .camera, trigger: camera, small: true)
                }
                .buttonStyle(.outlinedSmall)
                .transition(.scale(scale: 0.6).combined(with: .opacity))
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAction { router.push(.record(.document(doc))) }
        .onChange(of: doc.hasFile) { was, now in
            guard now && !was else { return }
            sweep += 1
            Motion.after(0.96) {
                withAnimation(.easeOut(duration: 0.2)) {
                    got = true
                    justNow = true
                }
                pop += 1
            }
        }
    }
}

/// A glowing line that sweeps down and up the box twice (480ms each way).
private struct ScanLine: View {
    let trigger: Int

    var body: some View {
        Clock(trigger: trigger, duration: 1.92) { t in
            if t < 1.92 {
                let leg = Int(t / 0.48)
                let local = Ease.easeInOut((t - Double(leg) * 0.48) / 0.48)
                let y = leg % 2 == 0 ? local : 1 - local
                Capsule()
                    .fill(Palette.ink)
                    .frame(width: 36, height: 2.5)
                    .shadow(color: Palette.ink.opacity(0.55), radius: 4)
                    .offset(y: -17.5 + 35 * y)
            }
        }
        .frame(width: 44, height: 44)
        .allowsHitTesting(false)
    }
}

/// ALL IN, slammed onto the folder (520ms after 300ms: from 2.2× and 12°).
private struct AllInStamp: View {
    let play: Int

    var body: some View {
        Clock(trigger: play, duration: 0.85) { t in
            let p = Ease(0.6, 0, 0.9, 0.6)(min(max((t - 0.3) / 0.52, 0), 1))
            let stops = [0, 0.7, 0.85, 1.0]
            ZStack {
                Circle().fill(Palette.coral)
                Circle().strokeBorder(Palette.ink, lineWidth: 2.6)
                Circle().strokeBorder(Palette.ink, style: StrokeStyle(lineWidth: 1.6, dash: [2, 4])).padding(7)
                Text("ALL IN")
                    .type(TypeStyle(size: 17, wght: 900, tracking: 0.06, relativeTo: nil))
                    .foregroundStyle(Palette.ink)
            }
            .frame(width: 72, height: 72)
            .rotationEffect(.degrees(-14 + kf(p, [12, 0, 0, 0], stops)))
            .scaleEffect(kf(p, [2.2, 1, 1.06, 1], stops))
            .opacity(kf(p, [0, 1, 1, 1], stops))
        }
        .accessibilityLabel("All in")
    }
}

// MARK: - All papers

struct DocumentsPage: View {
    @Environment(\.modelContext) private var ctx
    @Environment(Router.self) private var router
    @Query(sort: \Document.title) private var docs: [Document]
    @State private var search = ""
    @State private var request: AttachRequest?
    @State private var dropTargeted = false

    var body: some View {
        let visible = search.isEmpty ? docs : docs.filter {
            $0.title.localizedCaseInsensitiveContains(search) || $0.notes.localizedCaseInsensitiveContains(search)
                || $0.fileName.localizedCaseInsensitiveContains(search) || $0.number.localizedCaseInsensitiveContains(search)
        }
        let soon = docs.filter { d in d.expiresAt.map(Document.expiresSoon) ?? false }.count
        Screen(posterHeight: 306, sheetTop: 16) {
            Hand("Every paper").rise(0).at(24, 106)
            Lines("\(docs.count)", .disp(184), lineHeight: 0.78).rise(1).at(18, 136)
            CapLine(soon > 0 ? "\(soon) expiring\nsoon" : "\(docs.filter(\.hasFile).count) with a file").rise(2).at(24, 292)
            Picture(.vault, height: 180).rise(3).at(208, 118)
        } sheet: {
            if docs.count > 6 {
                SearchField(text: $search, prompt: "Search \(docs.count) papers")
            }
            SheetScroll {
                ForEach(DocumentKind.allCases, id: \.self) { kind in
                    let inKind = visible.filter { $0.kindValue == kind }
                    if !inKind.isEmpty {
                        SectionHeader(kind.title, count: inKind.count).padding(.top, 14)
                        ForEach(Array(inKind.enumerated()), id: \.element.id) { index, d in
                            Button { router.push(.record(.document(d))) } label: {
                                Row(rule: index < inKind.count - 1) {
                                    DocBox(icon: d.kindValue.icon, missing: !d.hasFile)
                                    RowText(title: d.displayTitle, subtitle: d.line,
                                            late: d.expiresAt.map(Document.expiresSoon) ?? false)
                                }
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button("Delete", role: .destructive) { Store.delete(d, in: ctx) }
                            }
                        }
                    }
                }
                if visible.isEmpty {
                    EmptyRow(title: docs.isEmpty ? "Your vault is empty" : "Nothing matches",
                             message: docs.isEmpty ? "Add passport scans, your visa, insurance papers and numbers you must not lose."
                                                   : "Try another word.")
                }
                FormBlock("Add", footer: "Files stay on this iPhone and on your own server.") {
                    ActionRow(title: "New paper (text or number)", icon: .pen) { newDocument() }
                    ActionRow(title: "Add a file", icon: .clip) { request = AttachRequest(source: .file) }
                    ActionRow(title: "Add a photo", icon: .image) { request = AttachRequest(source: .photo) }
                    if DocumentScanner.isAvailable {
                        ActionRow(title: "Scan with the camera", icon: .camera) { request = AttachRequest(source: .scan) }
                    }
                }
            }
        }
        .overlay {
            if dropTargeted {
                RoundedRectangle(cornerRadius: Metrics.sheetRadius)
                    .strokeBorder(Palette.ink, style: StrokeStyle(lineWidth: 3, dash: [10, 6]))
                    .padding(6)
                    .allowsHitTesting(false)
            }
        }
        // Drag files in from Files or another app (iPad, or iPhone with two apps).
        .dropDestination(for: URL.self) { urls, _ in
            for url in urls { addFile(url) }
            return !urls.isEmpty
        } isTargeted: { dropTargeted = $0 }
        .attachPicker($request) { d in router.push(.record(.document(d))) }
    }

    private func newDocument() {
        let d = Document()
        ctx.insert(d)
        router.push(.record(.document(d)))
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
}

// MARK: - One paper

struct DocumentDetail: View {
    @Bindable var doc: Document
    @State private var request: AttachRequest?
    @State private var preview: URL?
    @State private var error: String?
    @State private var downloading = false

    var body: some View {
        let cap: String = {
            if let exp = doc.expiresAt { return "Expires \(longDate(exp))" }
            return doc.hasFile ? DocumentFiles.sizeText(doc) : "No file yet"
        }()
        DetailPage(aside: doc.kindValue.title, title: doc.displayTitle, cap: cap) {
            fileBlock
            FormBlock("Details", footer: "With an expiry date you get a reminder 90 and 30 days before.") {
                TextRow("Title", text: $doc.title)
                SelectRow("Kind", selection: Binding(get: { doc.kindValue }, set: { doc.kindValue = $0 })) {
                    ForEach(DocumentKind.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                TextRow("Number (passport no., policy no.…)", text: $doc.number, plain: true)
                OptionalDateRow(title: "Issued", date: $doc.issuedAt)
                OptionalDateRow(title: "Expires", date: $doc.expiresAt)
            }
            FormBlock("Notes", footer: "Don't store full passwords here. A hint, or where to find it, is enough.") {
                TextRow("Addresses, phone numbers, policy details…", text: $doc.notes, vertical: true, lines: 3...20)
            }
            LinksBlock(record: .document(doc))
            DeleteButton(item: doc)
        }
        .quickLookPreview($preview)
        .attachPicker($request)
        .notice("Something went wrong", message: $error)
    }

    @ViewBuilder
    private var fileBlock: some View {
        FormBlock("File", footer: "Papers with \"Keep on every device\" download during sync, so you have them offline at the border.") {
            if doc.hasFile {
                ValueRow(label: doc.fileName.isEmpty ? "File" : doc.fileName, value: DocumentFiles.sizeText(doc))
                if let url = DocumentFiles.localURL(doc) {
                    ActionRow(title: "Open", icon: .eye) { preview = url }
                    ShareLink(item: url) {
                        FieldRow {
                            AnimatedIcon(.share, size: 20).foregroundStyle(Palette.ink)
                            Text("Share or save a copy").type(.bodyBold).foregroundStyle(Palette.ink)
                            Spacer(minLength: 4)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    ValueRow(label: "On your server", value: doc.uploadedFileID == doc.fileID ? "Yes" : "After the next sync")
                } else {
                    ActionRow(title: downloading ? "Downloading…" : "Download to this iPhone", icon: .download) {
                        guard !downloading else { return }
                        Task { await download() }
                    }
                }
                ToggleRow("Keep on every device", isOn: $doc.offline)
                ActionRow(title: "Replace with a file", icon: .clip) { request = AttachRequest(doc: doc, source: .file) }
                ActionRow(title: "Remove file", icon: .minus, role: .destructive) { DocumentFiles.detach(doc) }
            } else {
                if DocumentScanner.isAvailable {
                    ActionRow(title: "Scan with the camera", icon: .camera) { request = AttachRequest(doc: doc, source: .scan) }
                }
                ActionRow(title: "Attach a file", icon: .clip) { request = AttachRequest(doc: doc, source: .file) }
                ActionRow(title: "Attach a photo", icon: .image) { request = AttachRequest(doc: doc, source: .photo) }
            }
        }
    }

    @MainActor
    private func download() async {
        downloading = true
        defer { downloading = false }
        do { try await DocumentFiles.download(doc) } catch { self.error = error.localizedDescription }
    }
}
