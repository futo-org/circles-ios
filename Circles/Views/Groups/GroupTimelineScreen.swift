//  Copyright 2020, 2021 Kombucha Digital Privacy Systems LLC
//  Copyright 2022 FUTO Holdings, Inc
//
//  GroupTimelineScreen.swift
//  Circles for iOS
//
//  Created by Charles Wright on 11/3/20.
//

import SwiftUI
import Matrix

enum GroupScreenSheetType: String {
    case invite
    case composer
    case share
}
extension GroupScreenSheetType: Identifiable {
    var id: String { rawValue }
}

struct GroupTimelineScreen: View {
    @ObservedObject var room: Matrix.Room
    //@ObservedObject var group: SocialGroup
    @Environment(\.presentationMode) var presentation
    @AppStorage("debugMode") var debugMode: Bool = false
    
    @State var showComposer = false

    @State private var sheetType: GroupScreenSheetType? = nil

    @State private var newImageForHeader = UIImage()
    @State private var newImageForProfile = UIImage()
    @State private var newImageForMessage = UIImage()
    
    @State private var confirmNewProfileImage = false
    @State private var confirmNewHeaderImage = false
    
    @State private var newTopic = ""
    @State private var showTopicPopover = false

    @State var nilParentMessage: Matrix.Message? = nil
    
    var timeline: some View {
        TimelineView<MessageCard>(room: room)
    }
    
    var toolbarMenu: some View {
        Menu {
            
            NavigationLink(destination: GroupSettingsView(room: room)) {
                Label("Settings", systemImage: "gearshape")
            }
            
            if room.iCanInvite {
                Button(action: {
                    self.sheetType = .invite
                }) {
                    Label("Invite new members", systemImage: "person.crop.circle.badge.plus")
                }
            }
            
            Button(action: {
                self.sheetType = .share
            }) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            
        }
        label: {
            Label("Settings", systemImage: "gearshape.fill")
        }
    }
    
    var title: Text {
        Text(room.name ?? "(Unnamed Group)")
    }
    
    var body: some View {
        
        NavigationStack {
            ZStack {
                
                VStack(alignment: .center) {
                    
                    /*
                     VStack(alignment: .leading) {
                     Text("Debug Info")
                     Text("roomId: \(group.room.id)")
                     Text("type: \(group.room.type ?? "(none)")")
                     }
                     .font(.footnote)
                     */
                    
                    if !room.knockingMembers.isEmpty {
                        RoomKnockIndicator(room: room)
                    }
                    
                    timeline
                        .sheet(item: $sheetType) { st in
                            switch(st) {
                                
                            case .invite:
                                RoomInviteSheet(room: room, title: "Invite new members to \(room.name ?? "(unnamed group)")")
                                
                            case .composer:
                                PostComposerSheet(room: room, parentMessage: nilParentMessage)
                                
                            case .share:
                                let url = URL(string: "https://\(CIRCLES_PRIMARY_DOMAIN)/group/\(room.roomId.stringValue)")
                                RoomShareSheet(room: room, url: url)
                            }
                        }
                }
                
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: {
                            self.sheetType = .composer
                        }) {
                            Image(systemName: "plus.bubble.fill")
                                .resizable()
                                .scaledToFill()
                                .frame(width: 50, height: 50)
                                .padding()
                        }
                    }
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .automatic) {
                    toolbarMenu
                }
            }
            .navigationBarTitle(title, displayMode: .inline)
        }
    }
}

/*
struct ChannelView_Previews: PreviewProvider {
    static var previews: some View {
        ChannelView()
    }
}
 */
