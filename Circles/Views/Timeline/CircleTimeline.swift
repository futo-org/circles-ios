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
    private var formatter: DateFormatter
    @State private var showDebug = false
    @State private var loading = false
    private var cutoff: Date

    init(space: CircleSpace) {
        self.space = space
        self.formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .long

        // We want to filter out any messages claiming to be from the future
        // Allow for clocks being up to 5 minutes (300 sec) out of sync
        // But in general we will drop anything claiming to be from the future -- Otherwise a malicious user could effectively "sticky" their post at the top of everyone's timeline
        let now = Date()
        self.cutoff = now.addingTimeInterval(300.0)
    }
    
    var debugFooter: some View {
        VStack(alignment: .leading) {
            Button(action: {self.showDebug = false}) {
                Label("Hide debug info", systemImage: SystemImages.eyeSlash.rawValue)
            }
            Text("\(space.rooms.count) rooms in the Stream")
            let rooms: [Matrix.Room] = space.rooms.values.sorted { $0.timestamp < $1.timestamp }
            ForEach(rooms) { room in
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
    
    private func filter(_ message: Matrix.Message) -> Bool {
        if message.relatedEventId != nil {
            return false
        }
        
        // Filter out messages from the future
        if message.timestamp > cutoff {
            return false
        }
        
        // This is the more advanced version, where we filter based on power levels
        // This would allow having a circle for an organization, where multiple people can post
        // But it's more complex, more fragile, and we don't have any UI for making these posts yet anyway
        // So for now we do the simple thing and filter for the room creator's user id instead
        /*
        let sender = message.sender
        let room = message.room
        
        guard let powerLevels = room.powerLevels,
              let userPower = powerLevels.users?[sender.userId] ?? powerLevels.usersDefault
        else {
            return false
        }

        return userPower > 50
        */
        
        if message.sender.userId != message.room.creator {
            return false
        }
        
        // Omit ignored senders
        if message.room.session.ignoredUserIds.contains(message.sender.userId) {
            return false
        }
        
        return true
    }
    
    var body: some View {
        let messages: [Matrix.Message] = space.getCollatedTimeline(filter: self.filter).reversed()
        
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
                                if DebugModel.shared.debugMode && showDebug {
                                    let index: Int = messages.firstIndex(of: message)!
                                    Text("\(index)")
                                }
                                
                                MessageCard(message: message)
                            }
                            RepliesView(room: message.room, parent: message)
                        }
                    }
                    .padding(.horizontal, 3)
                    .padding(.vertical, 1)
                }
                .frame(maxWidth: TIMELINE_FRAME_MAXWIDTH)
            
                HStack(alignment: .bottom) {
                    Spacer()
                    if loading {
                        ProgressView("Loading...")
                    }
                    else if space.canPaginateRooms {
                        AsyncButton(action: {
                            self.loading = true
                            do {
                                try await space.paginateRooms()
                            } catch {
                                print("Failed to manually paginate rooms")
                            }
                            self.loading = false
                        }) {
                            Text("Load More")
                        }
                        .onAppear {
                            // Basically it's like we automatically click "Load More" for the user
                            self.loading = true
                            let _ = Task {
                                do {
                                    try await space.paginateRooms()
                                } catch {
                                    print("Failed to automatically paginate rooms")
                                }
                                self.loading = false
                            }
                        }
                    } else if DebugModel.shared.debugMode {
                        Text("Not currently loading; Can't paginate rooms")
                            .foregroundColor(.red)
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
                
                async let results = space.rooms.values.map { room in
                    print("REFRESH\tLoading latest messages from \(room.name ?? room.roomId.stringValue)")

                    return try? await room.getMessages(forward: false)
                }
                let responses = await results
                print("REFRESH\tGot \(responses.count) responses from \(space.rooms.count) rooms")
                
                print("REFRESH\tWaiting for network requests to come in")
                try? await Task.sleep(for: .seconds(1))
                
                print("REFRESH\tDecrypting un-decrypted messages")
                async let decryptions = space.rooms.values.map { room in
                    var count = 0
                    for message in room.messages {
                        if message.type == M_ROOM_ENCRYPTED {
                            do {
                                try await message.decrypt()
                                count += 1
                            } catch {
                                print("Failed to decrypt message \(message.eventId) in room \(room.roomId)")
                            }
                        }
                    }
                    print("Decrypted \(count) messages in room \(room.roomId)")
                    return count
                }
                let decrypted = await decryptions
                
                print("REFRESH\tSending Combine update")
                await MainActor.run {
                    space.objectWillChange.send()
                }
            }

            if DebugModel.shared.debugMode {
                if showDebug {
                    debugFooter
                } else {
                    Button(action: {self.showDebug = true}) {
                        Label("Show debug info", systemImage: SystemImages.eye.rawValue)
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
