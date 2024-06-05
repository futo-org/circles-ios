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
    @State private var errorMessage = ""
        
    private var showErrorMessageView: some View {
        VStack {
            if errorMessage != "" {
                ToastView(titleMessage: errorMessage)
                Text("")
                    .onAppear {
                        errorMessage = ""
                    }
            }
        }
    }
    
    var body: some View {
        VStack {
            showErrorMessageView
            Form {
                HStack {
                    Text("Profile picture")
                    Spacer()
                    
                    PhotosPicker(selection: $newAvatarImageItem, matching: .images) {
                        UserAvatarView(user: session.me)
                            .clipShape(Circle())
                            .frame(width: 80, height: 80)
                    }
                    .buttonStyle(.plain)
                    .onChange(of: newAvatarImageItem) { _ in
                        Task {
                            if let data = try? await newAvatarImageItem?.loadTransferable(type: Data.self) {
                                if let img = UIImage(data: data) {
                                    do {
                                        try await session.setMyAvatarImage(img)
                                    } catch {
                                        errorMessage = error.localizedDescription
                                    }
                                }
                            }
                        }
                    }
                }
                
                NavigationLink(destination: UpdateDisplaynameView(session: session)) {
                    Text("Your name")
                        .badge(session.me.displayName ?? "(none)")
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
