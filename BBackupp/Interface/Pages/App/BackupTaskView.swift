//
//  BackupTaskView.swift
//  BBackupp
//
//  Created by 秋星桥 on 2024/3/15.
//

import SwiftUI

struct BackupTaskView: View {
    let spacing: CGFloat = 16

    init(task: BackupTask) {
        _task = .init(wrappedValue: task)
    }

    @StateObject var task: BackupTask
    @State var openTerminateAlert: Bool = false

    var title: String { "Backup Progress - \(task.config.device.deviceName)" }
    var footnote: String {
        let info: [Any?] = [task.id, task.pid]
        return info
            .compactMap(\.self)
            .compactMap { "\($0)" }
            .joined(separator: " - ")
    }

    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            HStack {
                Text(title).bold()
                Spacer()
                if task.completed {
                    if task.error == nil {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        Image(systemName: "checkmark.circle.badge.xmark.fill")
                            .foregroundStyle(.red)
                    }
                } else {
                    Text("\(Int(task.overall.fractionCompleted * 100))%")
                }
            }
            .padding(spacing)
            Divider()
            VStack(alignment: .leading, spacing: 8) {
                content.frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(spacing)
            Divider()
            HStack {
                Text(footnote)
                    .font(.footnote)
                    .opacity(0.5)
                Spacer()
                if task.executing {
                    Button("Terminate") { openTerminateAlert = true }
                        .alert(isPresented: $openTerminateAlert) {
                            Alert(
                                title: Text("Are you sure you want to terminate this backup?"),
                                primaryButton: .destructive(Text("Terminate")) { task.terminate() },
                                secondaryButton: .cancel()
                            )
                        }
                }
                Button(task.completed ? "Done" : "Close") { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.cancelAction)
            }
            .padding(spacing)
        }
        .frame(width: 550)
    }

    var currentProgress: String {
        guard !task.completed else { return "" }
        guard task.current.fractionCompleted > 0,
              task.current.fractionCompleted < 1,
              task.current.completedUnitCount > 0,
              task.current.totalUnitCount > 0
        else { return "..." }
        let char = "="
        let charCountMax = 20
        let charCount = Int(task.current.fractionCompleted * Double(charCountMax))
        let charCountLeft = charCountMax - charCount
        let valueA = String(repeating: char, count: charCount)
        let valueB = String(repeating: " ", count: charCountLeft)
        let percent = Int(task.current.fractionCompleted * 100)
        let bytesFmt = ByteCountFormatter()
        bytesFmt.allowedUnits = [.useAll]
        bytesFmt.countStyle = .file
        let done = bytesFmt.string(fromByteCount: task.current.completedUnitCount)
        let total = bytesFmt.string(fromByteCount: task.current.totalUnitCount)
        return "Receiving \(total) - [\(valueA)>\(valueB)] \(percent)% (\(done))"
    }

    @ViewBuilder
    var content: some View {
        ProgressView(
            value: Double(task.overall.completedUnitCount),
            total: Double(task.overall.totalUnitCount)
        )
        .progressViewStyle(.linear)
        ScrollView(.vertical) {
            LazyVStack(alignment: .leading, spacing: 4) {
                if !currentProgress.isEmpty {
                    HStack(alignment: .top, spacing: 8) {
                        Text(Date().formatted(date: .numeric, time: .shortened))
                        Text(":")
                        Text(currentProgress)
                    }
                    .font(.footnote)
                    .monospaced()
                }

                ForEach(task.output.reversed()) { input in
                    HStack(alignment: .top, spacing: 8) {
                        Text(input.date.formatted(date: .numeric, time: .shortened))
                        Text(":")
                        Text(input.text)
                            .foregroundStyle(input.color)
                            .textSelection(.enabled)
                    }
                    .font(.footnote)
                    .monospaced()
                }
            }
        }
        .frame(height: 132)
    }
}

private extension BackupTask.Log {
    var color: Color {
        if text.lowercased().contains("error") {
            return .red
        }
        if text.lowercased().contains("warning") {
            return .orange
        }
        return .primary
    }
}
