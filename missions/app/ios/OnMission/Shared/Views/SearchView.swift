import SwiftUI
import SwiftData

/// Find anything (a cream page from Move): tasks, people, papers, notes, prayers, lists, letters.
struct SearchPage: View {
    @Environment(\.modelContext) private var ctx
    @Environment(Router.self) private var router
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
        let typing = query.trimmingCharacters(in: .whitespaces).count >= 2
        CreamPage {
            Text("Find anything")
                .type(.disp(62))
                .foregroundStyle(Palette.tomato)
                .padding(.top, 10)
                .accessibilityAddTraits(.isHeader)
            SearchField(text: $query, prompt: "Passport, Anna, insurance…")
                .padding(.top, 14)
                .padding(.bottom, 8)
            if !typing {
                Text("Tasks, people, papers, notes, prayers, checklists and letters.")
                    .type(.hand(26))
                    .foregroundStyle(Palette.tomato)
                    .rotationEffect(.degrees(-2))
                    .padding(.top, 14)
            } else if found.isEmpty {
                EmptyRow(title: "Nothing found", message: "No match for \"\(query)\".")
            } else {
                SectionHeader("Results", count: found.count).padding(.top, 12)
                ForEach(Array(found.enumerated()), id: \.element.id) { index, rec in
                    Button { router.open(rec) } label: {
                        RecordRow(record: rec, rule: index < found.count - 1)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
