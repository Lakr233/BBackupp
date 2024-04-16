//
//  OneTimeBackupView.swift
//  BBackupp
//
//  Created by 秋星桥 on 2024/3/8.
//

import SwiftUI

struct OneTimeBackupPanelView: View {
    let udid: Device.ID
    let spacing: CGFloat = 16

    @State var useNetwork: Bool = false
    @State var useStoreBase: URL = BackupTask.defaultBase
    @State var useIncrementalBackup: Bool = true
    @State var task: BackupTask? = nil
    @State var openWakeupDeviceAlert = false

    var useStoreBaseDefaultKey: String {
        "\(udid).one.time.store"
    }

    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            HStack {
                Text("Backup").bold()
                Spacer()
            }
            .padding(spacing)
            Divider()
            VStack(alignment: .leading, spacing: 8) {
                config.frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(spacing)
            Divider()
            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Start Backup") { startBackup() }
                    .buttonStyle(.borderedProminent)
                    .sheet(item: $task) { dismiss() } content: {
                        BackupTaskView(task: $0)
                    }
            }
            .padding(spacing)
        }
        .frame(width: 500)
        .onAppear {
            amdManager.requireDevice(udid: udid, connection: .usb) { device in
                if device == nil { useNetwork = true }
            }
            if let store = UserDefaults.standard.string(forKey: useStoreBaseDefaultKey) {
                useStoreBase = URL(fileURLWithPath: store)
            } else if let device = devManager.devices[udid] {
                useStoreBase = BackupTask.defaultBase.appendingPathComponent(device.deviceName)
            }
        }
        .onChange(of: useStoreBase) { newValue in
            UserDefaults.standard.set(newValue.path, forKey: useStoreBaseDefaultKey)
        }
    }

    var config: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("One-Time Backup")
                .bold()

            Text("One time backup is not stored inside the app. Save it where you want.")

            HStack {
                TextField("", text: .init(get: {
                    useStoreBase.path
                }, set: {
                    useStoreBase = URL(fileURLWithPath: $0.trimmingCharacters(in: .whitespacesAndNewlines))
                }))
                Button("Select") {
                    NSApp.beginSavePanel { panel in
                        panel.setup(
                            title: "Select Backup Storage",
                            nameFieldStringValue: useStoreBase.lastPathComponent,
                            directoryURL: useStoreBase.deletingLastPathComponent(),
                            canCreateDirectories: true
                        )
                    } completion: { url in
                        try? FileManager.default.createDirectory(
                            at: url,
                            withIntermediateDirectories: true
                        )
                        useStoreBase = url
                    }
                }
            }

            Group {
                if FileManager.default.fileExists(atPath: useStoreBase.path) {
                    Text("Free space: \(useStoreBase.getFreeSpaceSize())")
                } else {
                    Text("Will create this directory.")
                }
            }
            .font(.footnote)
            .opacity(0.5)

            Toggle("Connect via Network", isOn: $useNetwork)
        }
    }

    func startBackup() {
        guard let device = devManager.devices[udid] else {
            dismiss()
            return
        }
        let task = BackupTask(config: .init(
            device: device,
            useNetwork: useNetwork,
            useStoreBase: useStoreBase,
            useIncrementBackup: useIncrementalBackup
        ))
        task.start()
        bakManager.tasks.insert(task, at: 0)
        self.task = task
    }
}
