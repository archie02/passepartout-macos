//
//  InApp.swift
//  Passepartout-macOS
//
//  Created by Davide De Rosa on 8/16/19.
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

enum Donation: String {
    case tiny = "com.algoritmico.macos.Passepartout.donations.Tiny"
    
    case small = "com.algoritmico.macos.Passepartout.donations.Small"
    
    case medium = "com.algoritmico.macos.Passepartout.donations.Medium"
    
    case big = "com.algoritmico.macos.Passepartout.donations.Big"
    
    case huge = "com.algoritmico.macos.Passepartout.donations.Huge"
    
    case maxi = "com.algoritmico.macos.Passepartout.donations.Maxi"

    static let all: [Donation] = [
        .tiny,
        .small,
        .medium,
        .big,
        .huge,
        .maxi
    ]
}
