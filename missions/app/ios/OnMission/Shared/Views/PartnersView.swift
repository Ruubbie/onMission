import SwiftUI
import SwiftData
import UniformTypeIdentifiers

// MARK: - Moving a partner along

extension PartnerStage {
    /// The next stage on the usual path, for the swipe and the main button.
    var next: PartnerStage? {
        switch self {
        case .idea: .toAsk
        case .toAsk: .asked
        case .asked: .thinking
        case .thinking: .committed
        case .committed: .giving
        case .giving, .declined, .paused: nil
        }
    }

    var shortTitle: String {
        switch self {
        case .idea: "On my list"
        case .toAsk: "To ask"
        case .asked: "Asked"
        case .thinking: "Thinking"
        case .committed: "Committed"
        case .giving: "Giving"
        case .declined: "Not now"
        case .paused: "Paused"
        }
    }
}

extension Partner {
    /// Sets the stage and lets the automations add the next step.
    func move(to stage: PartnerStage, _ ctx: ModelContext) {
        let old = stageValue
        guard old != stage else { return }
        stageValue = stage
        Automations.partnerStageChanged(self, from: old, ctx)
    }

    /// Committed or giving without a thank-you yet, or a gift came in after the last one (as on Today).
    func needsThanks(_ gifts: [Gift]) -> Bool {
        if stageValue.countsAsSupport && thankedAt == nil { return true }
        return gifts.contains { g in
            g.partnerID == id && g.thankedAt == nil && (thankedAt.map { g.date > $0 } ?? true)
        }
    }

    /// Thanked today: ticks the thank-you tasks and marks the gifts thanked.
    func markThanked(_ ctx: ModelContext) {
        thankedAt = .now
        Automations.partnerThanked(self, ctx)
    }
}

// MARK: - People: partners by what they need from you, and contacts

struct PeopleView: View {
    enum Segment: Hashable { case partners, contacts }

    struct PartnerGroup: Identifiable {
        let title: String
        let partners: [Partner]
        var id: String { title }
    }

    @Environment(\.modelContext) private var ctx
    @Query(sort: \Partner.name) private var partners: [Partner]
    @Query(sort: \Contact.name) private var contacts: [Contact]
    @Query private var gifts: [Gift]
    @Query private var settingsList: [MissionSettings]
    @State private var segment: Segment = .partners
    @State private var search = ""
    @State private var bulkAdd = false
    @State private var importing = false
    @State private var exporting = false
    @State private var message: String?
    @State private var opened: Partner?
    @State private var openedContact: Contact?

    private static let needsYou = "Needs you"

    private var settings: MissionSettings { settingsList.first ?? MissionSettings() }

    private var insights: Insights {
        Insights(settings: settings, tasks: [], partners: partners, gifts: gifts, budget: [],
                 sells: [], packing: [], documents: [])
    }

