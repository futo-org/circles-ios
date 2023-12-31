//  Copyright 2020, 2021 Kombucha Digital Privacy Systems LLC
//
//  CircleOverviewCard.swift
//  Circles for iOS
//
//  Created by Charles Wright on 11/5/20.
//

import SwiftUI


struct CircleOverviewCard: View {
    @ObservedObject var space: CircleSpace
    
    var avatar: some View {
        CircleAvatar(space: space)
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack(alignment: .center) {
                
                avatar
                    .frame(width: 120, height: 120)
                
                VStack(alignment: .leading) {
                    HStack {
                        Text(space.name ?? "(unnamed circle)")
                            .font(.title2)
                            .fontWeight(.bold)
                        Spacer()
                    }
                    
                    VStack(alignment: .leading) {
                        
                        Text("Following \(space.following.count)")
                        
                        Text("Followed by \(space.followers.count)")

                        if space.unread > 0 {
                            Text("\(space.unread) unread posts")
                                .fontWeight(.bold)
                        } else {
                            Text("Last updated \(space.timestamp, formatter: RelativeDateTimeFormatter())")
                        }
                        
                        if let wall = space.wall {
                            let knockCount = wall.knockingMembers.count
                            if knockCount > 0 {
                                Label("\(knockCount) requests for invitations", systemImage: "star.fill")
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                    .font(.headline)
                    .foregroundColor(.gray)
                }
                .padding(.leading)

                Spacer()
            }
        }
    }
}

/*
struct ScreenOverviewCard_Previews: PreviewProvider {
    static var previews: some View {
        ScreenOverviewCard()
    }
}
 */
