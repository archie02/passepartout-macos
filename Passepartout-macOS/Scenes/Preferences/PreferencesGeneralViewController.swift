//
//  PreferencesGeneralViewController.swift
//  Passepartout-macOS
//
//  Created by Davide De Rosa on 5/31/19.
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

class PreferencesGeneralViewController: NSViewController {
    @IBOutlet private weak var checkResolveHostname: NSButton!

    @IBOutlet private weak var labelResolveHostname: NSTextField!

    private let service = TransientStore.shared.service

    override func viewDidLoad() {
        super.viewDidLoad()
        
        checkResolveHostname.title = L10n.Core.Service.Cells.VpnResolvesHostname.caption
        labelResolveHostname.stringValue = L10n.Core.Service.Sections.VpnResolvesHostname.footer
    }
    
    @IBAction private func toggleResolvesHostname(_ sender: Any?) {
        service.preferences.resolvesHostname = (checkResolveHostname.state == .on)
        cycleVPNIfNeeded()
    }

    private func cycleVPNIfNeeded() {
        let vpn = GracefulVPN(service: service)
        guard vpn.isEnabled else {
            return
        }
//        guard vpn.status == .disconnected else {
//            confirmVpnReconnection()
//            return
//        }
        vpn.reinstall(completionHandler: nil)
    }
}