    var body: some View {
        let i = insights
        List {
            header.brutalRow(top: 8, bottom: 4)
            BrutalSegmented(options: [(value: Segment.partners, label: "Partners · \(partners.count)"),
                                      (value: Segment.contacts, label: "Contacts · \(contacts.count)")],
                            selection: $segment)
                .brutalRow(top: 2, bottom: 6)
            if segment == .partners {
                partnerRows(i)
            } else {
                contactRows
            }
        }
        .brutalList()
        .toolbar(.hidden, for: .navigationBar)
        .captureContext(.partner)
        .task {
            // `-startPartner YES` opens someone in conversation (for screenshots).
            if UserDefaults.standard.bool(forKey: "startPartner"), opened == nil {
                #if DEBUG
                if partners.isEmpty { Self.addDemoPartners(ctx) }
                #endif
                opened = Store.all(Partner.self, ctx).first { $0.stageValue == .thinking } ?? partners.first
            }
        }
        .navigationDestination(item: $opened) { PartnerDetail(partner: $0) }
        .navigationDestination(item: $openedContact) { ContactDetail(contact: $0) }
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

    private var header: some View {
        HStack {
            Text("People").font(Typeface.heading(18)).foregroundStyle(Palette.ink)
            Spacer()
            Menu {
                Button { newPartner() } label: { Label("New partner", systemImage: "person.badge.plus") }
                Button { bulkAdd = true } label: { Label("Add many names", systemImage: "list.bullet") }
                Button { newContact() } label: { Label("New contact", systemImage: "person.crop.rectangle") }
                Divider()
                Button { importing = true } label: { Label("Import partners (CSV)…", systemImage: "square.and.arrow.down") }
                Button { exporting = true } label: { Label("Export partners (CSV)…", systemImage: "square.and.arrow.up") }
            } label: {
                IconTile(symbol: "ellipsis", size: 36)
            }
            .accessibilityLabel("More")
        }
    }

    // MARK: Partners

    @ViewBuilder
    private func partnerRows(_ i: Insights) -> some View {
        PartnersSummary(insights: i, settings: settings)
            .brutalRow(top: 2, bottom: 6)
        BrutalSearchField(text: $search, prompt: "Find a name")
            .brutalRow(top: 2, bottom: 4)
        let sections = groups(i)
        ForEach(sections) { group in
            SectionHeader(group.title, count: group.partners.count)
                .brutalRow(top: 12, bottom: 0)
            ForEach(group.partners) { p in
                partnerRow(p, reason: group.title == Self.needsYou ? reason(p, i) : nil,
                           first: p.id == group.partners.first?.id, last: p.id == group.partners.last?.id)
            }
        }
        if sections.isEmpty {
            BrutalEmptyState(symbol: "person.2.fill", title: partners.isEmpty ? "No names yet" : "No one here",
                             message: partners.isEmpty
                                ? "Tap ••• and choose \"Add many names\" to write down everyone you know."
                                : "Nobody matches \"\(search)\".",
                             accent: .pink, ollie: partners.isEmpty ? .hug : nil)
                .brutalRow()
        }
    }

    private func partnerRow(_ p: Partner, reason: String?, first: Bool, last: Bool) -> some View {
        CardLink { PartnerDetail(partner: p) } label: {
            PartnerRow(partner: p, reason: reason, first: first, last: last)
        }
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 0, leading: Metrics.l, bottom: 0, trailing: Metrics.l))
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            if let next = p.stageValue.next {
                Button(next.shortTitle) { withAnimation { p.move(to: next, ctx) } }
                    .tint(Accent.green.color)
            }
        }
        .swipeActions(edge: .trailing) {
            Button("Delete", role: .destructive) { Store.delete(p, in: ctx) }
            if p.stageValue.isOpen {
                Button("Tomorrow") {
                    p.nextFollowUp = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: .now))
                }
                .tint(Accent.purple.color)
            }
        }
        .contextMenu {
            Menu("Set stage") {
                ForEach(PartnerStage.allCases) { s in
                    Button { p.move(to: s, ctx) } label: { Label(s.title, systemImage: s.symbol) }
                }
            }
            Button("Delete", role: .destructive) { Store.delete(p, in: ctx) }
        }
    }

    private func matches(_ p: Partner) -> Bool {
        search.isEmpty || p.name.localizedCaseInsensitiveContains(search)
            || p.notes.localizedCaseInsensitiveContains(search) || p.church.localizedCaseInsensitiveContains(search)
    }

    /// Needs you first (follow-ups due and thanks owed), then the rest by where they are.
    private func groups(_ i: Insights) -> [PartnerGroup] {
        let shown = partners.filter(matches)
        let shownIDs = Set(shown.map(\.id))
        var needs: [Partner] = []
        for p in i.followUps + i.toThank where shownIDs.contains(p.id) && !needs.contains(where: { $0.id == p.id }) {
            needs.append(p)
        }
        let needIDs = Set(needs.map(\.id))
        func pick(_ stages: [PartnerStage]) -> [Partner] {
            shown.filter { stages.contains($0.stageValue) && !needIDs.contains($0.id) }
        }
        let all = [
            PartnerGroup(title: Self.needsYou, partners: needs),
            PartnerGroup(title: "In conversation", partners: pick([.asked, .thinking])),
            PartnerGroup(title: "To ask", partners: pick([.toAsk])),
            PartnerGroup(title: "Partners", partners: pick([.committed, .giving])),
            PartnerGroup(title: "On my list", partners: pick([.idea])),
            PartnerGroup(title: "Not now", partners: pick([.declined, .paused])),
        ]
        return all.filter { !$0.partners.isEmpty }
    }

    private func reason(_ p: Partner, _ i: Insights) -> String? {
        if i.followUps.contains(where: { $0.id == p.id }) {
            let what = p.nextStep.isEmpty ? "Follow up" : p.nextStep
            guard let when = p.nextFollowUp else { return what }
            return "\(what) · \(shortDate(when))"
        }
        return p.needsThanks(gifts) ? "Say thanks" : nil
    }

    // MARK: Contacts

    private var visibleContacts: [Contact] {
        guard !search.isEmpty else { return contacts }
        return contacts.filter {
            $0.name.localizedCaseInsensitiveContains(search) || $0.organisation.localizedCaseInsensitiveContains(search)
                || $0.role.localizedCaseInsensitiveContains(search) || $0.notes.localizedCaseInsensitiveContains(search)
        }
    }

    @ViewBuilder
    private var contactRows: some View {
        BrutalSearchField(text: $search, prompt: "Find a contact")
            .brutalRow(top: 2, bottom: 4)
        ForEach(visibleContacts) { c in
            CardLink { ContactDetail(contact: c) } label: { ContactRow(contact: c) }
                .brutalRow(top: 4, bottom: 6)
                .swipeActions {
                    Button("Delete", role: .destructive) { Store.delete(c, in: ctx) }
                }
        }
        if visibleContacts.isEmpty {
            BrutalEmptyState(symbol: "person.crop.rectangle.stack.fill", title: contacts.isEmpty ? "No contacts yet" : "No match",
                             message: contacts.isEmpty ? "YWAM Queenstown, the gemeente, your insurer, the GP: everyone you need to reach." : "",
                             accent: .grey)
                .brutalRow()
        }
        Button { newContact() } label: {
            Label("New contact", systemImage: "plus").frame(maxWidth: .infinity)
        }
        .buttonStyle(.brutalSecondary)
        .brutalRow(top: 8, bottom: 8)
    }

    #if DEBUG
    /// Sample partners for simulator screenshots (debug builds only, and only when there are none).
    private static func addDemoPartners(_ ctx: ModelContext) {
        let today = Calendar.current.startOfDay(for: .now)
        func add(_ name: String, _ stage: PartnerStage, monthly: Int = 0, follow: Int? = nil, step: String = "") {
            let p = Partner()
            p.name = name
            p.stageValue = stage
            p.monthlyCents = monthly
            p.phone = "06 12345678"
            p.nextStep = step
            p.nextFollowUp = follow.flatMap { Calendar.current.date(byAdding: .day, value: $0, to: today) }
            ctx.insert(p)
        }
        add("Anna Jansen", .thinking, follow: 0, step: "Call about her decision")
        add("Jan de Vries", .committed, monthly: 2_500)
        add("Familie Bakker", .giving, monthly: 5_000)
        add("Sanne Visser", .asked, follow: 2, step: "Coffee on Thursday")
        add("Pieter Smit", .toAsk)
        add("Kerk De Rank", .idea)
        try? ctx.save()
    }
    #endif

    // MARK: Actions

    private func newPartner() {
        let p = Partner()
        ctx.insert(p)
        opened = p
    }

    private func newContact() {
        let c = Contact()
        ctx.insert(c)
        openedContact = c
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
    let insights: Insights
    let settings: MissionSettings

    var body: some View {
        let stretch = max(settings.supportTargetMonthlyCents, 1)
        VStack(alignment: .leading, spacing: 4) {
            Cap("Monthly support")
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(euros(insights.committedMonthlyCents)).font(Typeface.number(26)).foregroundStyle(Palette.ink)
                Text("of \(euros(settings.supportTargetMonthlyCents)) a month")
                    .font(Typeface.body(13, weight: .semibold)).foregroundStyle(Palette.muted)
            }
            BrutalProgress(value: Double(insights.committedMonthlyCents) / Double(stretch), accent: .yellow,
                           goal: Double(settings.supportMinimumMonthlyCents) / Double(stretch))
                .padding(.top, 6)
            Text(line)
                .font(Typeface.body(12.5, weight: .semibold))
                .foregroundStyle(Palette.muted)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .brutalBox()
        .stitched()
    }

    private var line: String {
        let talking = insights.openConversations
        let conversations = "\(talking) in conversation."
        guard insights.stillNeededForMinimumCents > 0 else { return "Minimum reached (the green line). \(conversations)" }
        var text = "\(euros(insights.stillNeededForMinimumCents)) a month to your minimum (the green line)"
        if insights.partnersStillNeeded > 0 {
            text += ": about \(insights.partnersStillNeeded) partners at \(euros(settings.averageGiftCents))"
        }
        return text + ". " + conversations
    }
}

