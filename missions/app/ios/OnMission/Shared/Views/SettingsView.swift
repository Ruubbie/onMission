import SwiftUI
import SwiftData
import UniformTypeIdentifiers

// MARK: - Settings (handoff §7): your mission, this iPhone, your account

struct SettingsView: View {
    @Environment(\.modelContext) private var ctx
    @Environment(Router.self) private var router
    @Query private var settingsList: [MissionSettings]

    @State private var exporting = false
    @State private var importing = false
    @State private var backupMessage: String?
    @State private var backupFile = DataFile(data: Data())
    @State private var notificationsOn = false

    var body: some View {
        let s = settingsList.first ?? MissionSettings()
        Screen(posterHeight: 306) {
            Hand("Your mission").rise(0).at(24, 106)
            Lines(dayMonth(s.departureDate), .disp(150), lineHeight: 0.8)
                .rise(1)
                .at(18, 134)
            CapLine("Leaving for\n\(s.destination)").rise(2).at(24, 272)
            LineArt(drawing: Art.planeLoop).at(236, 266)
        } sheet: {
            SheetScroll {
                if let s = settingsList.first {
                    MissionBlock(settings: s)
                }
                FormBlock("This iPhone", footer: "Backups are a JSON file with all your records (not the vault files; those are on your server). Restoring adds to what's here.") {
                    SyncRow()
                    ToggleRow("Reminders at 9:00", isOn: Binding(get: { notificationsOn }, set: { on in
                        notificationsOn = on
                        guard on else { return }
                        Task {
                            notificationsOn = await Reminders.requestPermission()
                            await Reminders.refresh(ctx)
                        }
                    }))
                    ActionRow(title: "Export a backup", icon: .download) {
                        backupFile = DataFile(data: Backup.export(ctx))
                        exporting = true
                    }
                    ActionRow(title: "Restore from a backup", icon: .archive) { importing = true }
                }
                AccountBlock()
                FormBlock("About") {
                    Text("You do this with God. This app helps you plan, remember and follow up; it doesn't speak for Him.")
                        .type(.hand(24))
                        .foregroundStyle(Palette.tomato)
                        .rotationEffect(.degrees(-1.5))
                        .padding(.vertical, 12)
                    Text("Icons: Lucide (ISC licence), with motion from lucide-animated by pqoqubbw (MIT). Type: Archivo and Caveat (SIL Open Font License).")
                        .type(.small)
                        .foregroundStyle(Palette.inkFaint)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .task {
            _ = Store.settings(ctx)
            notificationsOn = await Reminders.isAuthorized()
        }
        .fileExporter(isPresented: $exporting, document: backupFile, contentType: .json,
                      defaultFilename: "on-mission-backup-\(DayFormat.string(.now)).json") { result in
            if case .success = result { router.showToast("Backup saved to Files") }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            guard case .success(let url) = result else { return }
            restore(url)
        }
        .notice("Backup", message: $backupMessage)
    }

    /// "15.12".
    private func dayMonth(_ d: Date) -> String {
        let c = Calendar.current.dateComponents([.day, .month], from: d)
        return String(format: "%02d.%02d", c.day ?? 0, c.month ?? 0)
    }

    private func restore(_ url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        do {
            let n = try Backup.restore(Data(contentsOf: url), ctx)
            backupMessage = "Restored \(n) records."
        } catch {
            backupMessage = "Could not read that backup: \(error.localizedDescription)"
        }
    }
}

// MARK: - Your mission

private struct MissionBlock: View {
    @Bindable var settings: MissionSettings

    var body: some View {
        FormBlock("Mission", footer: "Your passport must be valid until at least \(longDate(settings.passportMustLast)). NZ$ 4,200 is about \(euros(Money.cents(fromEuros: 4200 / max(settings.nzdPerEur, 0.1)))).") {
            LabeledRow("Your first name") {
                TextField("", text: Binding(get: { settings.ownerName }, set: { settings.ownerName = $0 }),
                          prompt: Text("For the greeting").foregroundStyle(Palette.inkFaint))
                    .type(TypeStyle(size: 15.5, wght: 800, relativeTo: .body))
                    .foregroundStyle(Palette.tomatoInk)
                    .multilineTextAlignment(.trailing)
                    .textContentType(.givenName)
            }
            LabeledRow("Destination") {
                TextField("", text: Binding(get: { settings.destination }, set: { settings.destination = $0 }),
                          prompt: Text("Queenstown, NZ").foregroundStyle(Palette.inkFaint))
                    .type(TypeStyle(size: 15.5, wght: 800, relativeTo: .body))
                    .foregroundStyle(Palette.tomatoInk)
                    .multilineTextAlignment(.trailing)
            }
            DateRow(title: "Leaving", date: $settings.departureDate)
            MoneyRow(title: "Monthly target", cents: $settings.supportTargetMonthlyCents)
            MoneyRow(title: "Monthly minimum", cents: $settings.supportMinimumMonthlyCents)
            MoneyRow(title: "Average monthly gift", cents: $settings.averageGiftCents)
            LabeledRow("NZ dollars per euro") {
                TextField("1.85", value: $settings.nzdPerEur, format: .number)
                    .type(TypeStyle(size: 15.5, wght: 800, relativeTo: .body))
                    .foregroundStyle(Palette.tomatoInk)
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.decimalPad)
                    .frame(maxWidth: 100)
            }
        }
    }
}

// MARK: - Sync

/// Sync with a status line. The icon spins once when Settings opens, and keeps spinning while it syncs;
/// "Synced just now" pops in after.
private struct SyncRow: View {
    @Environment(\.modelContext) private var ctx
    @MainActor private var sync: SyncEngine { SyncEngine.shared }
    @State private var spin = 0
    @State private var pop = 0

    var body: some View {
        Button {
            guard sync.isLoggedIn, !sync.isSyncing else { return }
            Task {
                await sync.sync(ctx)
                pop += 1
            }
        } label: {
            FieldRow {
                Clock(trigger: spin, duration: 0.9) { t in
                    AnimatedIcon(.sync, size: 20)
                        .rotationEffect(.degrees(t < 0.9 ? 360 * Ease(0.5, 0, 0.3, 1)(t / 0.9) : 0))
                }
                .rotationEffect(.degrees(sync.isSyncing ? 360 : 0))
                .animation(sync.isSyncing ? .linear(duration: 0.9).repeatForever(autoreverses: false) : .default, value: sync.isSyncing)
                .foregroundStyle(Palette.tomato)
                .frame(width: 20, height: 20)
                Text("Sync").type(.bodyBold).foregroundStyle(Palette.ink)
                Spacer(minLength: 8)
                Text(status)
                    .type(TypeStyle(size: 15.5, wght: 800, relativeTo: .body))
                    .foregroundStyle(sync.lastError != nil ? Palette.tomatoInk : Palette.inkSoft)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .pop(pop, to: 1.12)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint(sync.isLoggedIn ? "Syncs now" : "")
        .onAppear { Motion.after(0.6) { spin += 1 } }
    }

    @MainActor private var status: String {
        if sync.isSyncing { return "Syncing…" }
        if !sync.isLoggedIn { return "Only on this iPhone" }
        if sync.lastError != nil { return "Didn't work" }
        if let last = sync.lastSync {
            return Date.now.timeIntervalSince(last) < 60 ? "Synced just now" : "Synced \(relativeDate(last))"
        }
        return "Not synced yet"
    }
}

// MARK: - Account

private struct AccountBlock: View {
    @Environment(\.modelContext) private var ctx
    @MainActor private var sync: SyncEngine { SyncEngine.shared }

    @State private var server = ""
    @State private var email = ""
    @State private var password = ""
    @State private var busy = false
    @State private var message: String?
    @State private var devices: [API.Device] = []
    @State private var devicesError: String?
    @State private var confirmSignOut = false

    var body: some View {
        Group {
            if sync.isLoggedIn {
                signedIn
                devicesBlock
            } else {
                signIn
            }
        }
        .onAppear {
            if server.isEmpty { server = sync.serverURL }
            if email.isEmpty { email = sync.email }
        }
        .task(id: sync.isLoggedIn) {
            if sync.isLoggedIn { await loadDevices() }
        }
    }

    @MainActor private var signIn: some View {
        FormBlock("Account", footer: "Everything is saved on this iPhone first. Signed in, your iPhone and the Windows helper stay in sync and your vault files are backed up.") {
            TextRow("Server, e.g. api.92-5-233-11.sslip.io", text: $server, keyboard: .URL, plain: true)
            TextRow("Email", text: $email, keyboard: .emailAddress, plain: true)
                .textContentType(.username)
            FieldRow {
                SecureField("", text: $password, prompt: Text("Password").foregroundStyle(Palette.inkFaint))
                    .type(.bodyBold)
                    .foregroundStyle(Palette.ink)
                    .textContentType(.password)
            }
            if let message {
                Text(message).type(.small).foregroundStyle(Palette.tomatoInk).padding(.top, 8)
            }
            Button {
                Task { await logIn() }
            } label: {
                Text(busy ? "Signing in…" : "Sign in").frame(maxWidth: .infinity)
            }
            .buttonStyle(.wide)
            .disabled(busy || server.isEmpty || email.isEmpty || password.isEmpty)
            .opacity(busy || server.isEmpty || email.isEmpty || password.isEmpty ? 0.45 : 1)
            .padding(.top, 14)
        }
    }

    @MainActor private var signedIn: some View {
        FormBlock("Account", footer: "The app syncs when it opens and every 2 minutes while it's open.") {
            LabeledRow("Signed in as \(sync.email)") {
                Button("Sign out") { confirmSignOut = true }
                    .type(TypeStyle(size: 15.5, wght: 800, relativeTo: .body))
                    .foregroundStyle(Palette.tomatoInk)
            }
            ValueRow(label: "Server", value: sync.serverURL)
            if let error = sync.lastError {
                Text(error).type(.small).foregroundStyle(Palette.tomatoInk).padding(.top, 8)
            }
            ActionRow(title: "Test the connection", icon: .link) {
                Task { message = await sync.testConnection() }
            }
            if let message {
                Text(message).type(.small).foregroundStyle(Palette.inkSoft).padding(.top, 8)
            }
        }
        .confirm("Sign out?", isPresented: $confirmSignOut, message: "Your records stay on this iPhone.", button: "Sign out") {
            Task {
                await sync.logout()
                devices = []
                password = ""
            }
        }
    }

    @MainActor private var devicesBlock: some View {
        FormBlock("Signed-in devices", footer: "Lost a phone or laptop? Sign it out here; it can't sync any more after that.") {
            ForEach(Array(devices.enumerated()), id: \.element.id) { index, d in
                DeviceRow(device: d, rule: index < devices.count - 1) {
                    Task { await revoke(d.id) }
                }
            }
            if devices.isEmpty && devicesError == nil {
                Text("Loading…").type(.small).foregroundStyle(Palette.inkFaint).padding(.vertical, 12)
            }
            if let devicesError {
                Text(devicesError).type(.small).foregroundStyle(Palette.tomatoInk).padding(.vertical, 8)
            }
        }
    }

    @MainActor
    private func logIn() async {
        busy = true
        message = nil
        defer { busy = false }
        do {
            try await sync.login(server: server.trimmingCharacters(in: .whitespacesAndNewlines),
                                 email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                                 password: password)
            password = ""
            await sync.sync(ctx)
        } catch {
            message = error.localizedDescription
        }
    }

    @MainActor
    private func loadDevices() async {
        do {
            devices = try await sync.devices()
            devicesError = nil
        } catch {
            devicesError = "Could not load devices: \(error.localizedDescription)"
        }
    }

    @MainActor
    private func revoke(_ id: String) async {
        do {
            try await sync.revokeDevice(id)
            await loadDevices()
        } catch {
            devicesError = "Could not sign that device out: \(error.localizedDescription)"
        }
    }
}

private struct DeviceRow: View {
    let device: API.Device
    var rule = true
    let onRevoke: () -> Void
    @State private var confirming = false

    var body: some View {
        Row(rule: rule) {
            AnimatedIcon(icon, size: 22).foregroundStyle(Palette.tomato).frame(width: 28)
            RowText(title: device.name + (device.current ? " (this iPhone)" : ""),
                    subtitle: device.lastSeenAt.map { "Seen \(relativeDate($0))" } ?? device.platform)
            if !device.current {
                Button("Sign out") { confirming = true }
                    .buttonStyle(.outlinedSmall)
            }
        }
        .confirm("Sign out \(device.name)?", isPresented: $confirming, button: "Sign out", action: onRevoke)
    }

    private var icon: Icon {
        let p = device.platform.lowercased()
        if p.contains("ios") || p.contains("iphone") { return .device }
        return .laptop
    }
}
