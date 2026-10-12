import SwiftUI
import SwiftData

// MARK: - Contacts: useful people and offices (YWAM staff, the gemeente, the insurer, the GP)

struct ContactsPage: View {
    @Environment(\.modelContext) private var ctx
    @Environment(Router.self) private var router
    @Environment(\.openURL) private var openURL
    @Query(sort: \Contact.name) private var contacts: [Contact]
    @State private var search = ""

    var body: some View {
        let visible = search.isEmpty ? contacts : contacts.filter {
            $0.name.localizedCaseInsensitiveContains(search) || $0.organisation.localizedCaseInsensitiveContains(search)
                || $0.role.localizedCaseInsensitiveContains(search) || $0.notes.localizedCaseInsensitiveContains(search)
        }
        Screen(posterHeight: 306, sheetTop: 16) {
            Hand("Who to call").rise(0).at(24, 106)
            Lines("\(contacts.count)", .disp(184), lineHeight: 0.78).rise(1).at(18, 136)
            CapLine("Offices and people\nto reach").rise(2).at(24, 292)
            LineArt(drawing: Art.card).at(244, 150)
        } sheet: {
            if contacts.count > 6 {
                SearchField(text: $search, prompt: "Search \(contacts.count) contacts")
            }
            SheetScroll {
                ForEach(Array(visible.enumerated()), id: \.element.id) { index, c in
                    Row(rule: index < visible.count - 1) {
                        Avatar(name: c.displayTitle)
                        RowText(title: c.displayTitle, subtitle: c.line)
                            .contentShape(Rectangle())
                            .onTapGesture { router.push(.record(.contact(c))) }
                        if let url = PhoneLinks.call(c.phone) {
                            RoundButton(icon: .phone, label: "Call \(c.displayTitle)", ink: Palette.tomato) { openURL(url) }
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityAction { router.push(.record(.contact(c))) }
                    .contextMenu {
                        Button("Delete", role: .destructive) { Store.delete(c, in: ctx) }
                    }
                }
                if visible.isEmpty {
                    EmptyRow(title: contacts.isEmpty ? "No contacts yet" : "Nobody by that name",
                             message: contacts.isEmpty ? "YWAM Queenstown, the gemeente, your insurer, the GP: everyone you need to reach." : "Try another word.")
                }
                FormBlock("") {
                    ActionRow(title: "New contact", icon: .user) { newContact() }
                }
            }
        }
    }

    private func newContact() {
        let c = Contact()
        ctx.insert(c)
        router.push(.record(.contact(c)))
    }
}

extension Contact {
    /// "Staff · YWAM Queenstown".
    var line: String { [role, organisation].filter { !$0.isEmpty }.joined(separator: " · ") }
}

struct ContactDetail: View {
    @Environment(\.openURL) private var openURL
    @Bindable var contact: Contact

    var body: some View {
        DetailPage(aside: contact.role.isEmpty ? "A contact" : contact.role, title: contact.displayTitle, cap: contact.organisation) {
            let call = PhoneLinks.call(contact.phone)
            let app = PhoneLinks.whatsApp(contact.phone)
            let mail = PhoneLinks.email(contact.email)
            if call != nil || app != nil || mail != nil {
                HStack(spacing: 8) {
                    if let call { ActionButton(title: "Call", icon: .phone) { openURL(call) } }
                    if let app { ActionButton(title: "WhatsApp", icon: .message, style: .outlined) { openURL(app) } }
                    if let mail { ActionButton(title: "Email", icon: .mail, style: .outlined) { openURL(mail) } }
                }
                .padding(.bottom, 4)
            }
            FormBlock("Contact") {
                TextRow("Name", text: $contact.name)
                TextRow("Role (staff, school leader, advisor…)", text: $contact.role)
                TextRow("Organisation", text: $contact.organisation)
                TextRow("Phone", text: $contact.phone, keyboard: .phonePad)
                TextRow("Email", text: $contact.email, keyboard: .emailAddress, plain: true)
                TextRow("Address", text: $contact.address, vertical: true, lines: 1...4)
            }
            FormBlock("Notes") {
                TextRow("Notes", text: $contact.notes, vertical: true, lines: 3...12)
            }
            LinksBlock(record: .contact(contact))
            DeleteButton(item: contact)
        }
    }
}
