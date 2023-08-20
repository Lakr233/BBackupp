//
//  BackupProgressListView.swift
//  BBackupp
//
//  Created by QAQ on 2023/8/12.
//

import SwiftUI

struct BackupProgressListView: View {
    @StateObject var backupManager = BackupManager.shared

    var body: some View {
        Group {
            if backupManager.backupSession.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "cursorarrow.and.square.on.square.dashed")
                        .font(.largeTitle)
                    Text("There is nothing in progress.")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .padding()
            } else {
                ScrollView(.vertical, showsIndicators: true) {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(backupManager.backupSession) { session in
                            BackupSessionView(session: session)
                            Divider()
                        }
                    }
                    .padding()
                }
            }
        }
        .toolbar {
            ToolbarItem {
                Button {
                    backupManager.cleanCompleted()
                } label: {
                    Label("Clean Completed Session", systemImage: "lasso.and.sparkles")
                }
            }
        }
        .navigationTitle("Session")
        .frame(minWidth: 400, minHeight: 200)
    }

    var eof: some View {
        HStack(alignment: .center) {
            Image(systemName: "text.append")
            Text("End of File")
        }
        .font(.footnote)
    }
}

struct BackupSessionView: View {
    @StateObject var session: BackupSession
    init(session: BackupSession) {
        _session = .init(wrappedValue: session)
    }

    @State var openDetails = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: session.device.deviceSystemIcon)
                    .font(.system(size: 32, weight: .regular, design: .rounded))
                    .frame(width: 32, height: 32)
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(session.device.deviceName)")
                        .font(.system(.headline, design: .rounded, weight: .bold))
                    Text(
                        session.cratedAt.formatted() + " : " + (
                            session.isRunning
                                ? "\(Int(session.progress.fractionCompleted * 100))% > \(session.progressText.isEmpty ? session.device.universalDeviceIdentifier : session.progressText)"
                                : (
                                    session.errors.isEmpty
                                        ? "Backup process completed successfully."
                                        : session.errorDescription
                                )
                        )
                    )
                    .lineLimit(1)
                    .font(.system(.footnote))
                }
                Spacer()
                if session.isRunning {
                    ProgressView()
                } else {
                    Image(systemName: session.errors.isEmpty
                        ? "checkmark.circle"
                        : "checkmark.circle.badge.xmark"
                    )
                    .font(.system(size: 24, weight: .regular, design: .rounded))
                    .frame(width: 32, height: 32)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { openDetails = true }
        .sheet(isPresented: $openDetails) {
            BackupSessionDetailSheet(session: session) {
                openDetails = false
            }
        }
    }
}

struct BackupSessionDetailSheet: View {
    @StateObject var session: BackupSession
    let dismiss: () -> Void
    init(session: BackupSession, dismiss: @escaping () -> Void) {
        _session = .init(wrappedValue: session)
        self.dismiss = dismiss
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Details").font(.headline)
                Spacer()
                Button("Export") {
                    let filename = "BackupLog-\(session.device.deviceName)-\(Int(session.cratedAt.timeIntervalSince1970)).log"
                    UITemplate.requestToSave(filename: filename) { url in
                        guard let url else { return }
                        try? session.logs
                            .map { "\($0.date.formatted()): \($0.message)" }
                            .joined(separator: "\n")
                            .write(to: url, atomically: true, encoding: .utf8)
                    }
                }
            }
            Divider()
            panelBody.frame(maxWidth: .infinity, maxHeight: .infinity)
            Divider()
            HStack {
                Button {
                    UITemplate.makeConfirmation(
                        message: "Are you sure you want to cancel this backup?",
                        firstButtonText: "Cancel Backup",
                        secondButtonText: "Continue Backup"
                    ) { isConfirm in
                        guard isConfirm else { return }
                        session.cancelled = true
                    }
                } label: {
                    Text("Cancel")
                }
                .disabled(session.cancelled)
                .disabled(!session.isRunning)
                Spacer()
                Button { dismiss() } label: { Text("Done") }
                    .buttonStyle(.borderedProminent)
            }
            .background(
                Button("") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                    .opacity(0)
            )
        }
        .padding()
    }

    var panelBody: some View {
        VStack(alignment: .center, spacing: 4) {
            VStack(alignment: .center, spacing: 4) {
                ProgressView(session.progress)
                    .progressViewStyle(.linear)
            }
            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack {
                    ForEach(session.logs.reversed()) { log in
                        HStack(alignment: .top, spacing: 4) {
                            Text(log.date.formatted())
                            Text(">")
                            Text(log.message)
                        }
                        .foregroundColor(log.level.suggestedColor)
                        .font(.system(.footnote, design: .monospaced, weight: .regular))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                    }
                }
            }
        }
        .frame(minWidth: 600, idealWidth: 600, minHeight: 200, idealHeight: 200)
    }
}

extension BackupSession.BackupLog.Level {
    var suggestedColor: Color {
        switch self {
        case .log: return .primary
        case .error: return .red
        case .warning: return .orange
        case .percent: return .blue
        }
    }
}
