//
//  Explorer.swift
//  tinyGLL
//
//  The window around the three diagrams: a grammar and an input to parse, a pane picker,
//  and the parse itself. Each pane is a self-contained view holding its own state —
//  DerivationDiagramView, GrammarDiagramView, StackDiagramView.
//

import SwiftUI
import AppKit

// MARK: - Explorer

struct ExplorerView: View {

    @State private var grammarText = "S = a S | ε ."
    @State private var inputText = "aa"

    @State private var derivations: [DerivationNode] = []
    @State private var status = Status.idle
    @State private var pane = Pane.derivation

    /// The grammar read by the last successful parseGrammar(). Held as state rather than read
    /// from the `nonTerminalDefinitions` global so that editing the grammar redraws the
    /// diagram — SwiftUI cannot observe a global.
    @State private var definitions: [Character: GrammarNode] = [:]

    /// The call return forest left by the last parse. Snapshotted for the same reason as
    /// `definitions`, and because the engine's clusters are classes it mutates in place.
    @State private var crfSnapshot = CRFSnapshot()

    /// Bumped by every parse, and used as the derivation pane's identity so that its state —
    /// which derivation, which nodes collapsed — starts fresh on a new tree rather than
    /// carrying collapse paths over to a tree they no longer describe.
    @State private var parseID = 0

    enum Pane: String, CaseIterable, Identifiable {
        case derivation = "Derivation"
        case grammar = "Grammar"
        case stack = "Stack"

        var id: Self { self }
    }

    enum Status {
        case idle
        case accepted(Int)
        case rejected
        case failed(String)
    }

    var body: some View {
        VStack(spacing: 0) {
            controls
            Divider()
            switch pane {
            case .derivation:
                DerivationDiagramView(derivations: derivations)
                    .id(parseID)
            case .grammar:
                GrammarDiagramView(definitions: definitions)
            case .stack:
                StackDiagramView(snapshot: crfSnapshot)
            }
        }
        .onAppear(perform: parse)
    }

    // MARK: Controls

    /// Only what is shared by all three panes. Anything that acts on one canvas lives in
    /// that pane's own strip, next to the thing it acts on.
    private var controls: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Text("Grammar").foregroundStyle(.secondary)
                TextField("S = aS | ε .", text: $grammarText)
                    .font(.system(size: 12).monospaced())
                    .onSubmit(parse)
                Text("Input").foregroundStyle(.secondary)
                TextField("aa", text: $inputText)
                    .font(.system(size: 12).monospaced())
                    .frame(width: 130)
                    .onSubmit(parse)
                Button("Parse", action: parse).keyboardShortcut(.return, modifiers: .command)
            }

            HStack(spacing: 12) {
                Picker("", selection: $pane) {
                    ForEach(Pane.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 260)

                statusLabel

                Spacer()
            }
        }
        .padding(10)
    }

    @ViewBuilder
    private var statusLabel: some View {
        switch status {
        case .idle:
            Label("not parsed", systemImage: "circle.dashed").foregroundStyle(.secondary)
        case .accepted(let count):
            Label(count > 1 ? "accepted — ambiguous, \(count) derivations" : "accepted",
                  systemImage: count > 1 ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .foregroundStyle(count > 1 ? .orange : .green)
        case .rejected:
            Label("rejected — no derivation covers the whole input", systemImage: "xmark.circle.fill")
                .foregroundStyle(.red)
        case .failed(let message):
            Label(message, systemImage: "exclamationmark.octagon.fill").foregroundStyle(.red)
        }
    }

    // MARK: Parsing

    private func parse() {
        resetEngine()
        syntax = Array(grammarText)
        input = Array(inputText)
        derivations = []
        definitions = [:]
        crfSnapshot = CRFSnapshot()
        parseID += 1

        do {
            try parseGrammar()
            // Captured before the input parse, so the grammar diagram still draws when the
            // input is rejected or the grammar is being edited toward something parseable.
            definitions = nonTerminalDefinitions
            try parseInput()
            // Captured before the acceptance check: a rejected parse still builds a CRF, and
            // looking at where the calls got to is exactly how you find out why it failed.
            crfSnapshot = CRFSnapshot(crf: crf, root: nonTerminalDefinitions["S"])
        } catch {
            status = .failed("\(error)")
            return
        }

        guard parseAccepted else {
            status = .rejected
            return
        }

        derivations = DerivationBuilder().allDerivations()
        status = derivations.isEmpty ? .rejected : .accepted(derivations.count)
    }
}

// MARK: - Hosting a SwiftUI window from a command-line tool

private final class ExplorerAppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

private var explorerDelegate: ExplorerAppDelegate?
private var explorerWindow: NSWindow?

/// tinyGLL is a command-line tool, not an app bundle, so there is no `@main App` to hand the
/// scene to. Setting a regular activation policy and running an NSApplication by hand gets a
/// real window anyway — enough for a developer tool, and it keeps the engine in one target.
@MainActor
func runExplorer() {
    let app = NSApplication.shared
    app.setActivationPolicy(.regular)

    let delegate = ExplorerAppDelegate()
    explorerDelegate = delegate
    app.delegate = delegate
    app.mainMenu = makeMenu()

    let window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 1180, height: 760),
        styleMask: [.titled, .closable, .miniaturizable, .resizable],
        backing: .buffered,
        defer: false)
    window.title = "tinyGLL Explorer"
    window.contentView = NSHostingView(rootView: ExplorerView())
    window.center()
    window.makeKeyAndOrderFront(nil)
    explorerWindow = window

    app.activate()
    app.run()
}

/// Without a main menu there is no ⌘Q, and the text fields lose ⌘C/⌘V.
@MainActor
private func makeMenu() -> NSMenu {
    let mainMenu = NSMenu()

    let appItem = NSMenuItem()
    let appMenu = NSMenu()
    appMenu.addItem(withTitle: "Quit tinyGLL Explorer",
                    action: NSSelectorFromString("terminate:"),
                    keyEquivalent: "q")
    appItem.submenu = appMenu
    mainMenu.addItem(appItem)

    let editItem = NSMenuItem()
    let editMenu = NSMenu(title: "Edit")
    for (title, selector, key) in [("Undo", "undo:", "z"), ("Redo", "redo:", "Z"),
                                   ("Cut", "cut:", "x"), ("Copy", "copy:", "c"),
                                   ("Paste", "paste:", "v"), ("Select All", "selectAll:", "a")] {
        editMenu.addItem(withTitle: title, action: NSSelectorFromString(selector), keyEquivalent: key)
    }
    editItem.title = "Edit"
    editItem.submenu = editMenu
    mainMenu.addItem(editItem)

    return mainMenu
}
