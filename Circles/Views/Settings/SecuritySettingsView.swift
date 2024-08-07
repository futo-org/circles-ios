//
//  SecuritySettingsView.swift
//  Circles
//
//  Created by Charles Wright on 7/5/23.
//

import SwiftUI
import Matrix

struct SecuritySettingsView: View {
    var session: Matrix.Session
    
    @ViewBuilder
    var passwordButton: some View {
        AsyncButton(action: {
            try await session.setBsSpekePassword() { (uiaSession, data) in
                
                if let store = session.secretStore {
                    guard let bsspeke = uiaSession.getBSSpekeClient()
                    else {
                        print("Error: Failed to get BS-SPEKE client after changing password")
                        return
                    }
                    
                    let key = Data(bsspeke.generateHashedKey(label: MATRIX_SSSS_KEY_LABEL))
                    let keyId = bsspeke.generateHashedKey(label: MATRIX_SSSS_KEYID_LABEL)
                                       .prefix(16)
                                       .map {
                                           String(format: "%02hhx", $0)
                                       }
                                       .joined()
                    let description = try Matrix.SecretStore.generateKeyDescription(key: key, keyId: keyId, passphrase: .init(algorithm: ORG_FUTO_BSSPEKE_ECC))
                    let newKey = Matrix.SecretStorageKey(key: key, keyId: keyId, description: description)
                    // Set the key as our new default key for Secret Storage - This automatically encrypts and saves the old key on the server
                    try await store.addNewDefaultKey(newKey)
                    
                    // Save the keys into our device Keychain, so they will be available to future Matrix sessions where we load creds and connect, without logging in
                    let keychain = Matrix.LocalKeyStore(userId: session.creds.userId)
                    try await keychain.saveKey(key: key, keyId: keyId)
                }
                else {
                    print("No secret storage - Not computing new BS-SPEKE-based SSSS key")
                }
            }
        }) {
            //Text("Change Password")
            Label("Change Password", systemImage: "entry.lever.keypad")
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    var blurSettingForUnknownUserButton: some View {
        @AppStorage("blurUnknownUserPicture") var blurUnknownUserPicture = true
        
        Section(header: Text("Privacy Settings")) {
            Toggle(isOn: $blurUnknownUserPicture) {
                VStack(alignment: .leading) {
                    Text("Blur Image for Unknown Users")
                    Text("Enable this option to blur images for invitations from users not in your contacts.")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .tint(.orange)
        }
    }
    
    var body: some View {
        //NavigationView {
        VStack {
            Form {
                NavigationLink(destination: DevicesScreen(session: session)) {
                    Label("Login Sessions", systemImage: SystemImages.iphone.rawValue)
                }

                passwordButton

                NavigationLink(destination: EmailSettingsView(session: session)) {
                    Label("Email Addresses", systemImage: "envelope")
                }
                
                blurSettingForUnknownUserButton
            }
            .navigationTitle("Account Security")
        }
    }
}

/*
struct SecuritySettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SecuritySettingsView()
    }
}
*/
