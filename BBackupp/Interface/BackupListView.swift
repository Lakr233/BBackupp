//
//  BackupListView.swift
//  BBackupp
//
//  Created by QAQ on 2023/8/12.
//

import Combine
import SwiftUI
import ZipArchive

struct BackupListView: View {
    @StateObject var backupManager = BackupManager.shared
    var backupList: [Backup] { backupManager.backup(withDeviceID: selectedDevice) }

    let selectedDevice: Device.DevcieID?
    let allowToolbar: Bool
    init(device: Device.DevcieID? = nil, allowToolbar: Bool = true) {
        selectedDevice = device
        self.allowToolbar = allowToolbar
    }

    @State private var selected = Set<Backup.ID>()
    @State private var displayingContent: [Backup] = []
    @State private var searchText: String = ""
    @State private var sortOrder: [KeyPathComparator<Backup>] = []

    @State private var unpackProgressOpen: Bool = false
    @State private var unpackProgress: Progress = .init()
    @State private var unpackError: [Error] = []

    var body: some View {
        Table(displayingContent, selection: $selected, sortOrder: $sortOrder) {
            TableColumn("") { value in
                Image(systemName: FileManager.default.fileExists(atPath: value.location)
                    ? "magnifyingglass"
                    : "folder.badge.questionmark"
                )
                .resizable()
                .aspectRatio(contentMode: .fit)
                .contentShape(Rectangle())
                .onTapGesture {
                    guard NSWorkspace.shared.selectFile(
                        value.location,
                        inFileViewerRootedAtPath: ""
                    ) else {
                        UITemplate.makeErrorAlert(with: "Unable to locate this file")
                        return
                    }
                }
            }
            .width(12)
            TableColumn("Device", value: \.device.deviceName) { value in
                Text(value.device.deviceName)
            }
            .width(min: 100, max: 200)
            TableColumn("Archived At", value: \.archivedAt) { value in
                Text(value.archivedAt.formatted())
            }
            .width(min: 120, max: 240)
            TableColumn("Keep") { value in
                WiredToggleView(isOn: .constant(value.keep)) {
                    AnyView(Group {})
                } tapped: {
                    if value.keep {
                        UITemplate.makeConfirmation(
                            message: "This backup may be removed immediately if mets the requirement."
                        ) { yes in
                            guard yes else { return }
                            value.keep = false
                        }
                    } else {
                        value.keep = true
                    }
                }
            }
            .width(50)
            TableColumn("Size", value: \.size) { value in
                Text(value.size.formatted(.byteCount(style: .file)))
            }
            .width(min: 60, max: 100)
            TableColumn("Name", value: \.name)
                .width(min: 400)
        }
        .toolbar {
            if allowToolbar {
                ToolbarItem {
                    Button {
                        let savePanel = NSSavePanel()
                        savePanel.nameFieldStringValue = Constants.systemBackupLocation.lastPathComponent
                        savePanel.directoryURL = Constants.systemBackupLocation
                            .deletingLastPathComponent()
                        guard let window = NSApp.keyWindow ?? NSApp.windows.first else {
                            return
                        }
                        savePanel.beginSheetModal(for: window) { response in
                            assert(Thread.isMainThread)
                            if response == .OK, let url = savePanel.url { unpack(toDir: url) }
                        }
                    } label: {
                        Label("Unpack to iTunes", systemImage: "paperplane")
                    }
                    .disabled(selected.isEmpty)
                }
                ToolbarItem {
                    Button {
                        UITemplate.makeConfirmation(
                            message: "Are you sure you want to delete \(selected.count) backup(s)?",
                            firstButtonText: "Delete",
                            secondButtonText: "Cancel"
                        ) { yes in
                            guard yes else { return }
                            backupManager.delete(backups: Array(selected))
                        }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .disabled(selected.isEmpty)
                }
            }
        }
        .sheet(isPresented: $unpackProgressOpen) {
            UnpackProgressView(
                unpackProgress: $unpackProgress,
                errors: $unpackError
            )
        }
        .searchable(text: $searchText)
        .onChange(of: searchText) { newValue in
            rebuildContent(searchKey: newValue)
        }
        .onReceive(backupManager.objectWillChange) { _ in
            rebuildContent(searchKey: searchText)
        }
        .onChange(of: sortOrder) { _ in
            DispatchQueue.main.async { rebuildContent(searchKey: searchText) }
        }
        .onAppear { rebuildContent(searchKey: "") }
        .navigationTitle("Backups")
        .frame(minWidth: 400, minHeight: 200)
    }

    func rebuildContent(searchKey: String) {
        var build = [Backup]()
        defer { displayingContent = build.sorted(using: sortOrder) }

        let read = backupList
        if searchKey.isEmpty {
            build = read
            return
        }

        let key = searchKey.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        build = read.filter { backup in
            if backup.name.lowercased().contains(key) { return true }
            if backup.device.deviceName.contains(key) { return true }
            if backup.device.udid.lowercased() == key { return true }
            return false
        }
    }

    func unpack(toDir: URL) {
        unpackProgress = Progress(totalUnitCount: 1)
        unpackProgressOpen = true
        unpackError = []
        DispatchQueue.global().async {
            let backups = selected.compactMap { backupManager.backup(withBackID: $0) }
            for backup in backups {
                try? FileManager.default.createDirectory(
                    at: Constants.systemBackupLocation,
                    withIntermediateDirectories: true
                )
                let sem = DispatchSemaphore(value: 0)
                let delegate = UnpackDelegate(associatedBackup: backup) { progress in
                    DispatchQueue.main.async { unpackProgress = progress }
                } cancel: {
                    unpackProgress.isCancelled
                } completion: {
                    sem.signal()
                }

                SSZipArchive.unzipFile(
                    atPath: backup.location,
                    toDestination: toDir.path,
                    preserveAttributes: true,
                    overwrite: true,
                    nestedZipLevel: 0,
                    password: nil,
                    error: nil,
                    delegate: delegate
                ) { _, _, _, _ in } completionHandler: { _, _, error in
                    DispatchQueue.main.async {
                        if let error { unpackError.append(error) }
                    }
                }
                sem.wait()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                unpackProgress = Progress(totalUnitCount: 1)
                unpackProgress.completedUnitCount = 1
            }
        }
    }
}

struct UnpackProgressView: View {
    @Binding var unpackProgress: Progress
    @Binding var errors: [Error]

