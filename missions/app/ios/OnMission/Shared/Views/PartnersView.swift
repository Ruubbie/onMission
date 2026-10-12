import SwiftUI
import SwiftData
import UniformTypeIdentifiers

// MARK: - Moving a partner along

extension PartnerStage {
    /// The next stage on the usual path.
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

    /// The stop on the six-stop path (List · Ask · Asked · Thinking · Yes · Giving).
    var pathIndex: Int {
        switch self {
        case .idea: 0
        case .toAsk: 1
        case .asked: 2
        case .thinking, .declined, .paused: 3
        case .committed: 4
        case .giving: 5
        }
    }

    static let path: [PartnerStage] = [.idea, .toAsk, .asked, .thinking, .committed, .giving]
    static let pathLabels = ["List", "Ask", "Asked", "Thinking", "Yes", "Giving"]
}

extension PartnerCategory {
    /// "close friend" for the handwritten aside.
    var aside: String {
        switch self {
        case .a: "close friend"
        case .b: "good contact"
        case .c: "looser contact"
        case .k: "church or group"
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

    /// "Gives €50 a month", "Thinking it over", "To ask".
    var line: String {
        if monthlyCents > 0 && stageValue.countsAsSupport { return "Gives \(Money.text(monthlyCents, currency)) a month" }
        switch stageValue {
        case .idea: return "On your list"
        case .toAsk: return "To ask"
        case .asked: return nextStep.isEmpty ? "Asked" : nextStep
        case .thinking: return "Thinking it over"
        case .committed: return "Committed"
        case .giving: return "Giving"
        case .declined: return "Not now"
        case .paused: return "Paused"
        }
    }
}

// MARK: - People tab

/// People (handoff §5): monthly support big on tomato, a walker up the trail to the percentage;
/// the people waiting on you, each with one action.
struct PeopleView: View {
    @Environment(\.modelContext) private var ctx
    @Environment(Router.self) private var router
    @Environment(\.entry) private var entry
    @Query(sort: \Partner.name) private var partners: [Partner]
    @Query private var gifts: [Gift]
    @Query private var settingsList: [MissionSettings]

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
            TrailArt(fraction: fraction, trigger: entry).at(0, 252)
        } sheet: {
            SheetScroll {
                if waiting.isEmpty {
                    SectionHeader("Waiting on you")
                    EmptyRow(title: "Nobody's waiting on you", message: "Nice. Everyone has heard from you.")
                } else {
                    SectionHeader("Waiting on you", count: waiting.count)
                    ForEach(Array(waiting.prefix(3).enumerated()), id: \.element.id) { index, p in
                        WaitingRow(partner: p, gifts: gifts, rule: index < min(waiting.count, 3) - 1)
                            .transition(.asymmetric(insertion: .opacity, removal: .move(edge: .trailing).combined(with: .opacity)))
                    }
                    if waiting.count > 3 {
                        MoreNote(text: "+\(waiting.count - 3) more waiting")
                    }
                }
                MoreLink(title: "All \(partners.count) people") { router.push(.allPeople) }
            }
        }
        .captureContext(.partner)
    }

    /// The "Needs you" group: follow-ups due and thanks owed.
    private func waitingList(_ i: Insights) -> [Partner] {
        var out: [Partner] = []
        for p in i.toThank + i.followUps where !out.contains(where: { $0.id == p.id }) {
            out.append(p)
        }
        return out
    }
}

/// The trail up the mountain: the walker travels to the support percentage over 1.5s on entry.
private struct TrailArt: View {
    let fraction: Double
    let trigger: Int

    var body: some View {
        let path = SVG.path(Art.trailPath)
        ZStack(alignment: .topLeading) {
            LineArt(drawing: Art.trail)
            Clock(trigger: trigger, duration: 1.6) { t in
                let f = (t >= 1.5 ? 1 : Ease.outCubic(t / 1.5)) * fraction
                let spot = path.point(at: f)
                ZStack(alignment: .topLeading) {
                    SVGShape(d: Art.trailPath)
                        .trim(from: 0, to: f)
                        .stroke(Palette.cream, style: StrokeStyle(lineWidth: 3.2, lineCap: .round))
                    Circle().fill(Palette.cream)
                        .frame(width: 13, height: 13)
                        .position(spot.point)
                }
                .frame(width: 390, height: 136, alignment: .topLeading)
            }
        }
        .frame(width: 390, height: 136, alignment: .topLeading)
        .accessibilityHidden(true)
    }
}