/// A partner as a line: initials, name, amount or next step (or why they need you), and a stage pill.
struct PartnerRow: View {
    let partner: Partner
    var reason: String? = nil
    var first: Bool = true
    var last: Bool = true

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Avatar(name: partner.displayTitle, size: 34)
                VStack(alignment: .leading, spacing: 1) {
                    Text(partner.displayTitle)
                        .font(Typeface.body(15, weight: .semibold))
                        .foregroundStyle(Palette.ink)
                        .lineLimit(1)
                    Text(reason ?? detail)
                        .font(Typeface.body(12, weight: .semibold))
                        .foregroundStyle(isLate ? Palette.danger : (reason != nil ? Accent.pink.color : Palette.tag))
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                Pill(text: partner.stageValue.shortTitle, accent: partner.stageValue.accent)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            if !last { Rectangle().fill(Palette.hairline).frame(height: 1).padding(.horizontal, 12) }
        }
        .background(UnevenRoundedRectangle(topLeadingRadius: first ? 18 : 0, bottomLeadingRadius: last ? 18 : 0,
                                           bottomTrailingRadius: last ? 18 : 0, topTrailingRadius: first ? 18 : 0,
                                           style: .continuous).fill(Palette.paper))
    }

    private var isLate: Bool {
        guard partner.stageValue.isOpen, let d = partner.nextFollowUp else { return false }
        return d < Calendar.current.startOfDay(for: .now)
    }

    private var detail: String {
        if partner.monthlyCents > 0 && partner.stageValue.countsAsSupport {
            return "\(Money.text(partner.monthlyCents, partner.currency)) a month"
        }
        var parts: [String] = []
        if partner.stageValue.isOpen {
            if !partner.nextStep.isEmpty { parts.append(partner.nextStep) }
            if let d = partner.nextFollowUp { parts.append(shortDate(d)) }
        }
        if parts.isEmpty { parts.append(partner.category.isEmpty ? partner.stageValue.title : "Category \(partner.category)") }
        return parts.joined(separator: " · ")
    }
}

