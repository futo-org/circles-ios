//
//  EmailLoginSubmitTokenForm.swift
//  Circles
//
//  Created by Charles Wright on 3/25/24.
//

import Foundation
import SwiftUI
import Matrix

struct EmailLoginSubmitTokenForm: View {
    var session: any UIASession
    var secret: String

    @State var token = ""
    
    enum FocusField {
        case token
    }
    @FocusState var focus: FocusField?
    
    @State var showAlert = false
    let alertTitle = "Invalid code"
    let alertMessage = "Please double-check the code and enter it again, or request a new code."
    
    var tokenIsValid: Bool {
        token.count == 6 && Int(token) != nil
    }
    
    var body: some View {
        VStack {
            Spacer()
            VStack {
                Text("Enter the 6-digit code that you received in your email")
            }
            Spacer()
            VStack {
                TextField("123456", text: $token, prompt: Text("6-Digit Code"))
                    .customEmailTextFieldStyle(contentType: .oneTimeCode, keyboardType: .numberPad)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .focused($focus, equals: .token)
                    .frame(width: 300.0, height: 40.0)
                    .onAppear {
                        self.focus = .token
                    }
                
                AsyncButton(action: {
                    do {
                        try await session.doEmailLoginSubmitTokenStage(token: token, secret: secret)
                    } catch {
                        print("Email login submit token stage failed")
                        self.showAlert = true
                    }
                }) {
                    Text("Submit")
                }
                .buttonStyle(BigRoundedButtonStyle())
                .disabled(!tokenIsValid)
                .alert(isPresented: $showAlert) {
                    Alert(title: Text(self.alertTitle),
                          message: Text(self.alertMessage),
                          dismissButton: .default(Text("OK"), action: { self.token = "" })
                    )
                }
                
                AsyncButton(action: {
                    try await session.redoEmailLoginRequestTokenStage()
                }) {
                    Text("Send a new code")
                        .padding()
                }
            }
            Spacer()
        }
    }
}
