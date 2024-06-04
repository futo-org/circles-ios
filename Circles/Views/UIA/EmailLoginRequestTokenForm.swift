//
//  EmailLoginRequestTokenForm.swift
//  Circles
//
//  Created by Charles Wright on 3/25/24.
//

import Foundation
import SwiftUI
import Combine
import Matrix
import MarkdownUI

struct EmailLoginRequestTokenForm: View {
    var session: any UIASession
    var addresses: [String]

    @State var emailAddress: String = ""
    @State private var errorMessage = ""

    @Binding var secret: String
    
    enum FocusField {
        case email
    }
    @FocusState var focus: FocusField?
    
    var addressIsValid: Bool {
        // https://stackoverflow.com/questions/201323/how-can-i-validate-an-email-address-using-a-regular-expression
        let regex = #/(?:[a-z0-9!#$%&'*+/=?^_`{|}~-]+(?:\.[a-z0-9!#$%&'*+/=?^_`{|}~-]+)*|"(?:[\x01-\x08\x0b\x0c\x0e-\x1f\x21\x23-\x5b\x5d-\x7f]|\\[\x01-\x09\x0b\x0c\x0e-\x7f])*")@(?:(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+[a-z0-9](?:[a-z0-9-]*[a-z0-9])?|\[(?:(?:(2(5[0-5]|[0-4][0-9])|1[0-9][0-9]|[1-9]?[0-9]))\.){3}(?:(2(5[0-5]|[0-4][0-9])|1[0-9][0-9]|[1-9]?[0-9])|[a-z0-9-]*[a-z0-9]:(?:[\x01-\x08\x0b\x0c\x0e-\x1f\x21-\x5a\x53-\x7f]|\\[\x01-\x09\x0b\x0c\x0e-\x7f])+)\])/#
        return ((try? regex.wholeMatch(in: emailAddress)) != nil)
    }
    
    func submit() async throws {
        if addressIsValid {
            guard let secret = try? await session.doEmailLoginRequestTokenStage(email: emailAddress)
            else {
                print("Failed to request email token")
                return
            }
 
            await MainActor.run {
                self.secret = secret
            }
        } else {
            print("submit() - Error: No email address selected")
        }
    }
    
    var showErrorMessageView: some View {
        VStack {
            if errorMessage != "" {
                ToastView(titleMessage: errorMessage)
                Text("")
                    .onAppear {
                        errorMessage = ""
                    }
            }
        }
    }
    
    var body: some View {
        VStack {
            Text("Authenticate with email")
                .font(.title2)
                .fontWeight(.bold)
                .padding()
            Text("We will send a short 6-digit code to your email address to verify your identity.")
                .lineLimit(2)
            
            Spacer()
            
            Text("You have the following addresses enrolled:")
            ScrollView {
                ForEach(addresses, id: \.self) { address in
                    Text(address)
                        .foregroundColor(.gray)
                }
            }
            .padding(.leading)
            
            showErrorMessageView
            TextField("you@example.com", text: $emailAddress, prompt: Text("Email address"))
                .textContentType(.emailAddress)
                .focused($focus, equals: .email)
                .keyboardType(.emailAddress)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                //.focused($inputFocused)
                //.frame(width: 300.0, height: 40.0)
                .onSubmit {
                    Task {
                        do {
                            try await submit()
                        } catch {
                            errorMessage = error.localizedDescription
                        }
                    }
                }
                .onAppear {
                    self.focus = .email
                }
                .padding()
            
            AsyncButton(action: submit) {
                Text("Request Code")
                    .padding()
                    .frame(width: 300.0, height: 40.0)
                    .foregroundColor(.white)
                    .background(Color.accentColor)
                    .cornerRadius(10)
            }
            .disabled(!addressIsValid)
            
            Spacer()
            
        }
        .padding()

    }
}
