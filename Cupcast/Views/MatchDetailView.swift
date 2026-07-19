//
//  MatchDetailView.swift
//  Cupcast
//
//  Phase 4 — Match detail. Restyled for the dark theme in Phase 5.
//
//  THE @State anchor example (Objective 3.6): this view OWNS `pickedWinner` and
//  hands `$pickedWinner` down to WinnerPicker, whose taps write back into it.
//  Nothing touches the engine or the store until Confirm — the binding dance is
//  all local state, which is exactly the point of the pattern.
//
//  On Confirm: the pick goes through engine.advanceWinner (didSet cascade updates
//  the tree and tears down any invalidated later picks), the whole tree is mirrored
//  to the persisted Matches, and the save happens here through
//  @Environment(\.modelContext) — views own SwiftData writes, per the conventions.
//

import SwiftUI
import SwiftData

struct MatchDetailView: View {
    let node: BracketNode

    @State private var pickedWinner: Team?
    @Environment(BracketEngine.self) private var engine
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    init(node: BracketNode) {
        self.node = node
        // Seed the local state from the existing pick so reopening a decided
        // match shows the current choice instead of a blank slate.
        _pickedWinner = State(initialValue: node.predictedWinner)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    Spacer().frame(height: 12)
                    header
                    WinnerPicker(node: node, selection: $pickedWinner)
                    currentPickLine
                    cascadeNote
                    if let result = resultNote { result }
                    Spacer(minLength: 8)
                    confirmButton
                    if node.predictedWinner != nil { clearButton }
                }
                .padding()
            }
            .bracketBackground()
            // The bar names the round, matching the bracket column this sheet was
            // opened from, so the sheet says where you are in the hierarchy. The
            // matchup lives in the capsule instead — see `header`.
            .navigationTitle(BracketEngine.roundName(node.round))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                        .tint(Theme.textSecondary)
                }
            }
        }
    }

    // MARK: - Pieces

    private var header: some View {
        VStack(spacing: 8) {
            // The matchup in words, sitting directly above the same matchup in
            // flags — the two read as one statement, one verbal and one graphic.
            Text(matchupTitle.uppercased())
                .font(.caption2).fontWeight(.heavy).tracking(1.2)
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, 12).padding(.vertical, 5)
                .background(Capsule().fill(Theme.accentGradient))

            if let date = node.match?.matchDate {
                Text("\(date.formatted(date: .abbreviated, time: .omitted))\(Self.venue(for: node).map { " · \($0)" } ?? "")")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
    }

    /// Reads the @State the child writes — visible proof the binding works.
    private var currentPickLine: some View {
        HStack(spacing: 6) {
            if let picked = pickedWinner {
                Text("Your pick:").foregroundStyle(Theme.textSecondary)
                FlagView(team: picked)
                Text(picked.name).fontWeight(.semibold).foregroundStyle(.white)
            } else {
                Text("Tap a team to pick the winner").foregroundStyle(Theme.textSecondary)
            }
        }
        .font(.subheadline)
    }

    private var cascadeNote: some View {
        HStack(spacing: 9) {
            Image(systemName: "arrow.up.forward.circle.fill")
                .foregroundStyle(Theme.accentPurple)
            Text(node.round < BracketEngine.roundCount - 1
                 ? "The winner advances to the \(BracketEngine.roundName(node.round + 1)) and updates the bracket automatically."
                 : "The winner is crowned champion 🏆 and fills the trophy banner.")
            .font(.caption)
            .foregroundStyle(Theme.textSecondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.accentPurple.opacity(0.14)))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.accentPurple.opacity(0.3), lineWidth: 1))
    }

    /// Shown only once official results are in for this match.
    private var resultNote: (some View)? {
        guard let actual = node.actualWinner else { return Optional<AnyView>.none }
        let correct = node.predictedWinner?.id == actual.id
        let picked = node.predictedWinner != nil
        let (icon, tint, text): (String, Color, String) =
            !picked ? ("info.circle.fill", Theme.textSecondary, "No pick recorded. \(actual.name) won this match.")
            : correct ? ("checkmark.seal.fill", Theme.success, "Correct! \(actual.name) won — +\(pointsForRound) pts.")
            : ("xmark.seal.fill", Theme.danger, "You picked \(node.predictedWinner?.name ?? "—"), but \(actual.name) won.")

        return AnyView(
            HStack(spacing: 10) {
                Image(systemName: icon).foregroundStyle(tint)
                Text(text).font(.caption).fontWeight(.medium).foregroundStyle(.white)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 14).fill(tint.opacity(0.14)))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(tint.opacity(0.35), lineWidth: 1))
        )
    }

    private var confirmButton: some View {
        Button {
            confirmPick()
        } label: {
            Text("Confirm Pick")
                .fontWeight(.bold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Capsule().fill(canConfirm ? AnyShapeStyle(Theme.accentGradient) : AnyShapeStyle(Theme.card)))
                .foregroundStyle(canConfirm ? .white : Theme.textTertiary)
        }
        .buttonStyle(.plain)
        .disabled(!canConfirm)
    }

    private var clearButton: some View {
        Button(role: .destructive) {
            clearPick()
        } label: {
            Text("Clear Pick")
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .foregroundStyle(Theme.danger)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Derived

    private var canConfirm: Bool {
        pickedWinner != nil && pickedWinner?.id != node.predictedWinner?.id
    }

    private var pointsForRound: Int {
        [1, 2, 4, 8][safe: node.round] ?? 0
    }

    /// "Argentina vs Paraguay" once both teams are known. Later rounds open with
    /// their slots still empty, so those fall back to the match number rather than
    /// showing "TBD vs TBD" (Objective 2.6 — optional binding driving the copy).
    private var matchupTitle: String {
        guard let a = node.teamA, let b = node.teamB else {
            return "Match \(node.slot + 1)"
        }
        return "\(a.name) vs \(b.name)"
    }

    // MARK: - Actions

    private func confirmPick() {
        guard let winner = pickedWinner else { return }
        engine.advanceWinner(for: node, to: winner)
        persist()
        dismiss()
    }

    private func clearPick() {
        engine.clearPrediction(for: node)
        persist()
        dismiss()
    }

    private func persist() {
        engine.syncToStore()
        do {
            try modelContext.save()
        } catch {
            print("MatchDetailView: save failed — \(error)")
        }
    }

    // MARK: - Demo venues (flavor, matching the mockup)

    private static let venues: [String: String] = [
        "0-0": "MetLife, NJ", "0-1": "SoFi, LA", "0-2": "AT&T, Dallas", "0-3": "Azteca, MX",
        "0-4": "Mercedes-Benz, ATL", "0-5": "Lumen, Seattle", "0-6": "BC Place, Vancouver",
        "0-7": "Hard Rock, Miami", "1-0": "MetLife, NJ", "1-1": "AT&T, Dallas",
        "1-2": "Arrowhead, KC", "1-3": "SoFi, LA", "2-0": "AT&T, Dallas", "2-1": "MetLife, NJ",
        "3-0": "MetLife, NJ",
    ]

    private static func venue(for node: BracketNode) -> String? {
        venues["\(node.round)-\(node.slot)"]
    }
}

/// Safe indexing so a short pointsPerRound array can't crash the view.
extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Team.self, Match.self, configurations: config)

    let engine = BracketEngine()
    engine.buildBracket(from: SeedData.makeTeams())

    return MatchDetailView(node: engine.node(round: 0, slot: 0)!)
        .environment(engine)
        .modelContainer(container)
}
