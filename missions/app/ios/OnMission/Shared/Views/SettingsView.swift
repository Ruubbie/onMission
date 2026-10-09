import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.modelContext) private var ctx
    @Query private var settingsList: [MissionSettings]

    @State private var exporting = false
    @State private var importing = false
    @State private var backupMessage: String?
    @State private var backupFile = DataFile(data: Data())
    @State private var notificationsOn = false

    var body: some View {
        Form {
            if let s = settingsList.first {
                MissionSection(settings: s)
            }
            AccountSection()
            Section {
                Toggle("Reminders at 9:00", isOn: Binding(get: { notificationsOn }, set: { on in
                    notificationsOn = on
                    guard on else { return }
                    Task {
                        notificationsOn = await Reminders.requestPermission()
                        await Reminders.refresh(ctx)
                    }
                }))
                .tint(Accent.green.color)
            } header: {
                FormHeader("Notifications")
            } footer: {
                Text("For due tasks, partner follow-ups, birthdays and documents that expire. To turn them off, use the iPhone Settings app.")
            }

            Section {
                Button {
                    backupFile = DataFile(data: Backup.export(ctx))
                    exporting = true
                } label: { Label("Export a backup…", systemImage: "square.and.arrow.up") }
                Button { importing = true } label: { Label("Restore from a backup…", systemImage: "square.and.arrow.down") }
                if let backupMessage { Text(backupMessage).font(Typeface.body(14)) }
            } header: {
                FormHeader("Backup")
            } footer: {
                Text("A JSON file with all your records (not the vault files themselves; those are on your server). Restoring adds to what's here.")
            }

            Section {
                Text("You do this with God. This app helps you plan, remember and follow up; it doesn't speak for Him.")
                    .font(Typeface.body(15, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                    .padding(.vertical, 4)
            }
            .listRowBackground(Palette.softYellow)
        }
        .brutalForm()
        .navigationTitle("Settings")
        .task {
            _ = Store.settings(ctx)
            notificationsOn = await Reminders.isAuthorized()
        }
        .fileExporter(isPresented: $exporting, document: backupFile, contentType: .json,
                      defaultFilename: "on-mission-backup-\(DayFormat.string(.now)).json") { result in
            if case .success = result { backupMessage = "Backup saved." }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            guard case .success(let url) = result else { return }
            restore(url)
        }
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

private struct MissionSection: View {
    @Bindable var settings: MissionSettings

    var body: some View {
        Section {
            DatePicker("Departure", selection: $settings.departureDate, displayedComponents: .date)
            MoneyField(title: "Monthly minimum", cents: $settings.supportMinimumMonthlyCents)
            MoneyField(title: "Monthly goal", cents: $settings.supportTargetMonthlyCents)
            MoneyField(title: "Average monthly gift", cents: $settings.averageGiftCents)
            LabeledContent("NZ dollars per euro") {
                TextField("1.85", value: $settings.nzdPerEur, format: .number)
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.decimalPad)
            }
        } header: {
            FormHeader("Your mission")
        } footer: {
            Text("Your passport must be valid until at least \(longDate(settings.passportMustLast)). NZ$ 4,200 is about \(euros(Money.cents(fromEuros: 4200 / max(settings.nzdPerEur, 0.1)))).")
        }
    }
}

// MARK: - Server account, sync and devices

private struct AccountSection: View {
    @Environment(\.modelContext) private var ctx
    @MainActor private var sync: SyncEngine { SyncEngine.shared }

    @State private var server = ""
    @State private var email = ""
    @State private var password = ""
    @State private var busy = false
    @State private var message: String?
    @State private var devices: [API.Device] = []
    @State private var devicesError: String?

    var body: some View {
        Group {
            if sync.isLoggedIn { signedIn } else { signIn }
            if sync.isLoggedIn { devicesSection }
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
        Section {
            TextField("Server, e.g. api.92-5-233-11.sslip.io", text: $server)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            TextField("Email", text: $email)
                .keyboardType(.emailAddress)
                .textContentType(.username)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            SecureField("Password", text: $password)
                .textContentType(.password)
            Button {
                Task { await logIn() }
            } label: {
                HStack {
                    Text("Sign in")
                    if busy { ProgressView().padding(.leading, 6) }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.brutal)
            .disabled(busy || server.isEmpty || email.isEmpty || password.isEmpty)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: Metrics.shadow))
            if let message { Text(message).font(Typeface.body(14)).foregroundStyle(Palette.danger) }
        } header: {
            FormHeader("Sync with your server")
        } footer: {
            Text("Everything is saved on this iPhone first. Signed in, your iPhone and the Windows helper stay in sync and your vault files are backed up.")
        }
    }

    @MainActor private var signedIn: some View {
        Section {
            LabeledContent("Server", value: sync.serverURL)
            LabeledContent("Signed in as", value: sync.email)
            LabeledContent("Last sync", value: sync.lastSync.map { $0.formatted(.relative(presentation: .named)) } ?? "Not yet")
            if let error = sync.lastError {
                Text(error).font(Typeface.body(14)).foregroundStyle(Palette.danger)
            }
            HStack(spacing: Metrics.l) {
                Button {
                    Task { await sync.sync(ctx) }
                } label: {
                    HStack {
                        Text(sync.isSyncing ? "Syncing…" : "Sync now")
                        if sync.isSyncing { ProgressView() }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.brutal)
                .disabled(sync.isSyncing)
                Button {
                    Task { message = await sync.testConnection() }
                } label: {
                    Text("Test").frame(maxWidth: .infinity)
                }
                .buttonStyle(.brutalSecondary)
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: Metrics.shadow))
            if let message { Text(message).font(Typeface.body(14)) }
            Button(role: .destructive) {
                Task {
                    await sync.logout()
                    devices = []
                    password = ""
                }
            } label: {
                Label("Sign out", systemImage: "rectangle.portrait.and.arrow.right").foregroundStyle(Palette.danger)
            }
        } header: {
            FormHeader("Sync with your server")
        } footer: {
            Text("The app syncs when it opens and every 2 minutes while it's open.")
        }
    }

    @MainActor private var devicesSection: some View {
        Section {
            ForEach(devices, id: \.id) { d in
                DeviceRow(device: d) {
                    Task { await revoke(d.id) }
                }
            }
            if devices.isEmpty && devicesError == nil {
                Text("Loading…").foregroundStyle(Palette.muted)
            }
            if let devicesError {
                Text(devicesError).font(Typeface.body(14)).foregroundStyle(Palette.danger)
            }
        } header: {
            FormHeader("Signed-in devices")
        } footer: {
            Text("Lost a phone or laptop? Sign it out here; it can't sync any more after that.")
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
    let onRevoke: () -> Void
    @State private var confirming = false

    var body: some View {
        HStack(spacing: Metrics.m) {
            AccentSquareIcon(symbol: symbol, accent: device.current ? .lime : .grey, size: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(device.name + (device.current ? " (this iPhone)" : ""))
                    .font(Typeface.body(15, weight: .semibold))
                Text(device.lastSeenAt.map { "Seen \($0.formatted(.relative(presentation: .named)))" } ?? device.platform)
                    .font(Typeface.body(12))
                    .foregroundStyle(Palette.muted)
            }
            Spacer(minLength: 0)
            if !device.current {
                Button("Sign out") { confirming = true }
                    .buttonStyle(BrutalButtonStyle(kind: .danger, compact: true))
            }
        }
        .confirmationDialog("Sign out \(device.name)?", isPresented: $confirming, titleVisibility: .visible) {
            Button("Sign out", role: .destructive, action: onRevoke)
        }
    }

    private var symbol: String {
        let p = device.platform.lowercased()
        if p.contains("ios") || p.contains("iphone") { return "iphone" }
        if p.contains("windows") || p.contains("mac") { return "laptopcomputer" }
        return "desktopcomputer"
    }
}
