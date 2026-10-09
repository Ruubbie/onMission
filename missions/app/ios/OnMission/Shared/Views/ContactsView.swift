import SwiftUI
import SwiftData

/// Useful people and offices: YWAM staff, the gemeente, the insurer, the GP.
struct ContactsView: View {
    @Environment(\.modelContext) private var ctx
    @Query(sort: \Contact.name) private var contacts: [Contact]
    @State private var search = ""
    @State private var opened: Contact?

    private var visible: [Contact] {
        guard !search.isEmpty else { return contacts }
        return contacts.filter {
            $0.name.localizedCaseInsensitiveContains(search) || $0.organisation.localizedCaseInsensitiveContains(search)
                || $0.role.localizedCaseInsensitiveContains(search) || $0.notes.localizedCaseInsensitiveContains(search)
        }
    }

    var body: some View {
        List {
            ForEach(visible) { c in
                CardLink { ContactDetail(contact: c) } label: { ContactRow(contact: c) }
                    .brutalRow(top: 4, bottom: 6)
                    .swipeActions {
                        Button("Delete", role: .destructive) { Store.delete(c, in: ctx) }
                    }
            }
            if visible.isEmpty {
                BrutalEmptyState(symbol: "person.crop.rectangle.stack.fill", title: contacts.isEmpty ? "No contacts yet" : "No match",
                                 message: contacts.isEmpty ? "YWAM Queenstown, the gemeente, your insurer, the GP: everyone you need to reach." : "",
                                 accent: .grey)
                    .brutalRow()
            }
            Color.clear.frame(height: 80).brutalRow()
        }
        .brutalList()
        .brutalSearch(text: $search)
        .navigationTitle("Contacts")
        .addButton(newContact)
        .navigationDestination(item: $opened) { ContactDetail(contact: $0) }
    }

    private func newContact() {
        let c = Contact()
        ctx.insert(c)
        opened = c
    }
}

private struct ContactRow: View {
    let contact: Contact

    var body: some View {
        HStack(spacing: Metrics.m) {
            Text(initials)
                .font(Typeface.heading(15))
                .foregroundStyle(Palette.ink)
                .frame(width: 38, height: 38)
                .background(RoundedRectangle(cornerRadius: Metrics.radiusSmall).fill(Accent.sand.color))
                .overlay(RoundedRectangle(cornerRadius: Metrics.radiusSmall).strokeBorder(Palette.ink, lineWidth: Metrics.borderThin))
            VStack(alignment: .leading, spacing: 2) {
                Text(contact.displayTitle)
                    .font(Typeface.body(16, weight: .bold))
                    .foregroundStyle(Palette.ink)
                let line = [contact.role, contact.organisation].filter { !$0.isEmpty }.joined(separator: " · ")
                if !line.isEmpty {
                    Text(line).font(Typeface.body(13)).foregroundStyle(Palette.muted).lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(Metrics.m)
        .brutalBox(radius: Metrics.radiusSmall, shadow: Metrics.shadowSmall)
    }

    private var initials: String {
        let letters = contact.name.split(separator: " ").prefix(2).compactMap(\.first)
        return letters.isEmpty ? "?" : String(letters).uppercased()
    }
}

struct ContactDetail: View {
    @Environment(\.openURL) private var openURL
    @Bindable var contact: Contact

    var body: some View {
        Form {
            FormHeroRow(fill: Accent.sand.color) {
                TextField("Name", text: $contact.name)
                    .font(Typeface.heading(22))
                    .foregroundStyle(Palette.ink)
                HStack(spacing: Metrics.m) {
                    if let url = PhoneLinks.call(contact.phone) {
                        IconButton(symbol: "phone.fill", accent: .green, label: "Call") { openURL(url) }
                    }
                    if let url = PhoneLinks.whatsApp(contact.phone) {
                        IconButton(symbol: "message.fill", accent: .lime, label: "WhatsApp") { openURL(url) }
                    }
                    if let url = PhoneLinks.email(contact.email) {
                        IconButton(symbol: "envelope.fill", accent: .yellow, label: "Email") { openURL(url) }
                    }
                }
            }
            Section {
                TextField("Role (staff, school leader, advisor…)", text: $contact.role)
                TextField("Organisation", text: $contact.organisation)
                TextField("Phone", text: $contact.phone).keyboardType(.phonePad)
                TextField("Email", text: $contact.email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                TextField("Address", text: $contact.address, axis: .vertical)
            } header: { FormHeader("Contact") }
            Section {
                TextField("Notes", text: $contact.notes, axis: .vertical).lineLimit(3...12)
            } header: { FormHeader("Notes") }
            LinksSection(record: .contact(contact))
            Section { DeleteRecordButton(item: contact) }
        }
        .brutalForm()
        .navigationTitle(contact.displayTitle)
        .navigationBarTitleDisplayMode(.inline)
    }
}
