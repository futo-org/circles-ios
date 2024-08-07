//  Copyright 2020, 2021 Kombucha Digital Privacy Systems LLC
//  Copyright 2022, 2023 FUTO Holdings Inc
//
//  PhotoGalleryCard.swift
//  Circles for iOS
//
//  Created by Charles Wright on 11/3/20.
//

import SwiftUI
import Matrix

struct PhotoGalleryCard: View {
    @ObservedObject var room: Matrix.Room
    
    var timestamp: some View {
        let date = Date()
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .long
        return Text("\(date, formatter: formatter)")
    }
    
    var body: some View {
        ZStack {
            RoomAvatarView(room: room, avatarText: .none)
                .frame(width: 300, height: 300)
                /*
                .onAppear {
                    // Dirty nasty hack to test how/when SwiftUI is updating our Views
                    Task {
                        while true {
                            let sec = Int.random(in: 10...30)
                            try await Task.sleep(for: .seconds(sec))
                            let imageName = ["diamond.fill", "circle.fill", "square.fill", "seal.fill", "shield.fill"].randomElement()!
                            let newImage = UIImage(systemName: imageName)
                            await MainActor.run {
                                print("Setting avatar for room \(room.roomId)")
                                room.avatar = newImage
                            }
                        }
                    }
                }
                */
    
            VStack {
                if room.creator != room.session.creds.userId {
                    let user = room.session.getUser(userId: room.creator)
                    HStack {
                        UserAvatarView(user: user)
                            .frame(width: 70, height: 70)
                        Text(user.displayName ?? user.userId.username)
                            .font(.title3)
                            .fontWeight(.bold)
                    }
                }
                
                Text(room.name ?? "")
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .font(.title)
                    .fontWeight(.bold)

                if DebugModel.shared.debugMode {
                    Text(room.roomId.description)
                        .font(.subheadline)
                    timestamp
                        .font(.subheadline)
                    //Text(room.avatarUrl?.mediaId ?? "(none)")
                    //    .font(.subheadline)
                }
                
                let knockCount = room.knockingMembers.count
                if room.iCanInvite && room.iCanKick && knockCount > 0 {
                    Label("\(knockCount) requests for invitations", systemImage: "star.fill")
                            //.foregroundColor(.accentColor)
                }
            }
            .foregroundColor(.white)
            .shadow(color: .black, radius: 5)
        }
    }
}

/*
struct PhotoGalleryCard_Previews: PreviewProvider {
    static var previews: some View {
        PhotoGalleryCard()
    }
}
 */
