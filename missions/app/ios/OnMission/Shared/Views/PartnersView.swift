import SwiftUI
import SwiftData
import UniformTypeIdentifiers

// MARK: - A person

extension Partner {
    /// Sets the stage and lets the automations add the next step.
    func move(to stage: PartnerStage, _ ctx: ModelContext) {
        let old = stageValue
        guard old != stage else { return }
        stageValue = stage
        Automations.partnerStageChanged(self, from: old, ctx)
    }

    /// Committed or giving without a thank-you yet, or a gift came in after the last one.
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

    /// The next step the server sets with a message from hesent.me.
    static let replyStep = "Reply to their message from hesent.me"

    /// The hesent.me message is answered: no longer waiting on you, and the reply follow-up goes.
    func markAnswered() {
        replyWaiting = false
        lastContact = Calendar.current.startOfDay(for: .now)
        if nextStep == Partner.replyStep {
            nextStep = ""
            nextFollowUp = nil
        }
    }

    /// An email back, in the language they wrote in, with their newest message quoted.
    var replyURL: URL? {
        guard let m = siteMessages.first else { return PhoneLinks.email(email) }
        let en = m.lang == "en"
        let first = (m.name.isEmpty ? name : m.name).split(separator: " ").first.map(String.init) ?? ""
        let quote = m.text.split(separator: "\n", omittingEmptySubsequences: false).map { "> \($0)" }.joined(separator: "\n")
        let body = "\(en ? "Hi" : "Hoi") \(first),\n\n\n\n\(en ? "You wrote on hesent.me" : "Je schreef op hesent.me"):\n\(quote)"
        return PhoneLinks.email(email, subject: en ? "Your message on hesent.me" : "Je bericht op hesent.me", body: body)
    }

    /// How they are with you, not how far along: "Gives €50 a month · prays", or "In your people" (as on the web).
    var line: String {
        var bits: [String] = []
        if stageValue.countsAsSupport {
            bits.append(monthlyCents > 0 ? "Gives \(Money.text(monthlyCents, currency)) a month"
                        : (oneOffCents > 0 ? "Gave \(Money.text(oneOffCents, currency))" : "Gives"))
        }
        if prayer { bits.append(bits.isEmpty ? "Prays" : "prays") }
        if newsletter { bits.append(bits.isEmpty ? "Gets letters" : "gets letters") }
        if wantsToMeet { bits.append(bits.isEmpty ? "Wants to meet" : "wants to meet") }
        return bits.isEmpty ? "In your people" : bits.joined(separator: " · ")
    }

    /// Whether one of the ways is on for them.
    func has(_ way: Way) -> Bool {
        switch way {
        case .gives: stageValue.countsAsSupport
        case .prays: prayer
        case .letters: newsletter
        case .meet: wantsToMeet
        }
    }

    /// Switches a way on or off. Gives on is "giving" (the amount is set beside it); off is back on the list.
    func setWay(_ way: Way, _ on: Bool, _ ctx: ModelContext) {
        switch way {
        case .gives:
            if on { move(to: .giving, ctx) } else { monthlyCents = 0; move(to: .idea, ctx) }
        case .prays: prayer = on
        case .letters: newsletter = on
        case .meet: wantsToMeet = on
        }
    }

    /// They give: a monthly amount, or a gift once (recorded as a gift).
    func recordGiving(cents: Int, monthly: Bool, _ ctx: ModelContext) {
        if monthly {
            monthlyCents = cents
            move(to: .giving, ctx)
        } else {
            oneOffCents += cents
            _ = Automations.recordGift(for: self, cents: cents, recurring: false, ctx)
            if !stageValue.countsAsSupport { move(to: .giving, ctx) }
        }
        if startDate == nil { startDate = Calendar.current.startOfDay(for: .now) }
    }
}

/// The ways someone is with you. Any mix, and none is further along than another.
enum Way: CaseIterable, Identifiable {
    case gives, prays, letters, meet
    var id: Self { self }
    var title: String {
        switch self {
        case .gives: "Gives"
        case .prays: "Prays"
        case .letters: "Gets letters"
        case .meet: "Wants to meet"
        }
    }
}

// MARK: - People tab

