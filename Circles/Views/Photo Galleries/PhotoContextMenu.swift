//  Copyright 2023 FUTO Holdings Inc
//
//  PhotoContextMenu.swift
//  Circles
//
//  Created by Charles Wright on 4/18/23.
//

import Foundation
import SwiftUI

import Matrix

struct PhotoContextMenu: View {
    var message: Matrix.Message
    @Binding var showDetail: Bool
    var onErrorMessage: (String) -> Void
    
    var body: some View {
        let current = message.replacement ?? message
        
        if let content = current.content as? Matrix.MessageContent,
           content.msgtype == M_IMAGE,
           let imageContent = content as? Matrix.mImageContent
        {
            AsyncButton(action: {
                do {
                    try await saveImage(content: imageContent, session: message.room.session)
                } catch {
                    onErrorMessage(error.localizedDescription)
                }
            }) {
                Label("Save image", systemImage: "square.and.arrow.down")
            }

            if let thumbnail = current.thumbnail
            {
                let image = Image(uiImage: thumbnail)
                ShareLink(item: image, preview: SharePreview(imageContent.caption ?? "", image: image))
            }
        }
        
        Button(action: {
            message.objectWillChange.send()
        }) {
            Label("Refresh", systemImage: "arrow.clockwise")
        }
        
        Button(action: {
            self.showDetail = true
        }) {
            Label("Show detailed view", systemImage: "magnifyingglass")
        }
        
        if message.iCanRedact {
            AsyncButton(action: {
                do {
                    try await deleteAndPurge(message: message)
                } catch {
                    onErrorMessage(error.localizedDescription)
                }
            }) {
                Label("Delete", systemImage: "trash")
            }
            .foregroundColor(.red)
        }
    }
}
