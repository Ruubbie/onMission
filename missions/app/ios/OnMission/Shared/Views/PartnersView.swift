import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct PartnersView: View {
    @Environment(\.modelContext) private var ctx
    @Query(sort: \Partner.name) private var partners: [Partner]
    @Query private var settingsList: [MissionSettings]
    @State private var search = ""
    @State private var stageFilter: PartnerStage?
    @State private var bulkAdd = false
    @State private var importing = false
    @State private var exporting = false
    @State private var message: String?
    @State private var opened: Partner?

    private var settings: MissionSettings { settingsList.first ?? MissionSettings() }

    private var visible: [Partner] {
        partners.filter { p in
            (stageFilter == nil || p.stageValue == stageFilter)
                && (search.isEmpty || p.name.localizedCaseInsensitiveContains(search)
                    || p.notes.localizedCaseInsensitiveContains(search) || p.church.localizedCaseInsensitiveContains(search))
        }
    }

    var body: some View {
        List {
            PartnersSummary(partners: partners, settings: settings, stageFilter: $stageFilter)
                .brutalRow(top: 10, bottom: 10)
            ForEach(visible) { p in
                CardLink {
                    PartnerDetail(partner: p)
                } label: {
                    PartnerRow(partner: p)
                }
                .brutalRow(top: 4, bottom: 6)
                .swipeActions {
                    Button("Delete", role: .destructive) { Store.delete(p, in: ctx) }
                }
                .contextMenu {
                    Menu("Set stage") {
                        ForEach(PartnerStage.allCases) { s in
                            Button { setStage(p, s) } label: { Label(s.title, systemImage: s.symbol) }
                        }
                    }
                    Button("Delete", role: .destructive) { Store.delete(p, in: ctx) }
                }
            }
            if visible.isEmpty {
                BrutalEmptyState(symbol: "person.2.fill", title: partners.isEmpty ? "No names yet" : "No one here",
                                 message: partners.isEmpty ? "Tap + and choose \"Add many names\" to write down everyone you know." : "Nobody matches this filter.",
                                 accent: .pink)
                    .brutalRow()
            }
            Color.clear.frame(height: 80).brutalRow()
        }
        .brutalList()
        .brutalSearch(text: $search, prompt: "Find a name")
        .navigationTitle("Partners")
        .addMenu {
            Button { newPartner() } label: { Label("New partner", systemImage: "person.badge.plus") }
            Button { bulkAdd = true } label: { Label("Add many names", systemImage: "list.bullet") }
            Button { importing = true } label: { Label("Import CSV…", systemImage: "square.and.arrow.down") }
            Button { exporting = true } label: { Label("Export CSV…", systemImage: "square.and.arrow.up") }
        }
        .navigationDestination(item: $opened) { PartnerDetail(partner: $0) }
        .sheet(isPresented: $bulkAdd) { BulkAddPartners() }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.commaSeparatedText, .plainText, .text]) { result in
            guard case .success(let url) = result else { return }
            importCSV(url)
        }
        .fileExporter(isPresented: $exporting, document: DataFile(data: Backup.partnersCSV(partners)),
                      contentType: .commaSeparatedText, defaultFilename: "partners.csv") { _ in }
        .brutalDialog("Import", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } }),
                      message: message ?? "")
    }

    private func newPartner() {
        let p = Partner()
        ctx.insert(p)
        opened = p
    }

    private func setStage(_ p: Partner, _ s: PartnerStage) {
        let old = p.stageValue
        guard old != s else { return }
        p.stageValue = s
        Automations.partnerStageChanged(p, from: old, ctx)
    }

    private func importCSV(_ url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let text = (try? String(contentsOf: url, encoding: .utf8)) ?? (try? String(contentsOf: url, encoding: .isoLatin1)) ?? ""
        let n = Backup.importPartners(text, ctx)
        message = "Added \(n) new name\(n == 1 ? "" : "s"). Names already in your list were skipped."
    }
}

// MARK: - Summary and rows

private struct PartnersSummary: View {
    let partners: [Partner]
    let settings: MissionSettings
    @Binding var stageFilter: PartnerStage?

    private var committed: Int {
        partners.filter { $0.stageValue.countsAsSupport }.reduce(0) { $0 + $1.monthlyCents }
    }

