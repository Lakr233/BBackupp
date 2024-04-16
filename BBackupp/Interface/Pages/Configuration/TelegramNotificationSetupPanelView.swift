//
//  TelegramNotificationSetupPanelView.swift
//  BBackupp
//
//  Created by 秋星桥 on 2024/3/16.
//

import SwiftUI

struct TelegramNotificationSetupPanelView: View {
    let spacing: CGFloat = 16

    @StateObject var plan: BackupPlan

    @State var telegramBotToken: String = ""
    @State var telegramBotChatID: String = ""

    @Environment(\.dismiss) var dismiss

    @State var openProgress = false
    @State var lastError: BackupPlan.Notification.PushError? = nil

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            HStack {
                Text("Telegram Notification").bold()
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
        plan.notification.provoderContext["TelegramBotToken"] = telegramBotToken
        plan.notification.provoderContext["TelegramBotChatID"] = telegramBotChatID
    }

    @ViewBuilder
    var content: some View {
        editor
            .onAppear {
                plan.notification.provider = .telegram
                telegramBotToken = plan.notification.provoderContext["TelegramBotToken"] ?? ""
                telegramBotChatID = plan.notification.provoderContext["TelegramBotChatID"] ?? ""
            }
            .onDisappear {
                plan.notification.provoderContext["TelegramBotToken"] = telegramBotToken
                plan.notification.provoderContext["TelegramBotChatID"] = telegramBotChatID
            }
    }

    @ViewBuilder
    var editor: some View {
        Text("You can get the token from [@BotFather](https://t.me/BotFather).")
        Divider()
        HStack {
            Text("Bot Token").frame(width: 80, alignment: .trailing)
            TextField("", text: $telegramBotToken, prompt: Text("xxxx-xxxxxxxxx"))
        }
        Divider()
        HStack {
            Text("Chat ID").frame(width: 80, alignment: .trailing)
            TextField("", text: $telegramBotChatID, prompt: Text("888888"))
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
    TelegramNotificationSetupPanelView(plan: bakManager.plans.first!.value)
}
