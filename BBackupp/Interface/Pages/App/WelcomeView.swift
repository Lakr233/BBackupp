//
//  WelcomeView.swift
//  BBackupp
//
//  Created by 秋星桥 on 2024/1/4.
//

import ColorfulX
import SwiftUI

struct WelcomeView: View {
    @Environment(\.colorScheme) var colorScheme
    @State var openLicenseView = false

    var body: some View {
        ZStack {
            foot.frame(maxHeight: .infinity, alignment: .bottom)
            content
        }
        .padding()
        .hideToolbarBackground()
        .background(background.ignoresSafeArea())
        .toolbar {
            ToolbarItem {
                Button {
                    NSWorkspace.shared.open(Constants.projectUrl)
                } label: {
                    Label("Open GitHub", systemImage: "questionmark")
                }
            }
            ToolbarItem(placement: .navigation) {
                Button {
                    openLicenseView = true
                } label: {
                    Label("Show License", systemImage: "flag.and.flag.filled.crossed")
                }
                .sheet(isPresented: $openLicenseView) {
                    SheetPanelView("License", width: 600) {
                        LicenseView()
                    }
                }
            }
        }
    }

    @ViewBuilder
    var background: some View {
        ColorfulView(color: .constant([
            .init("WelcomeColorMain"),
            .init("WelcomeColorSecondary"),
            .background,
            .background,
            .background,
            .background,
            .background,
            .background,
            .background,
            .background,
        ]), speed: .constant(0.25))
            .opacity(0.25)
    }

    var content: some View {
        VStack(alignment: .center, spacing: 20) {
            Image("Avatar")
                .resizable()
                .antialiased(true)
                .aspectRatio(contentMode: .fill)
                .frame(width: 80, height: 80, alignment: .center)
            Text("Welcome to BBackupp")
                .font(.system(.body, design: .rounded, weight: .bold))
        }
        .padding(.bottom, 20)
    }

    var foot: some View {
        HStack(alignment: .bottom) {
            PairDeviceButton()
            Spacer()
            VStack(alignment: .trailing, spacing: 0) {
                Text("v\(Constants.appVersion).b\(Constants.appBuildVersion).c\(BackupTask.mobileBackupVersion)")
                Text(Restic.version)
            }
            .font(.system(.caption, design: .rounded, weight: .light))
            .onTapGesture {
                NSWorkspace.shared.open(Constants.projectUrl)
            }
        }
        .opacity(0.75)
    }
}

private struct WelcomeButton: View {
    let icon: String
    let title: String
    let onTap: () -> Void

    var body: some View {
        Button { onTap() } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                Text(title)
            }
            .font(.system(.footnote, design: .rounded, weight: .regular))
            .padding(6)
            .padding(.horizontal, 4)
            .background(Color.primary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }
}

private struct PairDeviceButton: View {
    @State var openPairPanel: Bool = false
    var body: some View {
        WelcomeButton(icon: "cable.connector", title: "Register Device") {
            openPairPanel = true
        }
        .sheet(isPresented: $openPairPanel) {
            RegisterSheetView()
        }
    }
}

private struct LicenseView: View {
    let licenseData: String?

    init() {
        guard let path = Bundle.main.path(forResource: "License", ofType: "resolved"),
              let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let ack = String(data: data, encoding: .utf8)
        else {
            licenseData = nil
            return
        }
        licenseData = ack
    }

    @ViewBuilder
    var body: some View {
        if let licenseData {
            ScrollView(.vertical) {
                TextEditor(text: .constant(licenseData))
                    .font(.system(size: 12, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 300)
        } else {
            Text("Unable to load license file, please refer to source code for more information.")
        }
    }
}
