//
//  SubscriptionSettingsView.swift
//  Circles
//
//  Created by Charles Wright on 11/28/23.
//

import SwiftUI
import StoreKit

import Matrix

struct SubscriptionSettingsProductView: View {
    // From Apple's SKDemo https://developer.apple.com/videos/play/wwdc2021/10114/
    // https://developer.apple.com/documentation/storekit/in-app_purchase/implementing_a_store_in_your_app_using_the_storekit_api
    /*
    Copyright © 2023 Apple Inc.

    Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
    */
    
    @ObservedObject var store: AppStoreInterface
    var product: Product
    @Binding var selected: String?
    
    @State private var errorTitle = ""
    @State private var isShowingError: Bool = false
    
    private var unit: String? {
        guard let subscription = product.subscription
        else { return nil }
        
        let plural = 1 < subscription.subscriptionPeriod.value
        
        let u: String
        switch subscription.subscriptionPeriod.unit {
        case .day:
            u = plural ? "\(subscription.subscriptionPeriod.value) days" : "day"
        case .week:
            u = plural ? "\(subscription.subscriptionPeriod.value) weeks" : "week"
        case .month:
            u = plural ? "\(subscription.subscriptionPeriod.value) months" : "month"
        case .year:
            u = plural ? "\(subscription.subscriptionPeriod.value) years" : "year"
        @unknown default:
            u = "period"
        }
        return u
    }
    
    private func buy() async {
        do {
            if try await store.purchase(product) != nil {
                withAnimation {
                    selected = product.id
                }
            }
        } catch StoreError.failedVerification {
            errorTitle = "Your purchase could not be verified by the App Store."
            isShowingError = true
        } catch {
            print("Failed purchase for \(product.id): \(error)")
        }
    }
    
    @ViewBuilder
    private var subscribeButton: some View {
        AsyncButton(action: {
            print("User tapped \"\(product.displayName)\"")
            await buy()
        }) {
            VStack {
                if let unit = self.unit {
                    Text(product.displayPrice)
                        .foregroundColor(.white)
                        .bold()
                        .padding(EdgeInsets(top: -4.0, leading: 0.0, bottom: -8.0, trailing: 0.0))
                    Divider()
                        .background(Color.white)
                    Text(unit)
                        .foregroundColor(.white)
                        .font(.system(size: 12))
                        .padding(EdgeInsets(top: -8.0, leading: 0.0, bottom: -4.0, trailing: 0.0))
                } else {
                    Text(product.displayPrice)
                        .foregroundColor(.white)
                        .bold()
                }
            }
            .padding()
            .frame(maxWidth: 95)
            .foregroundColor(.white)
            .background(Color.accentColor)
            .cornerRadius(15)
        }
    }
    
    @ViewBuilder
    private var checkBox: some View {
        Text(Image(systemName: SystemImages.checkmark.rawValue))
            .bold()
            .padding()
            .frame(maxWidth: 95)
            .foregroundColor(.white)
            .background(Color.green)
            .cornerRadius(15)
    }
    
    var body: some View {
        HStack {
            let emoji = store.emoji(for: product.id)

            Text(emoji)
                .font(.system(size: 50))
                .frame(width: 50, height: 50)
                .padding(.trailing, 10)
            
            VStack(alignment: .leading) {
                Text(product.displayName)
                    .bold()
                Text(product.description)
                    .font(.subheadline)
            }
            
            Spacer()
            
            if selected == product.id {
                checkBox
            } else {
                subscribeButton
            }
        }
        .alert(isPresented: $isShowingError, content: {
            Alert(title: Text(errorTitle), message: nil, dismissButton: .default(Text("Okay")))
        })

    }
}

struct SubscriptionSettingsView: View {
    @ObservedObject var store: AppStoreInterface
    @State private var selected: String?
    
    // FIXME Hard-coding this for initial development - Get this from the UIA session params
    private let productIds = [
        "org.futo.circles.individual_monthly",
        "org.futo.circles.family_monthly",
        "org.futo.circles.individual_yearly",
        "org.futo.circles.family_yearly",
    ]
    @State private var products: [Product] = []
    
    @State private var redeemSheetIsPresented = false

    var body: some View {
        VStack(alignment: .leading) {
            Form {
                let individualProducts = products.filter({ !$0.isFamilyShareable }).sorted(by: { $0.price < $1.price })
                if !individualProducts.isEmpty {
                    Section("Individual Subscriptions") {
                        ForEach(individualProducts) { product in
                            SubscriptionSettingsProductView(store: store, product: product, selected: $selected)
                                .padding(.vertical, 5)
                        }
                    }
                    .listRowInsets(.init(top: 5, leading: 5, bottom: 5, trailing: 5))
                }
                
                let familyShareableProducts = products.filter({ $0.isFamilyShareable }).sorted(by: { $0.price < $1.price })
                if !familyShareableProducts.isEmpty {
                    Section("Family Shareable Subscriptions") {
                        ForEach(familyShareableProducts) { product in
                            SubscriptionSettingsProductView(store: store, product: product, selected: $selected)
                                .padding(.vertical, 5)
                        }
                    }
                    .listRowInsets(.init(top: 5, leading: 5, bottom: 5, trailing: 5))
                }
                
                #if DEBUG
                Section("Testing") {
                    Button(action: {
                        redeemSheetIsPresented = true
                    }) {
                        Text("Present offer sheet")
                    }
                    .offerCodeRedemption(isPresented: $redeemSheetIsPresented) { result in
                        // Handle result
                        print("Got result")
                        switch result {
                        case .success:
                            print("Yay offer code redemption was successful")
                        case .failure(let error):
                            print("Boo offer code redemtion failed: \(error)")
                        }
                    }
                }
                #endif
            }
            Spacer()
        }
        .task {
            if let products = try? await store.requestProducts(for: productIds) {
                print("Loaded \(products.count) products")
                await MainActor.run {
                    self.products = products
                }
                
                for product in products {
                    if store.isPurchased(product) {
                        print("Product \(product.id) is purchased")
                        await MainActor.run {
                            self.selected = product.id
                        }
                    }
                }
            } else {
                print("Failed to load products from the App Store")
            }
        }
        .navigationTitle("Subscription Settings")
    }
}