/// People (handoff §5): monthly support big on the poster beside what friends give; "Someone gives" right at hand;
/// the people who need something from you, each with one action. Nobody is shown as further along than anyone else.
struct PeopleView: View {
    @Environment(\.modelContext) private var ctx
    @Environment(Router.self) private var router
    @Query(sort: \Partner.name) private var partners: [Partner]
    @Query private var gifts: [Gift]
    @Query private var settingsList: [MissionSettings]
    @State private var giving = false

    private var settings: MissionSettings { settingsList.first ?? MissionSettings() }

    var body: some View {
        let i = Insights(settings: settings, tasks: [], partners: partners, gifts: gifts, budget: [],
                         sells: [], packing: [], documents: [])
        let target = max(settings.supportTargetMonthlyCents, 1)
        let fraction = min(Double(i.committedMonthlyCents) / Double(target), 1)
        let waiting = waitingList(i)
        Screen(posterHeight: 306) {
            Hand("Monthly support").rise(0).at(24, 106)
            Lines(euros(i.committedMonthlyCents), .disp(112), minScale: 0.6).frame(width: 340, alignment: .leading).rise(1).at(20, 140)
            CapLine("of \(euros(settings.supportTargetMonthlyCents)) a month · \(Int((fraction * 100).rounded()))%", size: 18)
                .rise(2).at(24, 238)
            // What friends give: letters, a coffee, flowers, a heart. Not a trail to climb.
            Picture(.people, height: 153).rise(3).at(214, 236)
        } sheet: {
            SheetScroll {
                HStack(spacing: 8) {
                    ActionButton(title: "Someone gives", icon: .heart, style: .filledSmall) { giving = true }
                    ActionButton(title: "All \(partners.count) people", style: .outlinedSmall) { router.push(.allPeople) }
                    Spacer(minLength: 0)
                }
                .padding(.bottom, 16)
                if waiting.isEmpty {
                    SectionHeader("Waiting on you")
                    EmptyRow(title: "Nobody's waiting on you", message: "Nice. Nothing needs you right now.")
                } else {
                    // Everyone, not the first few: the sheet rises to the top bar when the list is long.
                    SectionHeader("Waiting on you", count: waiting.count)
                    ForEach(Array(waiting.enumerated()), id: \.element.id) { index, p in
                        WaitingRow(partner: p, gifts: gifts, rule: index < waiting.count - 1)
                            .transition(.asymmetric(insertion: .opacity, removal: .move(edge: .trailing).combined(with: .opacity)))
                    }
                }
            }
        }
        .captureContext(.partner)
        .sheet(isPresented: $giving) { SomeoneGivesSheet() }
    }

    /// The people who need something from you, and only them: messages from hesent.me first, then thanks owed,
    /// follow-ups you planned, and people who want to meet without a time yet. Nobody is listed for being on the list.
    private func waitingList(_ i: Insights) -> [Partner] {
        var out: [Partner] = []
        let meet = partners.filter { $0.wantsToMeet && $0.nextFollowUp == nil }
        for p in i.messages + i.toThank + i.followUps + meet where !out.contains(where: { $0.id == p.id }) {
            out.append(p)
        }
        return out
    }
}

/// "Someone gives": a name (someone in your people, or someone new), an amount, monthly or once. Saved at once,
/// with no stages to walk through first.
struct SomeoneGivesSheet: View {
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss
    @Environment(Router.self) private var router
    @Query(sort: \Partner.name) private var partners: [Partner]
    var fixed: Partner? = nil
    @State private var name = ""
    @State private var cents = 0
    @State private var monthly = true

    private var match: Partner? {
        let key = name.trimmingCharacters(in: .whitespaces).lowercased()
        return key.isEmpty ? nil : partners.first { $0.name.trimmingCharacters(in: .whitespaces).lowercased() == key }
    }

