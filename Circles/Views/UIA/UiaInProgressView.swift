//
//  UiaInProgressView.swift
//  Circles
//
//  Created by Charles Wright on 3/30/23.
//

import Foundation
import SwiftUI
import Matrix

struct UiaInProgressView: View {
    @ObservedObject var session: UIAuthSession<Matrix.Credentials>
    var state: UIAA.SessionState
    var stages: [String]
    
    @State var emailSecret = ""
    
    var body: some View {

        // Text("UIA in progress")

        if let stage = stages.first {
            //Text("We have a first stage: \(stage)")
            
            if stage == AUTH_TYPE_TERMS,
               let stageId = UIAA.StageId(AUTH_TYPE_TERMS),
               let params = state.params?[stageId] as? TermsParams {
                //UiaTermsView(params: params)
                TermsOfServiceForm(params: params, session: session)
            }
            else if stage == AUTH_TYPE_ENROLL_USERNAME,
               let signupSession = session as? SignupSession {
                UsernameEnrollForm(session: signupSession)
            }
            else if stage == AUTH_TYPE_ENROLL_BSSPEKE_OPRF {
                BsspekeEnrollOprfForm(session: session)
            }
            else if stage == AUTH_TYPE_ENROLL_BSSPEKE_SAVE {
                BsspekeEnrollSaveForm(session: session)
            }
            else if stage == AUTH_TYPE_LOGIN_BSSPEKE_OPRF {
                BsspekeLoginOprfForm(session: session)
            }
            else if stage == AUTH_TYPE_LOGIN_BSSPEKE_VERIFY {
                BsspekeLoginVerifyForm(session: session)
            }
            else if stage == AUTH_TYPE_ENROLL_EMAIL_REQUEST_TOKEN {
                EmailEnrollRequestTokenForm(session: session, secret: $emailSecret)
            }
            else if stage == AUTH_TYPE_ENROLL_EMAIL_SUBMIT_TOKEN {
                EmailEnrollSubmitTokenForm(session: session, secret: emailSecret)
            }
            else {
                Text("Stage = \(stage)")
            }
        } else {
            Text("Looks like we're all done!")
        }
        
    }
}
