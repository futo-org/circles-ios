//
//  SetupScreen.swift
//  Circles
//
//  Created by Charles Wright on 6/9/22.
//

import SwiftUI
import Matrix

struct SetupScreen: View {
    var store: CirclesStore
    @ObservedObject var matrix: Matrix.Session
    
    enum Stage {
        case profileSetup
        case circlesIntro
        case circlesSetup
    }
    @State var stage: Stage = .profileSetup
    
    @State var displayName: String?
    
    var body: some View {
        
        switch stage {
        case .profileSetup:
            SetupAvatarView(matrix: matrix, displayName: $displayName, stage: $stage)

        case .circlesIntro:
            SetupIntroToCircles(stage: $stage)
            
        case .circlesSetup:
            SetupCirclesView(store: store, matrix: matrix, user: matrix.me)

        }
        
    }
}

/*
struct SetupScreen_Previews: PreviewProvider {
    static var previews: some View {
        SetupScreen()
    }
}
*/
