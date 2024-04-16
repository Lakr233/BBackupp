//
//  ManageAccountView.swift
//  BBackupp
//
//  Created by 秋星桥 on 2024/3/16.
//

import ApplePackage
import SwiftUI

struct AppStoreAccountView: View {
    @StateObject private var backend = AppStoreBackend.shared

    @State var selected: Set<AppStoreBackend.Account.ID> = []
    @State var openAdd: Bool = false

    @Environment(\.dismiss) var dismiss

    var body: some View {
        Group {
            if backend.accounts.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "person.crop.circle.badge.questionmark.fill")
                        .font(.largeTitle)
                    Text("You dont have any account yet.")
                    Button("Login with Apple ID") { openAdd = true }
                }
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    Text("App Store Accounts")
                        .bold()
                        .padding(16)
                    Divider()
                    Table(backend.accounts, selection: $selected) {
                        TableColumn("Email") { value in
                            Text(value.email)
                        }
                        .width(min: 100, max: 300)
                        TableColumn("First Name") { value in
                            Text(value.storeResponse.firstName)
                        }
                        .width(min: 50, max: 100)
                        TableColumn("Last Name") { value in
                            Text(value.storeResponse.lastName)
                        }
                        .width(min: 50, max: 100)
                        TableColumn("Directory Services ID") { value in
                            Text(value.storeResponse.directoryServicesIdentifier)
                        }
                        .width(min: 100, max: 300)
                        TableColumn("Country Code") { value in
                            Text(value.countryCode)
                        }
                        .width(80)
                    }
                    Divider()
                    HStack {
                        Button {
                            openAdd = true
                        } label: {
                            Text("Add Account")
                        }
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(KeyEquivalent("N"), modifiers: .command)

                        Button {
                            for id in selected {
                                backend.delete(id: id)
                            }
                            selected = []
                        } label: {
                            Text("Delete Selected")
                        }
                        .keyboardShortcut(.delete)
                        .disabled(selected.isEmpty)
                        Spacer()
                        Button("Close") { dismiss() }
                    }
                    .padding(16)
                }
            }
        }
        .sheet(isPresented: $openAdd) {
            AppStoreAccountAddView()
        }
        .frame(minWidth: 600, minHeight: 300)
    }
}

struct AppStoreAccountAddView: View {
    @StateObject private var backend = AppStoreBackend.shared
    @Environment(\.dismiss) var dismiss

    @State var email: String = ""
    @State var password: String = ""

    @State var codeRequired: Bool = false
    @State var code: String = ""

    @State var error: Error?
    @State var openProgress: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Add Account").font(.headline)
                Spacer()
            }
            Divider()
            sheetBody
            Divider()
            HStack {
                Button {
                    dismiss()
                } label: {
                    Text("Cancel")
                }
                .keyboardShortcut(.cancelAction)
                Spacer()
                Button {
                    authenticate()
                } label: {
                    Text("Authenticate")
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .sheet(isPresented: $openProgress) {
            ProgressPanelView()
        }
    }

    var sheetBody: some View {
        VStack(spacing: 8) {
            TextField("Email (Apple ID)", text: $email)
                .disableAutocorrection(true)
            SecureField("Password", text: $password)
            if codeRequired {
                TextField("2FA Code (If Needed)", text: $code)
            }
            if let error {
                Text(error.localizedDescription)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
            }
        }
        .frame(width: 300)
    }

    func authenticate() {
        openProgress = true
        DispatchQueue.global().async {
            defer { DispatchQueue.main.async { openProgress = false } }
            let auth = ApplePackage.Authenticator(email: email)
            do {
                let account = try auth.authenticate(password: password, code: code.isEmpty ? nil : code)
                DispatchQueue.main.async {
                    backend.save(email: email, password: password, account: account)
                    dismiss()
                }
            } catch {
                DispatchQueue.main.async {
                    self.error = error
                    codeRequired = true
                }
            }
        }
    }
}

#Preview {
    AppStoreAccountView()
}
