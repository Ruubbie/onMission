import Foundation
import SwiftData

/// First launch: fill the app with your plan (checklists, tasks, packing list, vault slots, settings)
/// from Resources/seed-records.json. These are the same records, with the same ids and timestamp
/// (2026-10-08), as the server's seed, so syncing never makes doubles and any real edit wins.
enum Seeder {
    private static let flag = "seeded-records-v1"

    struct SeedFile: Decodable { var records: [API.Record] }

    static func seedIfNeeded(_ ctx: ModelContext) {
        guard !UserDefaults.standard.bool(forKey: flag) else { return }
        if let url = Bundle.main.url(forResource: "seed-records", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let seed = try? JSONDecoder().decode(SeedFile.self, from: data) {
            // Applied like server records: keeps their updatedAt and counts them as synced.
            Registry.apply(seed.records, ctx)
        }
        _ = Store.settings(ctx)
        try? ctx.save()
        UserDefaults.standard.set(true, forKey: flag)
    }
}
