//  Copyright 2020, 2021 Kombucha Digital Privacy Systems LLC
//
//  ChannelCreationSheet.swift
//  Circles for iOS
//
//  Created by Charles Wright on 11/14/20.
//

import SwiftUI
import PhotosUI
import Matrix

struct GroupCreationSheet: View {
    //@ObservedObject var store: KSStore
    @ObservedObject var groups: ContainerRoom<GroupRoom>
    @Environment(\.presentationMode) var presentation
    
    @State var groupName: String = ""
    @State var groupTopic: String = ""
    
    @State var newestUserId: String = ""
    @State var users: [Matrix.User] = []
    
    @State var headerImage: UIImage? = nil
    @State var showPicker = false
    @State var selectedItem: PhotosPickerItem?
    
    @State private var alertTitle: String = ""
    @State private var alertMessage: String = ""
    @State private var showAlert = false
    
    @FocusState var inputFocused
    
    func create() async throws {
        guard let roomId = try? await groups.createChild(name: self.groupName,
                                                         type: ROOM_TYPE_GROUP,
                                                         encrypted: true,
                                                         avatar: self.headerImage),
              let room = try await groups.session.getRoom(roomId: roomId)
        else {
            // Set error message
            return
        }
        
        if !self.groupTopic.isEmpty {
            do {
                try await room.setTopic(newTopic: self.groupTopic)
            } catch {
                // set error message
                return
            }
        }
        
        for user in self.users {
            do {
                try await room.invite(userId: user.userId)
            } catch {
                // set error message
                return
            }
        }
        
        self.presentation.wrappedValue.dismiss()
    }
    
    @ViewBuilder
    var buttonbar: some View {
        HStack {
            Button(action: {
                self.presentation.wrappedValue.dismiss()
            })
            {
                Text("Cancel")
            }
            
            Spacer()
        }
    }
    
    var body: some View {
        VStack {
            buttonbar
            let frameWidth = 200.0
            let frameHeight = 120.0
      
            ZStack {
                if let img = self.headerImage {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: frameWidth, maxHeight: frameHeight)

                } else {
                    Color.gray
                }

                VStack {
                    Text(self.groupName)
                        .font(.title)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                        .foregroundColor(Color.white)
                        .shadow(color: Color.black, radius: 3.0)
                        .padding()
                    
                    Text(self.groupTopic)
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                        .foregroundColor(Color.white)
                        .shadow(color: Color.black, radius: 3.0)
                        .padding(.horizontal)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .frame(maxWidth: frameWidth, maxHeight: frameHeight)
            .overlay(alignment: .bottomTrailing) {
                
                PhotosPicker(selection: $selectedItem, matching: .images) {
                    Image(systemName: "pencil.circle.fill")
                        .symbolRenderingMode(.multicolor)
                        .font(.system(size: 30))
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(.borderless)

            }
            .onChange(of: selectedItem) { newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                       let img = UIImage(data: data)
                    {
                        await MainActor.run {
                            self.headerImage = img
                        }
                    }
                }
            }
            
            TextField("Group name", text: $groupName)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .focused($inputFocused)
                .padding(.horizontal)
                .onAppear {
                    self.inputFocused = true
                }
            
            Spacer()

            AsyncButton(action: {
                try await create()
            })
            {
                Text("Create group")
                    .padding()
                    .frame(width: 300.0, height: 40.0)
                    .foregroundColor(.white)
                    .background(Color.accentColor)
                    .cornerRadius(10)
            }
            .disabled(groupName.isEmpty)
            
            Spacer()

        }
        .padding()
    }
    
}

/*
struct ChannelCreationSheet_Previews: PreviewProvider {
    static var previews: some View {
        ChannelCreationSheet()
    }
}
*/
