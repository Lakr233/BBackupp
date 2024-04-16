//
//  BarkNotificationSetupPanelView.swift
//  BBackupp
//
//  Created by 秋星桥 on 2024/3/16.
//

import SwiftUI

struct BarkNotificationSetupPanelView: View {
    let spacing: CGFloat = 16

    @StateObject var plan: BackupPlan

    @State var barkEndpoint: String = ""
    @State var barkGroup: String = ""
    @State var barkIcon: String = ""
    @State var barkSound: String = ""

    @Environment(\.dismiss) var dismiss

    @State var openProgress = false
    @State var lastError: BackupPlan.Notification.PushError? = nil

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            HStack {
                Text("Bark Notification").bold()
                Spacer()
            }
            .padding(spacing)
            Divider()
            VStack(alignment: .leading, spacing: 8) {
                content.frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(spacing)
            Divider()
            HStack {
                Button("Test") {
                    save()
                    openProgress = true
                    plan.notification.send(message: "It's working!") { result in
                        DispatchQueue.main.async {
                            openProgress = false
                            if case let .failure(failure) = result { lastError = failure }
                        }
                    }
                }
                .sheet(isPresented: $openProgress) {
                    ProgressPanelView()
                }
                Spacer()
                Button("OK") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }
            .padding(spacing)
        }
        .frame(width: 500)
    }

    func save() {
        plan.notification.provoderContext["BarkEndpoint"] = barkEndpoint
        plan.notification.provoderContext["BarkGroup"] = barkGroup
        plan.notification.provoderContext["BarkIcon"] = barkIcon
        plan.notification.provoderContext["BarkSound"] = barkSound
    }

    @ViewBuilder
    var content: some View {
        editor
            .onAppear {
                plan.notification.provider = .bark
                barkEndpoint = plan.notification.provoderContext["BarkEndpoint"] ?? ""
                barkGroup = plan.notification.provoderContext["BarkGroup"] ?? Constants.appName
                barkIcon = plan.notification.provoderContext["BarkIcon"] ?? Constants.appAvatarURL.absoluteString
                barkSound = plan.notification.provoderContext["BarkSound"] ?? "bell"
            }
            .onDisappear { save() }
    }

    @ViewBuilder
    var editor: some View {
        Text("To setup this app on device, visit [Finb/Bark](https://github.com/Finb/Bark) for details.")
        Divider()
        HStack {
            Text("Endpoint").frame(width: 60, alignment: .trailing)
            TextField("", text: $barkEndpoint, prompt: Text("https://"))
        }
        Divider()
        HStack {
            Text("Group").frame(width: 60, alignment: .trailing)
            TextField("", text: $barkGroup, prompt: Text("(Optional)"))
        }
        HStack {
            Text("Icon").frame(width: 60, alignment: .trailing)
            TextField("", text: $barkIcon, prompt: Text("(Optional)"))
        }
        HStack {
            Text("Sound").frame(width: 60, alignment: .trailing)
            TextField("", text: $barkSound, prompt: Text("(Optional)"))
        }
        if let lastError {
            Divider()
            Text(lastError.interfaceText)
                .font(.footnote)
                .foregroundStyle(.red)
        }
    }
}

#Preview {
    BarkNotificationSetupPanelView(plan: bakManager.plans.first!.value)
}
