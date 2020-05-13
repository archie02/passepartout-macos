//
//  ProductManager.swift
//  Passepartout-macOS
//
//  Created by Davide De Rosa on 10/11/19.
//  Copyright (c) 2020 Davide De Rosa. All rights reserved.
//
//  https://github.com/passepartoutvpn
//
//  This file is part of Passepartout.
//
//  Passepartout is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  Passepartout is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with Passepartout.  If not, see <http://www.gnu.org/licenses/>.
//

import Foundation
import StoreKit
import Convenience
import SwiftyBeaver

private let log = SwiftyBeaver.self

struct ProductManager {
    static let shared = ProductManager()
    
    private let inApp: InApp<Donation>
    
    private init() {
        inApp = InApp()
    }
    
    func listProducts(completionHandler: (([SKProduct]?, Error?) -> Void)?) {
        let products = Donation.all
        guard !products.isEmpty else {
            completionHandler?(nil, nil)
            return
        }
        inApp.requestProducts(withIdentifiers: products, completionHandler: { _ in
            log.debug("In-app products: \(self.inApp.products.map { $0.productIdentifier })")

            completionHandler?(self.inApp.products, nil)
        }, failureHandler: {
            completionHandler?(nil, $0)
        })
    }

    func purchase(_ product: SKProduct, completionHandler: @escaping (InAppPurchaseResult, Error?) -> Void) {
        inApp.purchase(product: product, completionHandler: completionHandler)
    }
}
