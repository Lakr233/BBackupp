//
//  SettingView.swift
//  BBackupp
//
//  Created by QAQ on 2023/8/11.
//

import SwiftUI

struct SettingView: View {
    @StateObject var config = appConfiguration

    @State var openProgressReason: String = ""
    @State var openProgress: Bool = false {
        didSet { if !openProgress { openProgressReason = "" } }
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading) {
                storage
                Divider()
                iTunesLocation
                Divider()
                aliveChecker
                Divider()
                HStack(alignment: .center) {
                    Image(systemName: "text.append")
                    Text("End of File")
                }
                .font(.footnote)
            }
            .padding()
        }
        .toolbar { toolbarItems }
        .sheet(isPresented: $openProgress) {
            UITemplate.makeProgress(text: $openProgressReason)
        }
        .navigationTitle("App Configuration")
    }

    @State var openLicenseView: Bool = false
    var toolbarItems: some ToolbarContent {
        Group {
            ToolbarItem {
                Button {
                    openLicenseView = true
                } label: {
                    Label("License", systemImage: "flag.2.crossed")
                }
                .sheet(isPresented: $openLicenseView) {
                    UITemplate.makeSheet(title: "License") {
                        AnyView(
                            TextEditor(text: .constant(
                                (try? String(contentsOf: Constants.licenseFile))
                                    ?? "Unable to load, please refer to project page."
                            ))
                            .font(.system(.body, design: .monospaced, weight: .regular))
                            .frame(minWidth: 600, idealWidth: 600, minHeight: 300, idealHeight: 300)
                        )
                    } complete: { _ in
                        openLicenseView = false
                    }
                }
            }
        }
    }

    var storage: some View {
        UITemplate.buildSection("Default Storage Location") {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    TextField("Storage Location", text: .constant(appConfiguration.defaultBackupLocation))
                        .disabled(true)
                    Button("Select") {
                        UITemplate.requestToSave(
                            filename: Constants.appName,
                            startDir: documentDir.deletingLastPathComponent().path
                        ) { url in
                            guard let url else { return }
                            appConfiguration.switchDefaultBackupLocaiton(url)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                Text("Unless specified, devices use the default storage. Changing this location won't move existing backups.")
                    .font(.system(.footnote))
                HStack {
                    Text("Mount: \(URL(fileURLWithPath: appConfiguration.defaultBackupLocation).mountPoint.path)")
                        .textSelection(.enabled)
                    Text("\(URL(fileURLWithPath: appConfiguration.defaultBackupLocation).getFreeSpaceSize())/\(URL(fileURLWithPath: appConfiguration.defaultBackupLocation).getTotalSpaceSize())")
                        .textSelection(.enabled)
                    Spacer()
                    Text("Reveal in Finder")
                        .underline()
                        .foregroundColor(.accentColor)
                        .onTapGesture {
                            NSWorkspace.shared.open(URL(fileURLWithPath: appConfiguration.defaultBackupLocation))
                        }
                }
                .font(.system(.footnote))
            }
        }
    }

    var iTunesLocation: some View {
        UITemplate.buildSection("iTunes Location") {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    TextField("iTunes Location", text: .constant(Constants.systemBackupLocation.path))
                        .disabled(true)
                    Button("Open") {
                        NSWorkspace.shared.selectFile(Constants.systemBackupLocation.path, inFileViewerRootedAtPath: "")
                    }
                    .buttonStyle(.borderedProminent)
                }
                Text("This is the location your iTunes backups are stored. When you need to restore a device, uncompress our backup and put it there. It will be recognized by iTunes.")
                    .font(.system(.footnote))
            }
        }
    }

    var aliveChecker: some View {
        UITemplate.buildSection("Alive Checker") {
            VStack(alignment: .leading, spacing: 8) {
                TextField("Alive Checker URL: https://alive.example.com/check", text: $config.aliveCheck)
                Text("If this option is set, we will perform a HTTP GET request every 60 seconds. It's helpful if you use uptime monitoring service like [Uptime-Kuma](https://github.com/louislam/uptime-kuma/).")
                    .font(.system(.footnote))
            }
        }
    }
}
