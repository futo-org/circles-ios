//  Copyright 2023 FUTO Holdings Inc
//
//  PhotoDetailView.swift
//  Circles
//
//  Created by Charles Wright on 4/18/23.
//

import Foundation
import SwiftUI

import Matrix

struct PhotoDetailView: View {
    @ObservedObject var message: Matrix.Message
    @State var fullres: UIImage?
    
    @Environment(\.presentationMode) var presentation
    //@GestureState private var magnifyBy = 1.0
    @State var magnifyBy = 1.0
    @State private var viewPort = CGSize.zero
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
        ZStack {
            if let image = fullres {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(magnifyBy)
                    .offset(x: viewPort.width, y: viewPort.height)
                    .gesture(DragGesture()
                        .onChanged { value in
                            self.viewPort = value.translation
                        }
                    )
                    .gesture(MagnificationGesture()
                        .onChanged { value in
                            self.magnifyBy = value
                        }
                    )
            } else {
                ZStack {
                    let thumb = message.thumbnail ?? UIImage()
                    Image(uiImage: thumb)
                        .resizable()
                        .scaledToFit()
                    ProgressView()
                        .scaleEffect(4)
                }
            }
            
            VStack {
                HStack {
                    Button(action: {
                        self.presentation.wrappedValue.dismiss()
                    }) {
                        Text("Close")
                            .font(.subheadline)
                    }
                    .padding()
                    Spacer()
                    Button(action: {
                        let newScale = [self.magnifyBy * 0.75, 0.25].max() ?? 1.0
                        self.magnifyBy = newScale
                    }) {
                        Image(systemName: "minus.magnifyingglass")
                    }
                    Button(action: {
                        let newScale = [self.magnifyBy * 1.25, 4.0].min() ?? 1.0
                        self.magnifyBy = newScale
                    }) {
                        Image(systemName: "plus.magnifyingglass")
                    }
                    .padding(.trailing)
                }
                .buttonStyle(.bordered)

                Spacer()
            }
        }
        .onAppear {
            guard let content = message.content as? Matrix.mImageContent
            else {
                print("Error: Failed to get m.image content for detailed view")
                return
            }
            guard self.fullres == nil
            else {
                // Nothing to do
                return
            }
            Task {
                if let file = content.file {
                    do {
                        let data = try await message.room.session.downloadAndDecryptData(file)
                        let image = UIImage(data: data)
                        await MainActor.run {
                            self.fullres = image
                        }
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                } else if let url = content.url {
                    do {
                        let data = try await message.room.session.downloadData(mxc: url)
                        let image = UIImage(data: data)
                        await MainActor.run {
                            self.fullres = image
                        }
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
            }
        }
    }
    
}