// MARK: - Detail: the next action first, details folded below

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
            FormHeroRow {
                PartnerHero(partner: partner, needsThanks: partner.needsThanks(gifts)) { recordingGift = true }
            }
            if partner.stageValue.isOpen { nextStepSection }
            if partner.stageValue.countsAsSupport || !gifts.isEmpty { giftsSection }
            messagesSection
            detailsSection
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
        .captureContext(.task, linkTo: .partner(partner))
        .sheet(isPresented: $recordingGift) { RecordGiftSheet(partner: partner) }
    }

    private var nextStepSection: some View {
        Section {
            TextField("What's next (call, coffee, send pitch…)", text: $partner.nextStep)
            OptionalDatePicker(title: "Follow up on", date: $partner.nextFollowUp)
            QuickDateChips(date: $partner.nextFollowUp,
                           options: [.init(title: "Tomorrow", days: 1), .init(title: "In 3 days", days: 3),
                                     .init(title: "Next week", days: 7), .init(title: "In 2 weeks", days: 14)])
            OptionalDatePicker(title: "Last contact", date: $partner.lastContact)
        } header: {
            FormHeader("Next step")
        } footer: {
            Text("From three days before the follow-up date, they show under Needs you and on Today.")
        }
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

    private var messagesSection: some View {
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
    }

    private var detailsSection: some View {
        Section {
            DisclosureGroup {
                MoneyField(title: "Monthly", cents: $partner.monthlyCents, currency: partner.currency)
                MoneyField(title: "One-off", cents: $partner.oneOffCents, currency: partner.currency)
                BrutalSelect("Currency", selection: $partner.currency) {
                    Text("Euro").tag("EUR")
                    Text("NZ dollar").tag("NZD")
                }
                OptionalDatePicker(title: "Giving since", date: $partner.startDate)
                Toggle("Thanked", isOn: Binding(get: { partner.thankedAt != nil }, set: { on in
                    if on { partner.markThanked(ctx) } else { partner.thankedAt = nil }
                }))
                Toggle("Prays for you", isOn: $partner.prayer)
                Toggle("Gets the newsletter", isOn: $partner.newsletter)
            } label: {
                DetailLabel(title: "Giving", summary: givingSummary)
            }
            DisclosureGroup {
                TextField("Phone", text: $partner.phone)
                    .keyboardType(.phonePad)
                TextField("Email", text: $partner.email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                TextField("Church", text: $partner.church)
                TextField("Postal address (for cards)", text: $partner.address, axis: .vertical)
                OptionalDatePicker(title: "Birthday", date: $partner.birthday)
            } label: {
                DetailLabel(title: "Contact", summary: contactSummary)
            }
        } header: {
            FormHeader("Details")
        }
    }

    private var givingSummary: String {
        var parts: [String] = []
        if partner.monthlyCents > 0 { parts.append("\(Money.text(partner.monthlyCents, partner.currency)) a month") }
        if partner.oneOffCents > 0 { parts.append("\(Money.text(partner.oneOffCents, partner.currency)) one-off") }
        if partner.thankedAt != nil { parts.append("thanked") }
        if partner.prayer { parts.append("prays") }
        return parts.isEmpty ? "Nothing yet" : parts.joined(separator: " · ")
    }

    private var contactSummary: String {
        let parts = [partner.phone, partner.email, partner.church].filter { !$0.isEmpty }
        return parts.isEmpty ? "No details yet" : parts.prefix(2).joined(separator: " · ")
    }
}

private struct DetailLabel: View {
    let title: String
    let summary: String

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title).font(Typeface.body(15, weight: .semibold)).foregroundStyle(Palette.ink)
            Text(summary).font(Typeface.body(12.5)).foregroundStyle(Palette.muted).lineLimit(1)
        }
    }
}

