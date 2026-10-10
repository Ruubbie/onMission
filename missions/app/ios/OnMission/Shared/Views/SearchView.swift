import SwiftUI
import SwiftData

/// Search across everything at once.
struct SearchView: View {
    @Environment(\.modelContext) private var ctx
    @State private var query = ""
    // Read so the results refresh when records change.
    @Query private var tasks: [Todo]
    @Query private var partners: [Partner]
    @Query private var documents: [Document]
    @Query private var notes: [Note]

    private var results: [AnyRecord] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard q.count >= 2 else { return [] }
        _ = (tasks.count, partners.count, documents.count, notes.count)
        return Array(AnyRecord.everything(ctx).filter { $0.searchText.localizedCaseInsensitiveContains(q) }.prefix(200))
    }

    var body: some View {
        let found = results
        List {
            if query.trimmingCharacters(in: .whitespaces).count < 2 {
                BrutalEmptyState(symbol: "magnifyingglass", title: "Search everything",
                                 message: "Tasks, partners, documents, notes, prayer points, checklists, newsletters.", accent: .yellow)
                    .brutalRow(top: 30)
            } else if found.isEmpty {
                BrutalEmptyState(symbol: "questionmark", title: "Nothing found", message: "No match for \"\(query)\".", accent: .grey)
                    .brutalRow(top: 30)
            } else {
                SectionHeader("Results", count: found.count).brutalRow(top: 10, bottom: 2)
                ForEach(found) { rec in
                    CardLink { RecordDestination(record: rec) } label: {
                        RecordRow(record: rec)
                            .padding(Metrics.m)
                            .brutalBox(radius: Metrics.radiusSmall, shadow: Metrics.shadowSmall)
                    }
                    .brutalRow(top: 4, bottom: 6)
                }
            }
        }
        .brutalList()
        .brutalSearch(text: $query, prompt: "Passport, Anna, insurance…")
        .navigationTitle("Search")
    }
}