    var body: some View {
        BrutalCard(fill: Palette.softPink) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(euros(committed)).font(Typeface.heading(30)).foregroundStyle(Palette.ink)
                Text("of \(euros(settings.supportTargetMonthlyCents)) a month")
                    .font(Typeface.body(15)).foregroundStyle(Palette.ink)
            }
            BrutalProgress(value: settings.supportTargetMonthlyCents > 0 ? Double(committed) / Double(settings.supportTargetMonthlyCents) : 0,
                           accent: committed >= settings.supportMinimumMonthlyCents ? .green : .pink)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(PartnerStage.allCases) { s in
                        let n = partners.filter { $0.stageValue == s }.count
                        FilterChip(text: "\(s.title) \(n)", accent: s.accent, selected: stageFilter == s) {
                            stageFilter = stageFilter == s ? nil : s
                        }
                    }
                }
                .padding(.vertical, 2)
            }
            Text("\(partners.count) names on your list. Aim for 150+; about one in two or three personal meetings becomes a monthly partner.")
                .font(Typeface.body(13))
                .foregroundStyle(Palette.ink)
        }
    }
}

struct PartnerRow: View {
    let partner: Partner

    var body: some View {
        HStack(spacing: Metrics.m) {
            AccentSquareIcon(symbol: partner.stageValue.symbol, accent: partner.stageValue.accent, size: 36)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(partner.displayTitle)
                        .font(Typeface.body(16, weight: .bold))
                        .foregroundStyle(Palette.ink)
                        .lineLimit(1)
                    Text(partner.category)
                        .font(Typeface.body(12, weight: .bold))
                        .foregroundStyle(Palette.muted)
                }
                Text(detail)
                    .font(Typeface.body(13))
                    .foregroundStyle(isLate ? Palette.danger : Palette.muted)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            if partner.monthlyCents > 0 {
                Text("\(euros(partner.monthlyCents))/mo")
                    .font(Typeface.heading(14))
                    .foregroundStyle(Palette.ink)
            }
        }
        .padding(Metrics.m)
        .brutalBox(radius: Metrics.radiusSmall, shadow: Metrics.shadowSmall)
    }

    private var isLate: Bool {
        guard partner.stageValue.isOpen, let d = partner.nextFollowUp else { return false }
        return d < Calendar.current.startOfDay(for: .now)
    }

    private var detail: String {
        var parts = [partner.stageValue.title]
        if partner.stageValue.isOpen {
            if !partner.nextStep.isEmpty { parts.append(partner.nextStep) }
            if let d = partner.nextFollowUp { parts.append(shortDate(d)) }
        }
        return parts.joined(separator: " · ")
    }
}

// MARK: - Detail

struct PartnerDetail: View {
    @Environment(\.modelContext) private var ctx
    @Bindable var partner: Partner
    @Query private var gifts: [Gift]
    @State private var recordingGift = false

    init(partner: Partner) {
        self.partner = partner
        let pid = partner.id
        _gifts = Query(filter: #Predicate<Gift> { $0.partnerID == pid }, sort: \Gift.date, order: .reverse)
    }

    var body: some View {
        Form {
            FormHeroRow(fill: partner.stageValue.accent.color.opacity(0.3)) {
                PartnerHero(partner: partner)
            }

            Section {
                BrutalSelect("Stage", selection: stageBinding) {
                    ForEach(PartnerStage.allCases) { Label($0.title, systemImage: $0.symbol).tag($0) }
                }
                BrutalSelect("Category", selection: Binding(get: { partner.categoryValue }, set: { partner.categoryValue = $0 })) {
                    ForEach(PartnerCategory.allCases) { Text($0.title).tag($0) }
                }
            } header: {
                FormHeader("Where you are")
            } footer: {
                Text("Changing the stage adds the next step for you: a meeting, a follow-up call, or a thank-you card.")
            }

            if partner.stageValue.isOpen {
                Section {
                    TextField("What's next (call, coffee, send pitch…)", text: $partner.nextStep)
                    OptionalDatePicker(title: "Follow up on", date: $partner.nextFollowUp)
                    OptionalDatePicker(title: "Last contact", date: $partner.lastContact)
                } header: { FormHeader("Next step") }
            }

            givingSection
            giftsSection
            contactSection

            Section {
                ForEach(MessageTemplate.suggested(for: partner)) { t in
                    ShareLink(item: t.text(for: partner)) {
                        Label(t.title, systemImage: "text.bubble.fill")
                    }
                }
                Menu {
                    ForEach(MessageTemplate.allCases) { t in
                        ShareLink(t.title, item: t.text(for: partner))
                    }
                } label: {
                    Label("All templates", systemImage: "ellipsis.bubble")
                }
            } header: {
                FormHeader("Messages")
            } footer: {
                Text("From your partners guide, with their name filled in. Fill in the [brackets] before sending.")
            }

            Section {
                TextField("What you talked about, prayer requests, family names…", text: $partner.notes, axis: .vertical)
                    .lineLimit(3...12)
            } header: { FormHeader("Notes") }

            LinksSection(record: .partner(partner))
            Section { DeleteRecordButton(item: partner) }
        }
        .brutalForm()
        .navigationTitle(partner.displayTitle)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $recordingGift) { RecordGiftSheet(partner: partner) }
    }

