//
//  ProfileSettingsView.swift
//  Circles
//
//  Created by Charles Wright on 7/5/23.
//

import SwiftUI
import PhotosUI
import Matrix

struct ProfileSettingsView: View {
    @ObservedObject var session: Matrix.Session
    //@ObservedObject var user: Matrix.User
    
    @State var showPicker = false
    @State var newAvatarImageItem: PhotosPickerItem?
    
    var body: some View {
        VStack {
            Form {
                HStack {
                    Text("Profile picture")
                    Spacer()
                    
                    PhotosPicker(selection: $newAvatarImageItem, matching: .images) {
                        UserAvatarView(user: session.me)
                            .frame(width: 80, height: 80)
                    }
                    .buttonStyle(.plain)
                    .onChange(of: newAvatarImageItem) { _ in
                        Task {
                            if let data = try? await newAvatarImageItem?.loadTransferable(type: Data.self) {
                                if let img = UIImage(data: data) {
                                    try await session.setMyAvatarImage(img)
                                }
                            }
                        }
                    }
                }
                NavigationLink(destination: UpdateDisplaynameView(session: session)) {
                    Text("Your name")
                        .badge(abbreviate(session.me.displayName))
                }
                
                Text("User ID")
                    .badge(session.creds.userId.stringValue)
                
                /*
                NavigationLink(destination: UpdateStatusMessageView(session: session)) {
                    Text("Status message")
                        .badge(session.statusMessage ?? "(none)")
                }
                */
            }
        }
        .navigationTitle("Public Profile")
    }
}

/*
struct ProfileSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileSettingsView()
    }
}
*/