    var body: some View {
        let who = fixed?.displayTitle ?? name.trimmingCharacters(in: .whitespaces)
        PaperSheet(title: fixed.map { "Gift from \($0.displayTitle)" } ?? "Someone gives", save: "Save",
                   saveDisabled: cents <= 0 || who.isEmpty, onSave: save) {
            if fixed == nil {
                FormBlock("Who", footer: match == nil && !name.isEmpty ? "New: they're added to your people." : "") {
                    TextRow("Name", text: $name)
                    let hints = partners.filter { !name.isEmpty && $0.name.localizedCaseInsensitiveContains(name) && $0.id != match?.id }.prefix(3)
                    ForEach(Array(hints)) { p in
                        Button { name = p.name } label: {
                            FieldRow { Text(p.displayTitle).type(.bodyBold).foregroundStyle(Palette.ink); Spacer(minLength: 0) }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            FormBlock("What") {
                MoneyRow(title: "Amount", cents: $cents, currency: fixed?.currency ?? match?.currency ?? "EUR")
                ToggleRow("Every month", isOn: $monthly)
            }
        }
        .onAppear { if let fixed, fixed.monthlyCents > 0 { cents = fixed.monthlyCents } }
    }

    private func save() {
        let p: Partner
        if let existing = fixed ?? match {
            p = existing
        } else {
            p = Partner()
            p.name = name.trimmingCharacters(in: .whitespaces)
            p.stageValue = .idea
            ctx.insert(p)
        }
        p.recordGiving(cents: cents, monthly: monthly, ctx)
        router.showToast(monthly ? "\(p.displayTitle) gives \(Money.text(cents, p.currency)) a month"
                                 : "\(Money.text(cents, p.currency)) from \(p.displayTitle) noted")
        dismiss()
    }
}

/// A person waiting on you, with the one thing to do: Reply, Say thanks, Check in, or Plan.
private struct WaitingRow: View {
    @Environment(\.modelContext) private var ctx
    @Environment(Router.self) private var router
    @Environment(\.openURL) private var openURL
    let partner: Partner
    let gifts: [Gift]
    var rule = true
    @State private var thanked = false
    @State private var heart = 0

    private enum Action { case reply, thanks, checkIn, plan }

    private var action: Action {
        if partner.replyWaiting { return .reply }
        if partner.needsThanks(gifts) { return .thanks }
        if partner.nextFollowUp != nil { return .checkIn }
        return .plan
    }

    private var subtitle: String {
        if thanked { return "Thanked just now" }
        switch action {
        case .reply:
            guard let m = partner.siteMessages.first else { return "Wrote to you on hesent.me" }
            return "Wrote \(relativeDate(m.at)) on hesent.me: “\(m.text.replacingOccurrences(of: "\n", with: " "))”"
        case .thanks:
            if let g = gifts.filter({ $0.partnerID == partner.id && $0.thankedAt == nil }).max(by: { $0.date < $1.date }) {
                return "Gave \(Money.text(g.amountCents, g.currency)) \(relativeDate(g.date))"
            }
            return "\(partner.line), not thanked yet"
        case .checkIn:
            let what = partner.nextStep.isEmpty ? "Follow up" : partner.nextStep
            guard let when = partner.nextFollowUp else { return what }
            return "\(what) · \(shortDate(when, midSentence: true))"
        case .plan:
            return "Would like to meet. Pick a time."
        }
    }

    private var late: Bool {
        guard action == .checkIn, let d = partner.nextFollowUp else { return false }
        return d < Calendar.current.startOfDay(for: .now)
    }

    var body: some View {
        Row(rule: rule) {
            Avatar(name: partner.displayTitle)
            RowText(title: partner.displayTitle, subtitle: subtitle, late: late || action == .reply)
                .contentShape(Rectangle())
                .onTapGesture { router.push(.partner(partner)) }
            switch action {
            case .reply:
                ActionButton(title: "Reply", style: .filledSmall) { reply() }
            case .thanks:
                Button { sayThanks() } label: {
                    ButtonLabel(title: thanked ? "Thanked" : "Say thanks", icon: thanked ? .heart : nil, trigger: heart, small: true)
                }
                .buttonStyle(.filledSmall)
                .pop(heart, to: 1.08)
                .disabled(thanked)
            case .checkIn:
                ActionButton(title: "Check in", style: .outlinedSmall) {
                    router.openCheckIn(CheckInRequest(partner: partner))
                }
            case .plan:
                ActionButton(title: "Plan", style: .outlinedSmall) { router.push(.partner(partner)) }
            }
        }
        .accessibilityElement(children: .contain)
    }

    /// Opens the email back and counts the message as answered.
    private func reply() {
        if let url = partner.replyURL { openURL(url) } else { router.push(.partner(partner)); return }
        let p = partner
        router.showToast("Marked \(p.firstName.isEmpty ? p.displayTitle : p.firstName)'s message as answered")
        Motion.after(0.7) {
            withAnimation(Motion.fold.rm) { p.markAnswered() }
        }
    }

    private func sayThanks() {
        thanked = true
        heart += 1
        let p = partner
        let context = ctx
        Motion.after(0.7) {
            withAnimation(Motion.fold.rm) { p.markThanked(context) }
        }
    }
}

// MARK: - A partner's page

/// Their name big, the six-stop path with a walker, the one next thing as a hero, their story.
struct PartnerPage: View {
    @Environment(\.modelContext) private var ctx
    @Environment(Router.self) private var router
    @Environment(\.openURL) private var openURL
    @Bindable var partner: Partner
    @Query private var gifts: [Gift]
    @State private var recordingGift = false
    @State private var showDetails = false
    @State private var thanksPlay = 0

    init(partner: Partner) {
        self.partner = partner
        let pid = partner.id
        _gifts = Query(filter: #Predicate<Gift> { $0.partnerID == pid }, sort: \Gift.date, order: .reverse)
    }

    private var who: String { partner.firstName.isEmpty ? "them" : partner.firstName }

    var body: some View {
        Screen(posterHeight: 306) {
            // How they are with you, on one line: it never runs into the name.
            Text(partner.line).type(.hand(33)).lineLimit(1).truncationMode(.tail)
                .frame(width: 342, alignment: .leading).rise(0).at(24, 106)
            Lines(wrapLines(partner.displayTitle, .disp(88), width: 230, maxLines: 2), .disp(88), lineHeight: 0.95, minScale: 0.5)
                .frame(width: 350, alignment: .leading)
                .rise(1)
                .at(20, 140)
            Picture(.partner, height: 128).rise(3).at(256, 250)
        } sheet: {
            SheetScroll { sheet }
        }
        .captureContext(.task, linkTo: .partner(partner))
        .sheet(isPresented: $recordingGift) { SomeoneGivesSheet(fixed: partner) }
    }

    // MARK: Sheet

    @ViewBuilder
    private var sheet: some View {
        SectionHeader("How \(who) is with you")
        WayChips(partner: partner)
        if partner.stageValue.countsAsSupport {
            MoneyRow(title: "A month", cents: $partner.monthlyCents, currency: partner.currency)
        }
        OptionalDateRow(title: "Follow up on", date: $partner.nextFollowUp)
        if needsYou {
            SectionHeader("Next", count: dueLabel)
            hero
                .id(partner.stage + (partner.needsThanks(gifts) ? "-thanks" : "") + (partner.replyWaiting ? "-reply" : ""))
                .transition(.asymmetric(insertion: .offset(y: 22).combined(with: .opacity),
                                        removal: .offset(x: 40).combined(with: .opacity)))
        } else {
            HStack {
                ActionButton(title: "Record a gift", icon: .heart, style: .outlinedSmall) { recordingGift = true }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 14)
        }
        let story = storyItems
        SectionHeader("Story", count: story.count)
        ForEach(Array(story.enumerated()), id: \.offset) { index, item in
            Row(rule: index < story.count - 1) {
                RowText(title: item.title, subtitle: item.subtitle)
                WhenText(text: item.when)
            }
        }
        MoreLink(title: showDetails ? "Fewer details" : "Details, messages and notes") {
            withAnimation(.easeOut(duration: 0.25)) { showDetails.toggle() }
        }
        if showDetails { details.transition(.opacity) }
    }

    private var dueLabel: String {
        if partner.replyWaiting, let m = partner.siteMessages.first { return "Sent on hesent.me \(relativeDate(m.at))" }
        if partner.needsThanks(gifts) { return "Today" }
        guard let d = partner.nextFollowUp else { return partner.wantsToMeet ? "When it suits" : "" }
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        if d < today { return "Was due \(shortDate(d, midSentence: true))" }
        if cal.isDateInToday(d) { return "Today" }
        let days = cal.dateComponents([.day], from: today, to: d).day ?? 0
        if days >= 7 && days % 7 == 0 { return "In \(days / 7) week\(days == 7 ? "" : "s")" }
        return shortDate(d)
    }

    /// A message from hesent.me waiting for an answer comes before whatever the stage asks for.
    @ViewBuilder
    private var hero: some View {
        if partner.replyWaiting, let m = partner.siteMessages.first {
            HeroCard(title: "\(who.capitalized) wrote to you", subtitle: "“\(m.text)”") {
                if let url = partner.replyURL {
                    ActionButton(title: "Reply", icon: .mail) {
                        openURL(url)
                        answered()
                    }
                }
                ActionButton(title: "Mark answered", style: .outlined) { answered() }
            }
        } else {
            stageHero
        }
    }

    private func answered() {
        router.showToast("Marked as answered")
        Motion.after(0.5) { withAnimation(Motion.arrive.rm) { partner.markAnswered() } }
    }

    /// Something actually needs you: a message, a thank-you, a follow-up you planned, or a coffee to plan.
    /// Otherwise the page stays calm: no next step is invented for anyone.
    private var needsYou: Bool {
        partner.replyWaiting || partner.needsThanks(gifts) || partner.nextFollowUp != nil || partner.wantsToMeet
    }

    @ViewBuilder
    private var stageHero: some View {
        let late = partner.nextFollowUp.map { $0 < Calendar.current.startOfDay(for: .now) } ?? false
        if partner.needsThanks(gifts) {
            HeroCard(title: "Say thanks", subtitle: "A quick note means a lot.") {
                Button {
                    thanksPlay += 1
                    router.showToast("Thank-you noted for \(partner.firstName.isEmpty ? partner.displayTitle : partner.firstName)")
                    Motion.after(0.5) { withAnimation(Motion.arrive.rm) { partner.markThanked(ctx) } }
                } label: {
                    ButtonLabel(title: thanksPlay > 0 ? "Thanked" : "Say thanks", icon: .heart, trigger: thanksPlay)
                }
                .buttonStyle(.filled)
                .pop(thanksPlay)
                ActionButton(title: "Record a gift", style: .outlined) { recordingGift = true }
            }
        } else if partner.nextFollowUp != nil {
            HeroCard(title: partner.nextStep.isEmpty ? "Catch up with \(who)" : partner.nextStep,
                     subtitle: "You planned this yourself.", late: late) {
                if let url = PhoneLinks.call(partner.phone) {
                    ActionButton(title: "Call", icon: .phone) {
                        openURL(url)
                        router.openCheckIn(CheckInRequest(partner: partner))
                    }
                } else {
                    ActionButton(title: "Check in", icon: .phone) { router.openCheckIn(CheckInRequest(partner: partner)) }
                }
                ActionButton(title: "Done", style: .outlined) { caughtUp(met: false) }
            }
        } else {
            HeroCard(title: "Plan a coffee with \(who)", subtitle: "\(who.capitalized) would like to meet. Pick a day above.") {
                share("Send invite", .invite, filled: true)
                ActionButton(title: "We met", style: .outlined) { caughtUp(met: true) }
            }
        }
    }

    /// The follow-up is done (or you met): it goes, and today is the last contact.
    private func caughtUp(met: Bool) {
        withAnimation(Motion.arrive.rm) {
            partner.lastContact = Calendar.current.startOfDay(for: .now)
            partner.nextFollowUp = nil
            partner.nextStep = ""
            if met { partner.wantsToMeet = false }
        }
        router.showToast(met ? "Noted that you met" : "Done")
    }

    private func share(_ title: String, _ template: MessageTemplate, filled: Bool) -> some View {
        ShareLink(item: template.text(for: partner)) {
            ButtonLabel(title: title, icon: .message)
        }
        .buttonStyle(filled ? CapsuleStyle(kind: .filled) : CapsuleStyle(kind: .outlined))
    }

    private struct StoryItem {
        let title: String
        let subtitle: String
        let when: String
        let date: Date
    }

    private var storyItems: [StoryItem] {
        var out: [StoryItem] = []
        for g in gifts {
            out.append(StoryItem(title: "Gave \(Money.text(g.amountCents, g.currency))",
                                 subtitle: g.recurring ? "Monthly gift" : "One-off gift" + (g.thankedAt != nil ? " · thanked" : ""),
                                 when: whenText(g.date), date: g.date))
        }
        for m in partner.siteMessages {
            out.append(StoryItem(title: "Wrote on hesent.me", subtitle: m.text.replacingOccurrences(of: "\n", with: " "),
                                 when: whenText(m.at), date: m.at))
        }
        if let last = partner.lastContact {
            out.append(StoryItem(title: "Last contact", subtitle: partner.stageValue.title, when: whenText(last), date: last))
        }
        for case .note(let n) in Links.linked(to: .partner(partner), ctx) {
            out.append(StoryItem(title: n.displayTitle, subtitle: n.kindValue.title, when: whenText(n.createdAt), date: n.createdAt))
        }
        out.append(StoryItem(title: "Added to your list", subtitle: partner.church.isEmpty ? "" : partner.church,
                             when: partner.createdAt.formatted(.dateTime.month(.abbreviated)), date: partner.createdAt))
        return out.sorted { $0.date > $1.date }
    }

    // MARK: Details (the existing partner form)

    @ViewBuilder
    private var details: some View {
        FormBlock("Name") {
            TitleField(placeholder: "Name", text: $partner.name)
            SelectRow("Category", selection: Binding(get: { partner.categoryValue }, set: { partner.categoryValue = $0 })) {
                ForEach(PartnerCategory.allCases) { Text($0.title).tag($0) }
            }
        }
        // Only when you want one: nobody needs a next step just for being in your people.
        FormBlock("Next step", footer: "From three days before the follow-up date, they show under Waiting on you and on Today.") {
            TextRow("What's next (call, coffee, a card…)", text: $partner.nextStep)
            QuickDates(date: $partner.nextFollowUp,
                       options: [.init(title: "Tomorrow", days: 1), .init(title: "In 3 days", days: 3),
                                 .init(title: "Next week", days: 7), .init(title: "In 2 weeks", days: 14)])
            OptionalDateRow(title: "Last contact", date: $partner.lastContact)
        }
        if partner.stageValue.countsAsSupport || !gifts.isEmpty {
            FormBlock("Gifts received") {
                ForEach(gifts) { g in
                    LinkedRow(record: .gift(g))
                }
                ActionRow(title: "Record a gift", icon: .gift) { recordingGift = true }
            }
        }
        FormBlock("Messages", footer: "From your partners guide, with their name filled in. Fill in the [brackets] before sending.") {
            ForEach(MessageTemplate.suggested(for: partner)) { t in
                ShareLink(item: t.text(for: partner)) {
                    FieldRow {
                        AnimatedIcon(.templates, size: 20).foregroundStyle(Palette.ink)
                        Text(t.title).type(.bodyBold).foregroundStyle(Palette.ink)
                        Spacer(minLength: 0)
                    }
                }
            }
            Menu {
                ForEach(MessageTemplate.allCases) { t in ShareLink(t.title, item: t.text(for: partner)) }
            } label: {
                FieldRow {
                    AnimatedIcon(.more, size: 20).foregroundStyle(Palette.ink)
                    Text("All templates").type(.bodyBold).foregroundStyle(Palette.ink)
                    Spacer(minLength: 0)
                }
            }
        }
        FormBlock("Giving") {
            MoneyRow(title: "Monthly", cents: $partner.monthlyCents, currency: partner.currency)
            MoneyRow(title: "One-off", cents: $partner.oneOffCents, currency: partner.currency)
            SelectRow("Currency", selection: $partner.currency) {
                Text("Euro").tag("EUR")
                Text("NZ dollar").tag("NZD")
            }
            OptionalDateRow(title: "Giving since", date: $partner.startDate)
            ToggleRow("Thanked", isOn: Binding(get: { partner.thankedAt != nil }, set: { on in
                if on { partner.markThanked(ctx) } else { partner.thankedAt = nil }
            }))
            ToggleRow("Prays for you", isOn: $partner.prayer)
            ToggleRow("Gets the newsletter", isOn: $partner.newsletter)
        }
        FormBlock("Contact") {
            contactButtons
            TextRow("Phone", text: $partner.phone, keyboard: .phonePad, plain: true)
            TextRow("Email", text: $partner.email, keyboard: .emailAddress, plain: true)
            TextRow("Church", text: $partner.church)
            TextRow("Postal address (for cards)", text: $partner.address, vertical: true)
            OptionalDateRow(title: "Birthday", date: $partner.birthday)
        }
        FormBlock("Notes") {
            TextRow("What you talked about, prayer requests, family names…", text: $partner.notes, vertical: true, lines: 3...12)
        }
        LinksBlock(record: .partner(partner))
        DeleteButton(item: partner)
    }

    @ViewBuilder
    private var contactButtons: some View {
        let call = PhoneLinks.call(partner.phone)
        let app = PhoneLinks.whatsApp(partner.phone)
        let mail = PhoneLinks.email(partner.email)
        if call != nil || app != nil || mail != nil {
            HStack(spacing: 8) {
                if let call { ActionButton(title: "Call", icon: .phone, style: .outlinedSmall) { openURL(call) } }
                if let app { ActionButton(title: "WhatsApp", icon: .message, style: .outlinedSmall) { openURL(app) } }
                if let mail { ActionButton(title: "Email", icon: .mail, style: .outlinedSmall) { openURL(mail) } }
            }
            .padding(.vertical, 10)
        }
    }
}

/// How someone is with you, as four toggles (Gives, Prays, Gets letters, Wants to meet) in a 2 × 2 grid.
/// Any mix is fine; tapping one saves at once.
private struct WayChips: View {
    @Environment(\.modelContext) private var ctx
    let partner: Partner
    @State private var tapped = 0

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
            ForEach(Way.allCases) { way in
                let on = partner.has(way)
                Button {
                    tapped += 1
                    withAnimation(Motion.indicator.rm) { partner.setWay(way, !on, ctx) }
                } label: {
                    HStack(spacing: 6) {
                        if on { AnimatedIcon(.check, size: 15) }
                        Text(way.title).type(TypeStyle(size: 14.5, wght: 650, relativeTo: .subheadline)).lineLimit(1)
                    }
                    .foregroundStyle(on ? Palette.paper : Palette.ink)
                    .frame(maxWidth: .infinity, minHeight: 40)
                    .background {
                        if on { Capsule().fill(Palette.ink) } else { Capsule().strokeBorder(Palette.chipRule, lineWidth: Metrics.outline) }
                    }
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .padding(.vertical, 10)
        .sensoryFeedback(.selection, trigger: tapped)
    }
}
// MARK: - All people

/// Everyone: category pills, live search, and the tools for adding many at once.
struct AllPeoplePage: View {
    @Environment(\.modelContext) private var ctx
    @Environment(Router.self) private var router
    @Query(sort: \Partner.name) private var partners: [Partner]
    @Query private var contacts: [Contact]
    @State private var category = "all"
    @State private var search = ""
    @State private var slide = 0
    @State private var direction: CGFloat = 1
    @State private var bulkAdd = false
    @State private var importing = false
    @State private var exporting = false
    @State private var message: String?

    var body: some View {
        let monthly = partners.filter { $0.stageValue.countsAsSupport && $0.monthlyCents > 0 }
        let together = monthly.reduce(0) { $0 + $1.monthlyCents }
        let items = [Pills<String>.Item(value: "all", title: "All", count: partners.count)]
            + PartnerCategory.allCases.map { c in
                Pills<String>.Item(value: c.rawValue, title: c.rawValue, count: partners.filter { $0.categoryValue == c }.count)
            }
        let shown = partners.filter { p in
            (category == "all" || p.category == category)
                && (search.isEmpty || p.name.localizedCaseInsensitiveContains(search) || p.church.localizedCaseInsensitiveContains(search))
        }
        Screen(posterHeight: 306, sheetTop: 16) {
            Hand("Your people").rise(0).at(24, 106)
            Lines("\(partners.count)", .disp(184), lineHeight: 0.78).rise(1).at(18, 136)
            CapLine("\(monthly.count) give monthly\n\(euros(together)) together").rise(2).at(24, 292)
            // The traveller waving to everyone who sends him.
            Picture(.travellerWave, height: 232).rise(3).at(264, 110)
        } sheet: {
            Pills(items: items, selection: $category)
            SearchField(text: $search, prompt: "Search \(partners.count) people")
            SheetScroll {
                Group {
                    ForEach(Array(shown.enumerated()), id: \.element.id) { index, p in
                        Button { router.push(.partner(p)) } label: {
                            Row(rule: index < shown.count - 1) {
                                Avatar(name: p.displayTitle)
                                RowText(title: p.displayTitle, subtitle: p.line)
                                WhenText(text: p.category)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    if shown.isEmpty {
                        EmptyRow(title: partners.isEmpty ? "No names yet" : "Nobody by that name",
                                 message: partners.isEmpty ? "Add many at once below, or one with the + on a tab."
                                                           : "Add them with the + at the top.")
                    }
                }
                .slideIn(slide, direction: direction)
                FormBlock("Add and share") {
                    ActionRow(title: "New partner", icon: .user) { newPartner() }
                    ActionRow(title: "Add many names", icon: .list) { bulkAdd = true }
                    ActionRow(title: "Import partners (CSV)", icon: .download) { importing = true }
                    ActionRow(title: "Export partners (CSV)", icon: .share) { exporting = true }
                    ActionRow(title: "Contacts · \(contacts.count)", icon: .building) { router.push(.contacts) }
                }
            }
        }
        .onChange(of: category) { old, new in
            direction = Pills<String>.direction(from: old, to: new, in: items)
            slide += 1
        }
        .captureContext(.partner)
        .sheet(isPresented: $bulkAdd) { BulkAddPartners() }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.commaSeparatedText, .plainText, .text]) { result in
            guard case .success(let url) = result else { return }
            importCSV(url)
        }
        .fileExporter(isPresented: $exporting, document: DataFile(data: Backup.partnersCSV(partners)),
                      contentType: .commaSeparatedText, defaultFilename: "partners.csv") { _ in }
        .notice("Import", message: $message)
    }

    private func newPartner() {
        let p = Partner()
        p.stageValue = .idea
        ctx.insert(p)
        router.push(.partner(p))
    }

    private func importCSV(_ url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let text = (try? String(contentsOf: url, encoding: .utf8)) ?? (try? String(contentsOf: url, encoding: .isoLatin1)) ?? ""
        let n = Backup.importPartners(text, ctx)
        message = "Added \(n) new name\(n == 1 ? "" : "s"). Names already in your list were skipped."
    }
}

// MARK: - Gifts

struct GiftDetail: View {
    @Environment(Router.self) private var router
    @Bindable var gift: Gift
    @Query private var partners: [Partner]

    var body: some View {
        DetailPage(aside: "A gift", title: Money.text(gift.amountCents, gift.currency)) {
            FormBlock("Gift") {
                MoneyRow(title: "Amount", cents: $gift.amountCents, currency: gift.currency)
                SelectRow("Currency", selection: $gift.currency) {
                    Text("Euro").tag("EUR")
                    Text("NZ dollar").tag("NZD")
                }
                DateRow(title: "Date", date: $gift.date)
                ToggleRow("Part of a monthly gift", isOn: $gift.recurring)
                TextRow("Via (bank, YWAM, cash…)", text: $gift.via)
                OptionalDateRow(title: "Thanked", date: $gift.thankedAt, defaultDate: .now)
            }
            if let p = partners.first(where: { $0.id == gift.partnerID }) {
                FormBlock("From") { LinkedRow(record: .partner(p), rule: false) }
            }
            FormBlock("Notes") {
                TextRow("Notes", text: $gift.notes, vertical: true, lines: 2...8)
            }
            LinksBlock(record: .gift(gift))
            DeleteButton(item: gift)
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
        PaperSheet(title: "Add names", save: "Add", onSave: add) {
            FormBlock("One name per line",
                      footer: "Family, church, friends, school, work, sport, neighbours, YWAM, your phone contacts. Write everyone down; you don't decide for someone else whether they'll give.") {
                TextEditor(text: $text)
                    .type(.bodyBold)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 240)
                    .padding(8)
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Palette.chipRule, lineWidth: Metrics.outline))
                    .padding(.vertical, 8)
            }
            SelectRow("Category for all", selection: $category) {
                ForEach(PartnerCategory.allCases) { Text($0.title).tag($0) }
            }
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

#if DEBUG
/// Sample partners for simulator screenshots (debug builds only, and only when there are none).
enum DemoData {
    static func addPartners(_ ctx: ModelContext) {
        let today = Calendar.current.startOfDay(for: .now)
        func add(_ name: String, _ stage: PartnerStage, _ category: PartnerCategory, monthly: Int = 0, follow: Int? = nil,
                 step: String = "") {
            let p = Partner()
            p.name = name
            p.stageValue = stage
            p.categoryValue = category
            p.monthlyCents = monthly
            p.phone = "06 12345678"
            p.nextStep = step
            p.nextFollowUp = follow.flatMap { Calendar.current.date(byAdding: .day, value: $0, to: today) }
            if stage.countsAsSupport { p.thankedAt = today }
            ctx.insert(p)
        }
        add("Anna Jansen", .thinking, .a, follow: -1, step: "Check in about her decision")
        add("Familie Bakker", .giving, .a, monthly: 5_000)
        add("Kerk De Ark", .giving, .k, monthly: 40_000)
        add("Mark & Lisa de Boer", .giving, .b, monthly: 2_500)
        add("Pieter de Vries", .toAsk, .b, follow: 0)
        add("Sophie Ouwens", .idea, .c)
        try? ctx.save()
    }
}
#endif
