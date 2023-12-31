//  Copyright 2023 FUTO Holdings Inc
//
//  GalleryInviteCard.swift
//  Circles
//
//  Created by Charles Wright on 4/17/23.
//

import Foundation
import SwiftUI

import Matrix

struct GalleryInviteCard: View {
    @ObservedObject var room: Matrix.InvitedRoom
    @ObservedObject var user: Matrix.User
    var container: ContainerRoom<GalleryRoom>
    
    @State var roomAvatarBlur = 20.0
    @State var userAvatarBlur = 20.0
    
    @ViewBuilder
    var buttonRow: some View {
         HStack {
            Spacer()
            
             AsyncButton(role: .destructive, action: {
                try await room.reject()
            }) {
                Label("Reject", systemImage: "hand.thumbsdown.fill")
            }
            .padding(2)
            .frame(width: 120.0, height: 40.0)
            
            Spacer()
            
            AsyncButton(action: {
                let roomId = room.roomId
                try await room.accept()
                try await container.addChild(roomId)
            }) {
                Label("Accept", systemImage: "hand.thumbsup.fill")
            }
            .padding(2)
            .frame(width: 120.0, height: 40.0)
            
            Spacer()
        }
        //.buttonStyle(.bordered)
    
    }
    
    var body: some View {
        VStack(alignment: .leading) {
                
            RoomAvatar(room: room, avatarText: .none)
                .scaledToFill()
                //.frame(width: 300, height: 300)
                .blur(radius: roomAvatarBlur)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .onTapGesture {
                    if roomAvatarBlur >= 5 {
                        roomAvatarBlur -= 5
                    }
                }
            
            Text("\(room.name ?? "(unknown)")")
                .font(.title2)
                .fontWeight(.bold)
            
            HStack(alignment: .top) {
                Text("From:")

                UserAvatarView(user: user)
                    .frame(width: 40, height: 40)
                    .blur(radius: userAvatarBlur)
                    .clipShape(Circle())
                    .onTapGesture {
                        if userAvatarBlur >= 5 {
                            userAvatarBlur -= 5
                        }
                    }
                
                VStack(alignment: .leading) {
                    Text(user.displayName ?? user.userId.username)
                    Text(user.userId.description)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
            }
            
            buttonRow
        }
        .padding()
        .onAppear {
            // Check to see if we have any connection to the person who sent this invitation
            // In that case we don't need to blur the room avatar
            let commonRooms = container.session.rooms.values.filter { $0.joinedMembers.contains(user.userId) }
            
            if !commonRooms.isEmpty {
                self.userAvatarBlur = 0
                self.roomAvatarBlur = 0
            }
        }
    }
}
