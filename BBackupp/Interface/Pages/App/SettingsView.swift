//
//  SettingsView.swift
//  BBackupp
//
//  Created by 秋星桥 on 2024/3/15.
//

import SwiftUI

struct SettingsView: View {
    @StateObject var vm = appSetting

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    backupBase
                }
                VStack(alignment: .leading, spacing: 12) {
                    iTunesBackupLocatin
                }
                VStack(alignment: .leading, spacing: 12) {
                    heartBeat
                }
                VStack(alignment: .leading) {
                    Text("\(Constants.appName) - \(Constants.appVersion)")
                    Text("Made with love by @Lakr233")
                        .onTapGesture {
                            let url = URL(string: "https://github.com/Lakr233")!
                            NSWorkspace.shared.open(url)
                        }
                }
                .font(.footnote)
                .opacity(0.5)
            }
            .frame(maxWidth: .infinity)
            .padding()
        }
        .navigationTitle("Setting")
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {} label: {
                    Label("", systemImage: "gear")
                }
            }
        }
    }

    @ViewBuilder
    var backupBase: some View {
        Text("Backup Base Location")
            .bold()
        Text("Before sending your backup to restic repository, your backup will be stored in this directory. This will also enable incremental backup support.")
        Text("We recommend using a fast drive for this purpose.")
            .foregroundStyle(.accent)
            .underline()
        HStack {
            TextField("", text: .init(
                get: { vm.tempBackupBase.path },
                set: { vm.tempBackupBase = .init(fileURLWithPath: $0) }
            ))
            .disabled(true)
            Button("Select") {
                NSApp.beginSavePanel { panel in
                    panel.setup(
                        title: "Select Temp Backup Storage",
                        nameFieldStringValue: vm.tempBackupBase.lastPathComponent,
                        directoryURL: vm.tempBackupBase.deletingLastPathComponent(),
                        canCreateDirectories: true
                    )
                } completion: {
                    try? FileManager.default.createDirectory(
                        at: vm.tempBackupBase,
                        withIntermediateDirectories: true
                    )
                    vm.tempBackupBase = $0
                }
            }
        }
        Text("Free space: \(vm.tempBackupBase.getFreeSpaceSize())")
            .font(.footnote)
        Divider()
    }

    @ViewBuilder
    var iTunesBackupLocatin: some View {
        Text("System Backup Location")
            .bold()
        Text("Finder or iTunes backups are located at this directory. If you are planing for a restore, put exported files here.")
        Text("Backup directory has device UDID as it's name.")
            .foregroundStyle(.accent)
            .underline()
        HStack {
            TextField("", text: .constant(Constants.systemBackupLocation.path))
                .disabled(true)
            Button("Reveal in Finder") {
                NSWorkspace.shared.open(Constants.systemBackupLocation)
            }
        }
        Text("Free space: \(vm.tempBackupBase.getFreeSpaceSize())")
            .font(.footnote)
        Divider()
    }

    @ViewBuilder
    var heartBeat: some View {
        Text("Heart Beat")
            .bold()
        Text("\(Constants.appName) supports online check. Fill in the heartbeat address to enable this feature.")
        Text("GET request will be sent every 30 seconds.")
            .foregroundStyle(.accent)
            .underline()
        TextField("", text: $vm.heartbeatAddress, prompt: Text("https://"))
        HStack {
            Toggle("Enabled", isOn: $vm.heartbeatEnabled)
            Spacer()
            if vm.heartbeatLastSent.timeIntervalSince1970 > 100 {
                Text("Last Sent: \(vm.heartbeatLastSent.formatted())")
                    .font(.footnote)
                    .opacity(0.5)
            }
        }
        Divider()
    }
}

#Preview {
    SettingsView()
        .frame(width: 600, height: 600, alignment: .center)
}
