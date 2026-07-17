//
//  MatchDetailView.swift
//  FIFA2026WorldCup
//
//  Phase 4 — Match detail. Screen 2 of 6, presented as a sheet from the bracket.
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
            VStack(spacing: 20) {
                header

                WinnerPicker(node: node, selection: $pickedWinner)

                currentPickLine

                Spacer(minLength: 0)

                confirmButton

                if node.predictedWinner != nil {
                    clearButton
                }
            }
            .padding()
            .navigationTitle(BracketEngine.roundName(node.round))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    // MARK: - Pieces

    private var header: some View {
        VStack(spacing: 4) {
            Text("Match \(node.slot + 1)")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let date = node.match?.matchDate {
                Text(date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    /// Reads the @State the child writes — visible proof the binding works.
    private var currentPickLine: some View {
        HStack(spacing: 6) {
            if let picked = pickedWinner {
                Text("Your pick:")
                    .foregroundStyle(.secondary)
                FlagView(team: picked)
                Text(picked.name)
                    .fontWeight(.semibold)
            } else {
                Text("Tap a team to pick the winner")
                    .foregroundStyle(.secondary)
            }
        }
        .font(.subheadline)
    }

    private var confirmButton: some View {
        Button {
            confirmPick()
        } label: {
            Text("Confirm Pick")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .disabled(pickedWinner == nil || pickedWinner?.id == node.predictedWinner?.id)
    }

    private var clearButton: some View {
        Button(role: .destructive) {
            clearPick()
        } label: {
            Text("Clear Pick")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
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
        engine.syncPredictionsToStore()
        do {
            try modelContext.save()
        } catch {
            print("MatchDetailView: save failed — \(error)")
        }
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