/// Name, category, call / WhatsApp / email, where they are on the path, and the one thing to do next.
private struct PartnerHero: View {
    @Environment(\.modelContext) private var ctx
    @Environment(\.openURL) private var openURL
    @Bindable var partner: Partner
    let needsThanks: Bool
    let onRecordGift: () -> Void

    var body: some View {
        TextField("Name", text: $partner.name)
            .font(Typeface.heading(24))
            .foregroundStyle(Palette.ink)
        HStack(spacing: 6) {
            Menu {
                Picker("Category", selection: Binding(get: { partner.categoryValue }, set: { partner.categoryValue = $0 })) {
                    ForEach(PartnerCategory.allCases) { Text($0.title).tag($0) }
                }
            } label: {
                Chip(text: partner.category.isEmpty ? "Category" : "Category \(partner.category)", accent: .sand,
                     symbol: "chevron.down", selected: false)
            }
            .accessibilityLabel("Category \(partner.category)")
            if partner.monthlyCents > 0 {
                Chip(text: "\(Money.text(partner.monthlyCents, partner.currency)) a month", accent: .green)
            }
            Spacer(minLength: 0)
            if let url = PhoneLinks.call(partner.phone) {
                IconButton(symbol: "phone.fill", accent: .green, size: 38, label: "Call") { openURL(url) }
            }
            if let url = PhoneLinks.whatsApp(partner.phone) {
                IconButton(symbol: "message.fill", accent: .lime, size: 38, label: "WhatsApp") { openURL(url) }
            }
            if let url = PhoneLinks.email(partner.email) {
                IconButton(symbol: "envelope.fill", accent: .yellow, size: 38, label: "Email") { openURL(url) }
            }
        }
        StagePath(stage: partner.stageValue) { picked in
            withAnimation(.easeOut(duration: 0.2)) { partner.move(to: picked, ctx) }
        }
        .padding(.top, 4)
        PartnerNextAction(partner: partner, needsThanks: needsThanks, onRecordGift: onRecordGift)
    }
}

/// The path from "on my list" to "giving" as dots on a line. Tap a dot to set the stage.
private struct StagePath: View {
    let stage: PartnerStage
    let onPick: (PartnerStage) -> Void
    private let path: [PartnerStage] = [.idea, .toAsk, .asked, .thinking, .committed, .giving]

