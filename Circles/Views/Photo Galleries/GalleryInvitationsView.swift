//  Copyright 2023 FUTO Holdings Inc
//
//  GalleryInvitationsView.swift
//  Circles
//
//  Created by Charles Wright on 8/1/23.
//

import SwiftUI
import Matrix

struct GalleryInvitationsView: View {
    @ObservedObject var session: Matrix.Session
    @ObservedObject var container: ContainerRoom<GalleryRoom>
    
    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                let invitations = session.invitations.values.filter { $0.type == ROOM_TYPE_PHOTOS }
                if invitations.isEmpty {
                    Text("No current invitations")
                } else {
                    ForEach(invitations) { invitation in
                        let user = session.getUser(userId: invitation.sender)
                        GalleryInviteCard(room: invitation, user: user, container: container)
                        Divider()
                    }
                }
            }
        }
        .navigationTitle(Text("Invitations"))
    }
}

/*
struct GalleryInvitationsView_Previews: PreviewProvider {
    static var previews: some View {
        GalleryInvitationsView()
    }
}
*/
