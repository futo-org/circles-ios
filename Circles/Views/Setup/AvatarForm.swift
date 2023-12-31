//
//  AvatarForm.swift
//  Circles
//
//  Created by Charles Wright on 9/7/21.
//

import SwiftUI
import PhotosUI

struct AvatarForm: View {
    var session: SetupSession

    @State var displayName = ""
    @State var avatarImage: UIImage?
    @State var showPicker = false
    @State var showCamera = false
    //@State var pickerSourceType: UIImagePickerController.SourceType = .photoLibrary
    @State var selectedItem: PhotosPickerItem?

    @State var pending = false

    let stage = "avatar"

    var avatar: Image {
        if let img = self.avatarImage {
            return Image(uiImage: img)
        } else {
            return Image(systemName: "person.crop.square")
        }
    }

    var body: some View {
        VStack {
            //let currentStage: SignupStage = .getAvatarImage

            Spacer()

            Text("Set up your profile")
                .font(.title)
                .fontWeight(.bold)
                
            avatar
                .resizable()
                .scaledToFill()
                .frame(width: 200, height: 200, alignment: .center)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .task {
                    // Check to see -- Does this user already have an avatar image?
                    let userId = session.client.creds.userId
                    if let image = try? await session.client.getAvatarImage(userId: userId) {
                        await MainActor.run {
                            self.avatarImage = image
                        }
                    }
                }
                .overlay(alignment: .bottomTrailing) {
                    Menu {
                        
                        Button(action: {
                            self.showPicker = true
                        }) {
                            Label("Choose a photo", systemImage: "photo.fill")

                        }
                        
                        Button(action: {
                            self.showCamera = true
                        }) {
                            Label("Take a new photo", systemImage: "camera")
                        }
                        .sheet(isPresented: $showCamera) {
                            ImagePicker(selectedImage: $avatarImage, sourceType: .camera)
                        }
                    }
                    label: {
                        Image(systemName: "pencil.circle.fill")
                            .symbolRenderingMode(.multicolor)
                            .font(.system(size: 30))
                            .foregroundColor(.accentColor)
                    }
                }
                .photosPicker(isPresented: $showPicker, selection: $selectedItem)
                .onChange(of: selectedItem) { newItem in
                    Task {
                        if let data = try? await newItem?.loadTransferable(type: Data.self),
                           let img = UIImage(data: data)
                        {
                            await MainActor.run {
                                self.avatarImage = img
                            }
                        }
                    }
                }
                

                
            Label("NOTE: Profile photos are not encrypted", systemImage: "exclamationmark.triangle")
                .foregroundColor(.orange)

            
            TextField("First Last", text: $displayName, prompt: Text("Your name"))
                .textContentType(.name)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.words)
                .frame(width: 300)
                .padding()
                /*
                .task {
                    let userId = session.client.creds.userId
                    if let name = try? await session.client.getDisplayName(userId: userId) {
                        await MainActor.run {
                            self.displayName = name
                        }
                    }
                }
                */

            AsyncButton(action: {
                try await session.setupProfile(name: displayName, avatar: avatarImage)
            }) {
                Text("Next")
                    .padding()
                    .frame(width: 300.0, height: 40.0)
                    .foregroundColor(.white)
                    .background(Color.accentColor)
                    .cornerRadius(10)
            }
            .disabled(displayName.isEmpty)
            .padding()

            Spacer()
        }
    }
}

/*
struct AvatarForm_Previews: PreviewProvider {
    static var previews: some View {
        AvatarForm()
    }
}
*/
