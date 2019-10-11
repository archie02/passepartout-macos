//
//  HostServiceView.swift
//  Passepartout-macOS
//
//  Created by Davide De Rosa on 6/13/19.
//  Copyright (c) 2019 Davide De Rosa. All rights reserved.
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

import Cocoa
import PassepartoutCore

protocol HostServiceViewDelegate: class {
}

class HostServiceView: NSView {
    @IBOutlet private weak var labelAddressesCaption: NSTextField!
    
    @IBOutlet private weak var tableAddresses: NSTableView!
    
    var isEnabled: Bool = true {
        didSet {
        }
    }
    
    var profile: HostConnectionProfile? {
        didSet {
            tableAddresses.reloadData()
        }
    }
    
    weak var delegate: HostServiceViewDelegate?

    override func viewWillMove(toSuperview newSuperview: NSView?) {
        super.viewWillMove(toSuperview: newSuperview)
        
        labelAddressesCaption.stringValue = L10n.App.Service.Cells.Addresses.caption.asCaption
    }
    
    func reloadData() {
    }
}

extension HostServiceView: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int {
        guard let profile = profile else {
            return 0
        }
        return profile.addresses.count
    }
    
    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        guard let profile = profile else {
            return nil
        }
        return profile.addresses[row]
    }
    
    func tableView(_ tableView: NSTableView, setObjectValue object: Any?, for tableColumn: NSTableColumn?, row: Int) {
    }
}
