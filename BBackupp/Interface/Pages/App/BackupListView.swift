//
//  BackupListView.swift
//  BBackupp
//
//  Created by 秋星桥 on 2024/3/7.
//

import AuxiliaryExecute
import SwiftUI

private let relativeDateFmt = {
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .full
    return formatter
}()

private let byteFmt = {
    let fmt = ByteCountFormatter()
    fmt.allowedUnits = [.useAll]
    fmt.countStyle = .file
    return fmt
}()

struct BackupListView: View {
    let udid: Device.ID
    @StateObject var backupManager = bakManager
    @StateObject var deviceManager = devManager

    @State private var backups: [Backup] = []
    @State private var selected = Set<Backup.ID>()
    @State private var searchText: String = ""

    @State private var openProgress = false
    @State private var openDeleteAlert = false
    @State private var openExportProgress = false
    @State private var exportProgress: Progress = .init()
    @State private var exportPID: pid_t?
    @State private var showInFinderAfterComplete = false

    var body: some View {
        content
            .sheet(isPresented: $openProgress) {
                ProgressPanelView()
            }
            .sheet(isPresented: $openExportProgress) {
                progressPanel
            }
            .onAppear { backupManager.reloadBackup(forDevice: udid) }
            .onAppear {
                reloadBackups()
                if let first = backups.first { selected.insert(first.id) }
            }
            .onReceive(backupManager.objectWillChange) { _ in reloadBackups() }
    }

    @ViewBuilder
    var content: some View {
        if backups.isEmpty {
            Text("No Backup Available")
                .font(.system(.body, design: .rounded, weight: .regular))
                .opacity(backups.isEmpty ? 0.5 : 0)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                tableView
                Divider()
                toolbar
            }
        }
    }

    @ViewBuilder
    var progressPanel: some View {
        VStack(spacing: 4) {
            HStack {
                Text("Export Backup").bold()
                Spacer()
            }
            .padding()
            Divider()
            Spacer().frame(height: 18)
            ProgressView()
                .progressViewStyle(.circular)
                .padding(16)
            VStack(spacing: 4) {
                ProgressView(
                    value: Double(exportProgress.completedUnitCount),
                    total: Double(exportProgress.totalUnitCount)
                )
                .progressViewStyle(.linear)
                HStack {
                    Text("\(byteFmt.string(fromByteCount: exportProgress.completedUnitCount))/\(byteFmt.string(fromByteCount: exportProgress.totalUnitCount))")
                    Spacer()
                    Text("\(Int(exportProgress.fractionCompleted * 100))%")
                }
                .font(.footnote)
                .monospaced()
            }
            .padding()

            Divider()
            HStack {
                Toggle("Show In Finder After Complete", isOn: $showInFinderAfterComplete)
                Spacer()
                Button("Cancel") {
                    if let pid = exportPID { terminateSubprocess(pid) }
                }
            }
            .padding()
        }
        .frame(width: 500)
    }

    @ViewBuilder
    var toolbar: some View {
        HStack {
            Button("Delete Selected \(selected.count) Backups") {
                openDeleteAlert = true
            }
            .disabled(selected.isEmpty)
            .alert(isPresented: $openDeleteAlert) {
                Alert(
                    title: Text("Are you sure you want to delete \(selected.count) backups?"),
                    primaryButton: .destructive(Text("Delete")) { deleteSelectedSnapshots() },
                    secondaryButton: .cancel()
                )
            }
            Spacer()
            Button("Export Backup for Restore") {
                let backup = backups.filter { selected.contains($0.id) }.first
                guard let backup, let device = deviceManager.devices[backup.deviceID]
                else { return }
                let fmt = DateFormatter()
                fmt.dateFormat = "yyyy-MM-dd-HHmmss"
                let date = fmt.string(from: backup.snapshot.date)
                NSApp.beginSavePanel { panel in
                    panel.setup(
                        title: "Export Backup",
                        nameFieldStringValue: "\(device.deviceName) @ \(date)",
                        canCreateDirectories: true,
                        showsHiddenFiles: false
                    )
                } completion: { url in
                    openExportProgress = true
                    backup.export(toURL: url) {
                        exportPID = $0
                    } onProgress: { progress in
                        exportProgress = progress
                    } onCompletion: {
                        openExportProgress = false
                        if showInFinderAfterComplete {
                            NSWorkspace.shared.activateFileViewerSelecting([url])
                        }
                    }
                    exportPID = nil
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(selected.count != 1)
        }
        .padding()
    }

    var tableView: some View {
        Table(backups, selection: $selected) {
            TableColumn("ID") { value in
                Text(value.snapshot.short_id)
                    .monospaced()
            }
            .width(min: 50, ideal: 100, max: 150)
            TableColumn("Date") { value in
                Text(value.snapshot.date.formatted(date: .numeric, time: .standard))
            }
            .width(min: 50, ideal: 150)
            TableColumn("Relative") { value in
                let interval = value.snapshot.date.timeIntervalSinceNow
                let text = relativeDateFmt.localizedString(fromTimeInterval: interval)
                Text(text)
            }
            .width(min: 50, ideal: 100)
            TableColumn("Restic Version") { value in
                Text(value.snapshot.program_version.capitalized)
            }
            .width(min: 50, ideal: 100, max: 150)
        }
    }

    func reloadBackups() {
        backups = backupManager.backups[udid] ?? []
    }

    func deleteSelectedSnapshots() {
        openProgress = true
        let backups = backups.filter { selected.contains($0.id) }
        selected = []

        DispatchQueue.global().async {
            defer { DispatchQueue.main.async {
                openProgress = false
                reloadBackups()
            } }

            for backup in backups {
                backupManager.deleteBackup(backup)
            }
        }
    }
}

private extension Backup {
    func export(
        toURL url: URL,
        setPid: @escaping (pid_t) -> Void,
        onProgress: @escaping (Progress) -> Void,
        onCompletion: @escaping () -> Void
    ) {
        let progress = Progress()
        progress.completedUnitCount = 1
        onProgress(progress)

        DispatchQueue(label: "wiki.qaq.restic.export").asyncAfter(deadline: .now() + 1) {
            try? FileManager.default.removeItem(at: url)
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)

            let recp = AuxiliaryExecute.spawn(
                command: Restic.executable,
                args: [
                    "--json",
                    "--retry-lock", "5h",
                    "restore", snapshot.id,
                    "--target", url.path,
                ],
                environment: repo.prepareEnv()
            ) { pid in
                DispatchQueue.main.asyncAndWait { setPid(pid) }
            } output: { output in
                guard let data = output.data(using: .utf8),
                      let dic = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                      let message_type = dic["message_type"] as? String,
                      message_type == "status",
                      let total_bytes = dic["total_bytes"] as? Int64,
                      let bytes_restored = dic["bytes_restored"] as? Int64
                else { return }
                let progress = Progress()
                progress.totalUnitCount = total_bytes
                progress.completedUnitCount = bytes_restored
                DispatchQueue.main.async { onProgress(progress) }
            }
            print("snapshot \(snapshot.id) at \(repo.location) export returned \(recp.exitCode)")
            DispatchQueue.main.async {
                onCompletion()
            }
        }
    }
}