    var body: some View {
        let reached = path.firstIndex(of: stage) ?? -1
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                ForEach(Array(path.enumerated()), id: \.offset) { index, s in
                    if index > 0 {
                        Capsule()
                            .fill(index <= reached ? Accent.yellow.color : Palette.chip)
                            .frame(height: 3)
                    }
                    Button { onPick(s) } label: {
                        ZStack {
                            Circle()
                                .fill(index <= reached ? Accent.yellow.color : Palette.chip)
                                .frame(width: s == stage ? 24 : 12, height: s == stage ? 24 : 12)
                            if s == stage {
                                Image(systemName: s.symbol)
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(Palette.onAccent)
                            }
                        }
                        .frame(width: 32, height: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(s.title)
                    .accessibilityAddTraits(s == stage ? .isSelected : [])
                }
            }
            HStack(alignment: .firstTextBaseline) {
                Text(stage.title).font(Typeface.body(14, weight: .bold)).foregroundStyle(Palette.ink)
                Spacer()
                Menu {
                    ForEach([PartnerStage.declined, .paused]) { s in
                        Button { onPick(s) } label: { Label(s.title, systemImage: s.symbol) }
                    }
                } label: {
                    Text("Not now…")
                        .font(Typeface.body(12.5, weight: .semibold))
                        .foregroundStyle(Palette.muted)
                        .frame(minHeight: 32)
                }
            }
        }
    }
}

/// One clear next step for where this partner is, with the matching message template beside it.
private struct PartnerNextAction: View {
    @Environment(\.modelContext) private var ctx
    let partner: Partner
    let needsThanks: Bool
    let onRecordGift: () -> Void

    private var who: String { partner.firstName.isEmpty ? "them" : partner.firstName }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(hint)
                .font(Typeface.body(13))
                .foregroundStyle(Palette.muted)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) { buttons }
        }
        .padding(.top, 2)
    }

    private var hint: String {
        switch partner.stageValue {
        case .idea: "On your list. Ready to ask \(who)?"
        case .toAsk: "Invite \(who) for coffee or a call."
        case .asked: "After you've met, log it: a follow-up call is planned for you."
        case .thinking: partner.nextFollowUp.map { "Thinking it over. Next follow-up: \(shortDate($0))." } ?? "Thinking it over."
        case .committed: needsThanks ? "Committed, and not thanked yet." : "Committed. Waiting for the first gift."
        case .giving: needsThanks ? "A gift came in that you haven't thanked \(who) for yet." : "Giving. Record gifts as they come in."
        case .declined, .paused: "Not now. You can ask again later."
        }
    }

    @ViewBuilder
    private var buttons: some View {
        switch partner.stageValue {
        case .idea:
            primary("Plan to ask", "paperplane") { partner.move(to: .toAsk, ctx) }
        case .toAsk:
            share("Send invite", .invite, primary: true)
            secondary("I asked") { partner.move(to: .asked, ctx) }
        case .asked:
            primary("Log the meeting", "cup.and.saucer") {
                partner.lastContact = Calendar.current.startOfDay(for: .now)
                partner.move(to: .thinking, ctx)
            }
            share("Thanks text", .thanksAfterMeeting, primary: false)
        case .thinking:
            primary("They're in", "hand.thumbsup") { partner.move(to: .committed, ctx) }
            share("Follow-up", .followUp, primary: false)
        case .committed, .giving:
            if needsThanks {
                primary("Mark thanked", "checkmark") { partner.markThanked(ctx) }
                share("Thank-you text", MessageTemplate.suggested(for: partner).first ?? .thankYouCard, primary: false)
            } else {
                primary("Record a gift", "gift", action: onRecordGift)
            }
        case .declined, .paused:
            secondary("Ask again") { partner.move(to: .toAsk, ctx) }
        }
    }

    private func primary(_ title: String, _ symbol: String, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.easeOut(duration: 0.2)) { action() }
        } label: {
            Label(title, systemImage: symbol)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(BrutalButtonStyle(kind: .primary))
    }

    private func secondary(_ title: String, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.easeOut(duration: 0.2)) { action() }
        } label: {
            Text(title)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.brutalSecondary)
    }

    private func share(_ title: String, _ template: MessageTemplate, primary: Bool) -> some View {
        ShareLink(item: template.text(for: partner)) {
            Label(title, systemImage: "text.bubble")
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(BrutalButtonStyle(kind: primary ? .primary : .secondary))
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
