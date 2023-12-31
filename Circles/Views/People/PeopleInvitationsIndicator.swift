//  Copyright 2023 FUTO Holdings Inc
//
//  PeopleInvitationsIndicator.swift
//  Circles
//
//  Created by Michael Hollister on 9/5/23.
//

import SwiftUI
import Matrix

struct PeopleInvitationsIndicator: View {
    //@Binding var invitations: [Matrix.InvitedRoom]
    @ObservedObject var session: Matrix.Session
    var container: ContainerRoom<Matrix.SpaceRoom>
    
    @State var invitations: [Matrix.InvitedRoom] = []
    
    var body: some View {
        HStack {
            Spacer()
            
            if !invitations.isEmpty {
                NavigationLink(destination: PeopleInvitationsView(session: session, people: container)) {
                    Label("\(invitations.count) invitation(s) to connect", systemImage: "envelope.open.fill")
                }
            }
            
            Spacer()
        }
        .onAppear {
            invitations = session.invitations.values.filter { $0.type == M_SPACE }
        }
    }
}

/*
struct PeopleInvitationsIndicator_Previews: PreviewProvider {
    static var previews: some View {
        PeopleInvitationsIndicator()
    }
}
*/
