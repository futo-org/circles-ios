//  Copyright 2020, 2021 Kombucha Digital Privacy Systems LLC
//  Copyright 2023 FUTO Holdings Inc
//
//  CircleTimeline.swift
//  Circles for iOS
//
//  Created by Charles Wright on 11/6/20.
//

import SwiftUI
import Matrix

struct CircleTimeline: View {
    @ObservedObject var space: CircleSpace
    @AppStorage("debugMode") var debugMode: Bool = false
    private var formatter: DateFormatter
    @State private var showDebug = false
    @State private var loading = false

    init(space: CircleSpace) {
        self.space = space
        self.formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .long
    }
    
    var debugFooter: some View {
        VStack(alignment: .leading) {
            Button(action: {self.showDebug = false}) {
                Label("Hide debug info", systemImage: "eye.slash")
            }
            Text("\(space.rooms.count) rooms in the Stream")
            ForEach(space.rooms) { room in
                let owner = room.creator
                let messages = room.messages
                    
                HStack {
                    Text("\(messages.count) total messages in \(owner.description): \(room.name ?? room.roomId.description)")
                        .padding(.leading, 10)
                    if owner == room.session.creds.userId {
                        Text("(my room)")
                            .fontWeight(.bold)
                    }
                }
                if let firstMessage = messages.first {
                    let ts = firstMessage.timestamp
                    Text("since \(formatter.string(from: ts))")
                        .padding(.leading, 20)
                }
            }
            /*
            let lfr = stream.lastFirstRoom
            Text("Last first room is \(lfr?.displayName ?? "None")")
            */
        }
        .font(.caption)
    }
    
    var body: some View {
        let messages: [Matrix.Message] = space.getCollatedTimeline(filter: { $0.relatedEventId == nil }).reversed()
        
        VStack(alignment: .leading) {
            if let wall = space.wall,
               wall.knockingMembers.count > 0
            {
                RoomKnockIndicator(room: wall)
            }
            
            ScrollView {
                LazyVStack(alignment: .center) {
                    ForEach(messages) { message in
                        VStack(alignment: .leading) {
                            HStack {
                                if debugMode && showDebug {
                                    let index: Int = messages.firstIndex(of: message)!
                                    Text("\(index)")
                                }
                                
                                MessageCard(message: message)
                            }
                            RepliesView(room: message.room, parent: message)
                        }
                    }
                    .padding([.top, .leading, .trailing], 3)
                }
                .frame(maxWidth: TIMELINE_FRAME_MAXWIDTH)
            
                HStack(alignment: .bottom) {
                    Spacer()
                    if loading {
                        ProgressView("Loading...")
                    }
                    else if space.canPaginateRooms {
                        AsyncButton(action: {
                            try await space.paginateRooms()
                        }) {
                            Text("Load More")
                        }
                        .onAppear {
                            // Basically it's like we automatically click "Load More" for the user
                            let _ = Task {
                                try await space.paginateRooms()
                            }
                        }
                    }
                    
                    Spacer()
                }
                .frame(minHeight: TIMELINE_BOTTOM_PADDING)
            }
            .onAppear {
                _ = Task {
                    try await space.paginateEmptyTimelines(limit: 25)
                }
            }
            .refreshable {
                if let wall = space.wall {
                    print("REFRESH\tUpdating Circle avatar image")
                    wall.updateAvatarImage()
                }
                
                async let results = space.rooms.map { room in
                    print("REFRESH\tLoading latest messages from \(room.name ?? room.roomId.stringValue)")

                    return try? await room.getMessages(forward: false)
                }
                let responses = await results
                print("REFRESH\tGot \(responses.count) responses from \(space.rooms.count) rooms")
                
                print("REFRESH\tWaiting for network requests to come in")
                try? await Task.sleep(for: .seconds(1))
                
                print("REFRESH\tSending Combine update")
                await MainActor.run {
                    space.objectWillChange.send()
                }
            }



            if debugMode {
                if showDebug {
                    debugFooter
                } else {
                    Button(action: {self.showDebug = true}) {
                        Label("Show debug info", systemImage: "eye")
                            .font(.footnote)
                    }
                }
            }

        }

    }
}

/*
struct StreamTimeline_Previews: PreviewProvider {
    static var previews: some View {
        StreamScreen()
    }
}
 */