    private var stageBinding: Binding<PartnerStage> {
        Binding(get: { partner.stageValue }, set: { new in
            let old = partner.stageValue
            guard new != old else { return }
            partner.stageValue = new
            Automations.partnerStageChanged(partner, from: old, ctx)
        })
    }

    private var givingSection: some View {
        Section {
            MoneyField(title: "Monthly", cents: $partner.monthlyCents, currency: partner.currency)
            MoneyField(title: "One-off", cents: $partner.oneOffCents, currency: partner.currency)
            BrutalSelect("Currency", selection: $partner.currency) {
                Text("Euro").tag("EUR")
                Text("NZ dollar").tag("NZD")
            }
            OptionalDatePicker(title: "Giving since", date: $partner.startDate)
            Toggle("Thanked", isOn: Binding(get: { partner.thankedAt != nil }, set: { on in
                if on {
                    partner.thankedAt = .now
                    Automations.partnerThanked(partner, ctx)
                } else {
                    partner.thankedAt = nil
                }
            }))
            .tint(Accent.green.color)
            Toggle("Prays for you", isOn: $partner.prayer).tint(Accent.green.color)
            Toggle("Gets the newsletter", isOn: $partner.newsletter).tint(Accent.green.color)
        } header: { FormHeader("Giving") }
    }

    private var giftsSection: some View {
        Section {
            ForEach(gifts) { g in
                NavigationLink { GiftDetail(gift: g) } label: { GiftRow(gift: g) }
            }
            Button { recordingGift = true } label: {
                Label("Record a gift", systemImage: "plus.circle.fill")
            }
        } header: {
            FormHeader("Gifts received")
        }
    }

    private var contactSection: some View {
        Section {
            TextField("Phone", text: $partner.phone)
                .keyboardType(.phonePad)
            TextField("Email", text: $partner.email)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            TextField("Church", text: $partner.church)
            TextField("Postal address (for cards)", text: $partner.address, axis: .vertical)
            OptionalDatePicker(title: "Birthday", date: $partner.birthday)
        } header: { FormHeader("Contact") }
    }
}

/// Name, stage and the call / WhatsApp / email buttons.
private struct PartnerHero: View {
    @Bindable var partner: Partner
    @Environment(\.openURL) private var openURL

    var body: some View {
        TextField("Name", text: $partner.name)
            .font(Typeface.heading(24))
            .foregroundStyle(Palette.ink)
        HStack(spacing: 6) {
            Chip(text: partner.stageValue.title, accent: partner.stageValue.accent, symbol: partner.stageValue.symbol)
            Chip(text: partner.category, accent: .sand)
            if partner.monthlyCents > 0 { Chip(text: "\(euros(partner.monthlyCents))/mo", accent: .green) }
        }
        HStack(spacing: Metrics.m) {
            if let url = PhoneLinks.call(partner.phone) {
                IconButton(symbol: "phone.fill", accent: .green, label: "Call") { openURL(url) }
            }
            if let url = PhoneLinks.whatsApp(partner.phone) {
                IconButton(symbol: "message.fill", accent: .lime, label: "WhatsApp") { openURL(url) }
            }
            if let url = PhoneLinks.email(partner.email) {
                IconButton(symbol: "envelope.fill", accent: .yellow, label: "Email") { openURL(url) }
            }
        }
        .padding(.top, 4)
    }
}