/// A person waiting on you, with the one thing to do: Say thanks, Check in, or Ask.
private struct WaitingRow: View {
    @Environment(\.modelContext) private var ctx
    @Environment(Router.self) private var router
    let partner: Partner
    let gifts: [Gift]
    var rule = true
    @State private var thanked = false
    @State private var heart = 0

    private enum Action { case thanks, checkIn, ask }

    private var action: Action {
        if partner.needsThanks(gifts) { return .thanks }
        if partner.stageValue == .asked || partner.stageValue == .thinking { return .checkIn }
        return .ask
    }

    private var subtitle: String {
        if thanked { return "Thanked just now" }
        switch action {
        case .thanks:
            if let g = gifts.filter({ $0.partnerID == partner.id && $0.thankedAt == nil }).max(by: { $0.date < $1.date }) {
                return "Gave \(Money.text(g.amountCents, g.currency)) \(relativeDate(g.date))"
            }
            return "\(partner.stageValue.title), not thanked yet"
        case .checkIn:
            let what = partner.stageValue == .thinking ? "Thinking it over" : (partner.nextStep.isEmpty ? "Follow up" : partner.nextStep)
            guard let when = partner.nextFollowUp else { return what }
            return "\(what) · \(shortDate(when, midSentence: true))"
        case .ask:
            return "On your list to ask"
        }
    }

    private var late: Bool {
        guard action == .checkIn, let d = partner.nextFollowUp else { return false }
        return d < Calendar.current.startOfDay(for: .now)
    }

