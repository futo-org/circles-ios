//  Copyright 2020, 2021 Kombucha Digital Privacy Systems LLC
//
//  CirclesApp.swift
//  Circles for iOS
//
//  Created by Charles Wright on 5/25/21.
//

import SwiftUI
import StoreKit
import Matrix

@main
struct CirclesApp: App {
    @StateObject private var store = CirclesStore()
    private var paymentQueue = SKPaymentQueue.default()
    private var countryCode = SKPaymentQueue.default().storefront?.countryCode
    
    init() {
        // We need to register all of our custom types with the Matrix library, so it can decode them for us
        Matrix.registerAccountDataType(EVENT_TYPE_CIRCLES_CONFIG, CirclesConfigContent.self)
    }

    var body: some Scene {
        WindowGroup {
            ContentView(store: store)
                .environmentObject(store)
                /*
                .environmentObject(iapObserver)
                .onAppear {

                    
                    // For some strange reason, I'm getting nil for the storefront on the first run of the app.
                    // What if we just do some thing really stupid here and ask for it here well before we actually need it?
                    if let storefront = SKPaymentQueue.default().storefront {
                        let countryCode = storefront.countryCode
                        print("APP\tGot country code = \(countryCode)")
                    } else {
                        print("APP\tCouldn't get country code from StoreKit")
                    }

                    SKPaymentQueue.default().add(iapObserver)

                }
                .onDisappear {
                    SKPaymentQueue.default().remove(iapObserver)
                }
                */
        }
    }
}