struct GiftRow: View {
    let gift: Gift

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(Money.text(gift.amountCents, gift.currency))
                    .font(Typeface.body(16, weight: .bold))
                Text("\(longDate(gift.date))\(gift.recurring ? " · monthly" : "")\(gift.via.isEmpty ? "" : " · \(gift.via)")")
                    .font(Typeface.body(13))
                    .foregroundStyle(Palette.muted)
            }
            Spacer()
            if gift.thankedAt != nil {
                Chip(text: "Thanked", accent: .green, symbol: "checkmark")
            }
        }
    }
}

struct GiftDetail: View {
    @Bindable var gift: Gift
    @Query private var partners: [Partner]

    var body: some View {
        Form {
            Section {
                MoneyField(title: "Amount", cents: $gift.amountCents, currency: gift.currency)
                BrutalSelect("Currency", selection: $gift.currency) {
                    Text("Euro").tag("EUR")
                    Text("NZ dollar").tag("NZD")
                }
                BrutalDateRow(title: "Date", date: $gift.date)
                Toggle("Part of a monthly gift", isOn: $gift.recurring).tint(Accent.green.color)
                TextField("Via (bank, YWAM, cash…)", text: $gift.via)
                OptionalDatePicker(title: "Thanked", date: $gift.thankedAt, defaultDate: .now)
            } header: { FormHeader("Gift") }

            if let p = partners.first(where: { $0.id == gift.partnerID }) {
                Section {
                    NavigationLink { PartnerDetail(partner: p) } label: { Label(p.displayTitle, systemImage: "person.fill") }
                } header: { FormHeader("From") }
            }

            Section {
                TextField("Notes", text: $gift.notes, axis: .vertical).lineLimit(2...8)
            } header: { FormHeader("Notes") }

            LinksSection(record: .gift(gift))
            Section { DeleteRecordButton(item: gift) }
        }
        .brutalForm()
        .navigationTitle("Gift")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct RecordGiftSheet: View {
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss
    let partner: Partner
    @State private var cents = 0
    @State private var recurring = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    MoneyField(title: "Amount", cents: $cents, currency: partner.currency)
                    Toggle("Part of a monthly gift", isOn: $recurring).tint(Accent.green.color)
                } header: {
                    FormHeader("Gift from \(partner.displayTitle)")
                } footer: {
                    Text("Recording a gift adds a thank-you task when it's needed.")
                }
            }
            .brutalForm()
            .navigationTitle("Record a gift")
            .navigationBarTitleDisplayMode(.inline)
            .brutalSheetToolbar(cancel: { dismiss() }, save: "Save", saveDisabled: cents <= 0) {
                Automations.recordGift(for: partner, cents: cents, recurring: recurring, ctx)
                dismiss()
            }
        }
        .onAppear {
            cents = partner.monthlyCents
            recurring = partner.monthlyCents > 0
        }
    }
}

/// Paste or type a list of names, one per line. Good for the first brain-dump of 150 people.
struct BulkAddPartners: View {
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var category: PartnerCategory = .b

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextEditor(text: $text).frame(minHeight: 240)
                } header: {
                    FormHeader("One name per line")
                } footer: {
                    Text("Family, church, friends, school, work, sport, neighbours, YWAM, your phone contacts. Write everyone down; you don't decide for someone else whether they'll give.")
                }
                Section {
                    BrutalSelect("Category for all", selection: $category) {
                        ForEach(PartnerCategory.allCases) { Text($0.title).tag($0) }
                    }
                }
            }
            .brutalForm()
            .navigationTitle("Add names")
            .navigationBarTitleDisplayMode(.inline)
            .brutalSheetToolbar(cancel: { dismiss() }, save: "Add", onSave: add)
        }
    }

    private func add() {
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        let rows = lines.map { "\"\($0.replacingOccurrences(of: "\"", with: ""))\",\(category.rawValue)" }
        let csv = (["name,category"] + rows).joined(separator: "\n")
        _ = Backup.importPartners(csv, ctx)
        dismiss()
    }
}