    var body: some View {
        Row(rule: rule) {
            Avatar(name: partner.displayTitle)
            RowText(title: partner.displayTitle, subtitle: subtitle, late: late)
                .contentShape(Rectangle())
                .onTapGesture { router.push(.partner(partner)) }
            switch action {
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
            case .ask:
                ShareLink(item: MessageTemplate.invite.text(for: partner)) {
                    Text("Ask")
                }
                .buttonStyle(.outlinedSmall)
            }
        }
        .accessibilityElement(children: .contain)
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
            Hand("Category \(partner.categoryValue.rawValue) · \(partner.categoryValue.aside)").rise(0).at(24, 106)
            Lines(wrapLines(partner.displayTitle, .disp(96), width: 350, maxLines: 2), .disp(96), lineHeight: 0.86, minScale: 0.5)
                .frame(width: 350, alignment: .leading)
                .rise(1)
                .at(20, 140)
            StagePath(stage: partner.stageValue) { picked in
                withAnimation(.easeOut(duration: 0.2)) { partner.move(to: picked, ctx) }
            }
            .at(0, 304)
        } sheet: {
            SheetScroll { sheet }
        }
        .captureContext(.task, linkTo: .partner(partner))
        .sheet(isPresented: $recordingGift) { RecordGiftSheet(partner: partner) }
    }

    // MARK: Sheet

    @ViewBuilder
    private var sheet: some View {
        SectionHeader("Next", count: dueLabel, color: Palette.tomatoInk)
        hero
            .id(partner.stage + (partner.needsThanks(gifts) ? "-thanks" : ""))
            .transition(.asymmetric(insertion: .offset(y: 22).combined(with: .opacity),
                                    removal: .offset(x: 40).combined(with: .opacity)))
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
        guard partner.stageValue.isOpen, let d = partner.nextFollowUp else { return "" }
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        if d < today { return "Was due \(shortDate(d, midSentence: true))" }
        if cal.isDateInToday(d) { return "Today" }
        let days = cal.dateComponents([.day], from: today, to: d).day ?? 0
        if days >= 7 && days % 7 == 0 { return "In \(days / 7) week\(days == 7 ? "" : "s")" }
        return shortDate(d)
    }

    @ViewBuilder
    private var hero: some View {
        let thanks = partner.needsThanks(gifts)
        let late = (partner.nextFollowUp.map { $0 < Calendar.current.startOfDay(for: .now) } ?? false) && partner.stageValue.isOpen
        switch partner.stageValue {
        case .idea:
            HeroCard(title: "Ready to ask \(who)?", subtitle: "On your list. Plan when you'll ask.") {
                ActionButton(title: "Plan to ask", icon: .arrow) { withAnimation { partner.move(to: .toAsk, ctx) } }
                share("Message", .invite, filled: false)
            }
        case .toAsk:
            HeroCard(title: "Invite \(who) for coffee", subtitle: "Or a call. Tell your story first, then ask.") {
                share("Send invite", .invite, filled: true)
                ActionButton(title: "I asked", style: .outlined) { withAnimation { partner.move(to: .asked, ctx) } }
            }
        case .asked:
            HeroCard(title: partner.nextStep.isEmpty ? "Log the meeting" : partner.nextStep,
                     subtitle: "After you've met, log it: a follow-up is planned for you.", late: late) {
                ActionButton(title: "Log it", icon: .check) {
                    partner.lastContact = Calendar.current.startOfDay(for: .now)
                    withAnimation { partner.move(to: .thinking, ctx) }
                }
                share("Thanks text", .thanksAfterMeeting, filled: false)
            }
        case .thinking:
            HeroCard(title: partner.nextStep.isEmpty ? "Check in about the decision" : partner.nextStep,
                     subtitle: "\(partner.firstName.isEmpty ? "They're" : partner.firstName + " is") still thinking it over.", late: late) {
                if let url = PhoneLinks.call(partner.phone) {
                    ActionButton(title: "Call", icon: .phone) {
                        openURL(url)
                        router.openCheckIn(CheckInRequest(partner: partner))
                    }
                } else {
                    ActionButton(title: "Check in", icon: .phone) { router.openCheckIn(CheckInRequest(partner: partner)) }
                }
                share("Message", .followUp, filled: false)
            }
        case .committed, .giving:
            if thanks {
                HeroCard(title: "Say thanks and set the amount", subtitle: "\(who.capitalized) said yes! Thank them while it's fresh.") {
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
            } else {
                HeroCard(title: partner.monthlyCents > 0 ? "Gives \(Money.text(partner.monthlyCents, partner.currency)) a month" : "A partner",
                         subtitle: "Record gifts as they come in.") {
                    ActionButton(title: "Record a gift", icon: .gift) { recordingGift = true }
                }
            }
        case .declined, .paused:
            HeroCard(title: "Catch up later", subtitle: "No pressure. You can ask again another time.") {
                ActionButton(title: "Ask again", style: .outlined) { withAnimation { partner.move(to: .toAsk, ctx) } }
                share("Write a note", .invite, filled: false)
            }
        }
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
            SelectRow("Stage", selection: Binding(get: { partner.stageValue }, set: { new in withAnimation { partner.move(to: new, ctx) } })) {
                ForEach(PartnerStage.allCases) { Text($0.title).tag($0) }
            }
        }
        if partner.stageValue.isOpen {
            FormBlock("Next step", footer: "From three days before the follow-up date, they show under Waiting on you and on Today.") {
                TextRow("What's next (call, coffee, send pitch…)", text: $partner.nextStep)
                OptionalDateRow(title: "Follow up on", date: $partner.nextFollowUp)
                QuickDates(date: $partner.nextFollowUp,
                           options: [.init(title: "Tomorrow", days: 1), .init(title: "In 3 days", days: 3),
                                     .init(title: "Next week", days: 7), .init(title: "In 2 weeks", days: 14)])
                OptionalDateRow(title: "Last contact", date: $partner.lastContact)
            }
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
                        AnimatedIcon(.templates, size: 20).foregroundStyle(Palette.tomato)
                        Text(t.title).type(.bodyBold).foregroundStyle(Palette.ink)
                        Spacer(minLength: 0)
                    }
                }
            }
            Menu {
                ForEach(MessageTemplate.allCases) { t in ShareLink(t.title, item: t.text(for: partner)) }
            } label: {
                FieldRow {
                    AnimatedIcon(.more, size: 20).foregroundStyle(Palette.tomato)
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

/// The six stops from List to Giving. The walker slides to their stage on entry (1s) and a halo pulses;
/// a step forward springs, and Not now dims the path. Tap a stop to set the stage.
private struct StagePath: View {
    let stage: PartnerStage
    let onPick: (PartnerStage) -> Void
    @Environment(\.entry) private var entry
    @State private var pos: CGFloat = 0
    @State private var halo = 0

    private func x(_ i: CGFloat) -> CGFloat { 40 + i * 62 }

    var body: some View {
        let out = stage == .declined || stage == .paused
        ZStack(alignment: .topLeading) {
            SVGShape(d: "M40 26 L350 26")
                .stroke(Palette.cream, style: StrokeStyle(lineWidth: 2.4, lineCap: .round, dash: [1, 8]))
            Path { p in
                p.move(to: CGPoint(x: 40, y: 26))
                p.addLine(to: CGPoint(x: x(pos), y: 26))
            }
            .stroke(Palette.cream, style: StrokeStyle(lineWidth: 3.4, lineCap: .round))
            ForEach(0..<6, id: \.self) { i in
                let reached = x(CGFloat(i)) <= x(pos) + 0.5
                Circle()
                    .fill(reached ? Palette.cream : Palette.tomato)
                    .overlay(Circle().stroke(Palette.cream, lineWidth: 2.4))
                    .frame(width: 11, height: 11)
                    .position(x: x(CGFloat(i)), y: 26)
                Button { onPick(PartnerStage.path[i]) } label: {
                    Text(PartnerStage.pathLabels[i].uppercased())
                        .type(TypeStyle(size: 11.5, wght: 800, tracking: 0.09, relativeTo: nil))
                        .foregroundStyle(Palette.cream)
                        .opacity(i == stage.pathIndex ? 1 : 0.5)
                        .fixedSize()
                        .frame(width: 60, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .position(x: x(CGFloat(i)), y: 56)
                .accessibilityLabel(PartnerStage.path[i].title)
                .accessibilityAddTraits(i == stage.pathIndex ? .isSelected : [])
            }
            Circle()
                .stroke(Palette.cream, lineWidth: 2)
                .frame(width: 22, height: 22)
                .keyframeAnimator(initialValue: HaloValue(), trigger: halo) { view, v in
                    view.scaleEffect(v.scale).opacity(v.opacity)
                } keyframes: { _ in
                    KeyframeTrack(\.scale) {
                        MoveKeyframe(1)
                        LinearKeyframe(2.6, duration: 0.9, timingCurve: .bezier(startControlPoint: UnitPoint(x: 0.2, y: 0.8), endControlPoint: UnitPoint(x: 0.2, y: 1)))
                    }
                    KeyframeTrack(\.opacity) {
                        MoveKeyframe(0.9)
                        LinearKeyframe(0, duration: 0.9)
                    }
                }
                .position(x: x(pos), y: 26)
            Circle().fill(Palette.cream)
                .frame(width: 22, height: 22)
                .position(x: x(pos), y: 26)
                .accessibilityHidden(true)
        }
        .frame(width: 390, height: 86, alignment: .topLeading)
        .opacity(out ? 0.35 : 1)
        .animation(.easeOut(duration: 0.6), value: out)
        .onChange(of: entry) { _, _ in walkIn() }
        .onAppear { walkIn() }
        .onChange(of: stage) { old, new in
            let target = CGFloat(new.pathIndex)
            if new.pathIndex > old.pathIndex {
                Motion.after(0.5) {
                    withAnimation(.spring(k: 170, c: 14).rm) { pos = target }
                    Motion.after(0.8) { halo += 1 }
                }
            } else {
                withAnimation(.easeOut(duration: 0.4)) { pos = target }
                Motion.after(0.5) { halo += 1 }
            }
        }
        .sensoryFeedback(.selection, trigger: stage)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Stage: \(stage.title)")
    }

    private func walkIn() {
        var t = Transaction()
        t.disablesAnimations = true
        withTransaction(t) { pos = 0 }
        Motion.after(0.2) {
            withAnimation(.curve(0.33, 1, 0.68, 1, 1).rm) { pos = CGFloat(stage.pathIndex) }
            Motion.after(1) { halo += 1 }
        }
    }
}

private struct HaloValue {
    var scale: CGFloat = 1
    var opacity: Double = 0
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
            LineArt(drawing: Art.group).at(206, 146)
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

/// Record a gift that came in (a sheet).
private struct RecordGiftSheet: View {
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss
    let partner: Partner
    @State private var cents = 0
    @State private var recurring = false

    var body: some View {
        CreamSheet(title: "Gift from \(partner.displayTitle)", save: "Save", saveDisabled: cents <= 0, onSave: {
            Automations.recordGift(for: partner, cents: cents, recurring: recurring, ctx)
            dismiss()
        }) {
            FormBlock("", footer: "Recording a gift adds a thank-you task when it's needed.") {
                MoneyRow(title: "Amount", cents: $cents, currency: partner.currency)
                ToggleRow("Part of a monthly gift", isOn: $recurring)
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
        CreamSheet(title: "Add names", save: "Add", onSave: add) {
            FormBlock("One name per line",
                      footer: "Family, church, friends, school, work, sport, neighbours, YWAM, your phone contacts. Write everyone down; you don't decide for someone else whether they'll give.") {
                TextEditor(text: $text)
                    .type(.bodyBold)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 240)
                    .padding(8)
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Palette.chipRule, lineWidth: 1.6))
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