    @Environment(\.dismiss) var dismiss

    enum UnarchiveError: Error {
        case cancelled
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Unpacking Backup").font(.headline)
                Spacer()
            }
            Divider()
            VStack(spacing: 12) {
                if unpackProgress.isFinished {
                    Image(systemName: errors.isEmpty ? "checkmark.circle.fill" : "checkmark.circle.trianglebadge.exclamationmark")
                        .font(.system(size: 32))
                        .foregroundStyle(errors.isEmpty ? .green : .red)
                        .padding()
                    if !errors.isEmpty {
                        Text(errors.map(\.localizedDescription).joined(separator: ", ").capitalized)
                            .foregroundStyle(.red)
                    } else {
                        Text("Unpack Completed")
                    }
                } else {
                    Group {
                        Spacer().frame(height: 20)
                        ProgressView()
                        ProgressView(unpackProgress)
                            .progressViewStyle(.linear)
                    }
                }
            }
            .padding(.vertical)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            Divider()
            HStack {
                Button("Cancel") {
                    UITemplate.makeConfirmation(message: "This will leave partial unpacked items behind.") { yes in
                        guard yes else { return }
                        unpackProgress.cancel()
                        errors.append(UnarchiveError.cancelled)
                    }
                }
                .disabled(!unpackProgress.isCancellable)
                .disabled(unpackProgress.isFinished)
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .disabled(!unpackProgress.isFinished)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(minWidth: 500, minHeight: 200)
    }
}

class UnpackDelegate: NSObject, SSZipArchiveDelegate {
    let associatedBackup: Backup
    let cancel: () -> Bool
    let setProgress: (Progress) -> Void
    let completion: () -> Void

    @Published var progress = Progress()
    var cancellable: Set<AnyCancellable> = []

    init(associatedBackup: Backup, setProgress: @escaping (Progress) -> Void, cancel: @escaping () -> Bool, completion: @escaping () -> Void) {
        self.associatedBackup = associatedBackup
        self.cancel = cancel
        self.setProgress = setProgress
        self.completion = completion

        super.init()

        $progress
            .throttle(for: .seconds(0.5), scheduler: DispatchQueue.global(), latest: true)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] val in
                guard !(self?.cancel() ?? true) else { return }
                self?.setProgress(val)
            }
            .store(in: &cancellable)
    }

    func zipArchiveShouldUnzipFile(at _: Int, totalFiles _: Int, archivePath _: String, fileInfo _: unz_file_info) -> Bool {
        if cancel() {
            completion()
            return false
        }
        return true
    }

    func zipArchiveProgressEvent(_ loaded: UInt64, total: UInt64) {
        let progress = Progress()
        progress.completedUnitCount = Int64(loaded)
        progress.totalUnitCount = Int64(total)
        if progress.completedUnitCount >= progress.totalUnitCount {
            // never complete
            progress.totalUnitCount = progress.completedUnitCount + 1
        }
        self.progress = progress
    }

    func zipArchiveDidUnzipArchive(atPath _: String, zipInfo _: unz_global_info, unzippedPath _: String) {
        completion()
    }
}
