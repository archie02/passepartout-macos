//
//  DebugLogViewController.swift
//  Passepartout-macOS
//
//  Created by Davide De Rosa on 7/31/18.
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

class DebugLogViewController: NSViewController {
    @IBOutlet private weak var labelExchangedCaption: NSTextField!

    @IBOutlet private weak var labelExchanged: NSTextField!
    
    @IBOutlet private weak var checkMasking: NSButton!

    @IBOutlet private weak var labelLog: NSTextField!

    @IBOutlet private weak var scrollTextLog: NSScrollView!
    
    @IBOutlet private var textLog: NSTextView!

    @IBOutlet private weak var textFinderLog: NSTextFinder!

    @IBOutlet private weak var buttonPrevious: NSButton!

    @IBOutlet private weak var buttonNext: NSButton!
    
    @IBOutlet private weak var buttonShare: NSButton!

    private let service = TransientStore.shared.service
    
    private let vpn = VPN.shared
    
    private var tmpDebugURL: URL?
    
    private var shouldDeleteLogOnDisconnection = false
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = L10n.Core.Service.Cells.DebugLog.caption

        checkMasking.title = L10n.Core.Service.Cells.MasksPrivateData.caption
        checkMasking.state = (TransientStore.masksPrivateData ? .on : .off)

        labelExchangedCaption.stringValue = L10n.Core.Service.Cells.DataCount.caption.asCaption
        labelLog.stringValue = L10n.Core.Service.Cells.DebugLog.caption.asCaption
//        scrollTextLog.scrollerStyle = .overlay
//        scrollTextLog.autohidesScrollers = false
        textLog.font = NSFont(name: "Courier New", size: NSFont.systemFontSize(for: .regular))
        if #available(macOS 10.12.2, *) {
            buttonPrevious.image = NSImage(named: NSImage.touchBarRewindTemplateName)
            buttonNext.image = NSImage(named: NSImage.touchBarFastForwardTemplateName)
        } else {
            buttonPrevious.title = L10n.Core.DebugLog.Buttons.previous
            buttonNext.title = L10n.Core.DebugLog.Buttons.next
        }
        buttonShare.image = NSImage(named: NSImage.shareTemplateName)
        
        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(vpnDidPrepare), name: .VPNDidPrepare, object: nil)
        nc.addObserver(self, selector: #selector(vpnDidUpdate), name: .VPNDidChangeStatus, object: nil)
        nc.addObserver(self, selector: #selector(serviceDidUpdateDataCount), name: ConnectionService.didUpdateDataCount, object: nil)

        if vpn.isPrepared {
            startRefreshingLog()
        }
        refreshDataCount()
    }

    @IBAction private func toggleMasking(_ sender: Any?) {
        let isOn = (self.checkMasking.state == .on)
        let handler = {
            TransientStore.masksPrivateData = isOn
            self.service.baseConfiguration = TransientStore.baseVPNConfiguration.build()
        }
        
        guard vpn.status == .disconnected else {
            let alert = Macros.warning(
                L10n.Core.Service.Cells.MasksPrivateData.caption,
                L10n.Core.Service.Alerts.MasksPrivateData.Messages.mustReconnect
            )
            alert.present(in: view.window, withOK: L10n.Core.Service.Alerts.Buttons.reconnect, cancel: L10n.Core.Global.cancel, handler: {
                handler()
                self.shouldDeleteLogOnDisconnection = true
                
                do {
                    self.vpn.reconnect(configuration: try self.service.vpnConfiguration(), completionHandler: nil)
                } catch {
                }
            }, cancelHandler: {
                self.checkMasking.state = (isOn ? .off : .on)
            })
            return
        }
        
        handler()
        service.eraseVpnLog()
        shouldDeleteLogOnDisconnection = false
    }

    @IBAction private func share(_ sender: Any?) {
        let text = textLog.string
        guard !text.isEmpty else {
            let alert = Macros.warning(
                L10n.Core.Service.Cells.DebugLog.caption,
                L10n.Core.DebugLog.Alerts.EmptyLog.message
            )
            alert.present(in: view.window, withOK: L10n.Core.Global.ok, handler: nil)
            return
        }
        let log = DebugLog(raw: text)
        let logString = log.decoratedString()
        let picker = NSSharingServicePicker(items: [logString])
        picker.show(relativeTo: buttonShare.bounds, of: buttonShare, preferredEdge: .minY)
    }
    
    @IBAction private func previousSession(_ sender: Any?) {
        textFinderLog.performAction(.previousMatch)
//        textLog.findPrevious(string: GroupConstants.Log.sessionMarker)
    }

    @IBAction private func nextSession(_ sender: Any?) {
        textFinderLog.performAction(.previousMatch)
//        textLog.findNext(string: GroupConstants.Log.sessionMarker)
    }
    
    private func startRefreshingLog() {
        let fallback: () -> String = { self.service.vpnLog }
        
        vpn.requestDebugLog(fallback: fallback) {
            self.textLog.string = $0
            
            DispatchQueue.main.async {
                self.textLog.scrollToEnd()
                self.refreshLogInBackground()
            }
        }
    }
    
    private func refreshLogInBackground() {
        let fallback: () -> String = { self.service.vpnLog }
        let updateBlock = {
            DispatchQueue.main.asyncAfter(deadline: .now() + AppConstants.Log.viewerRefreshInterval) { [weak self] in
                self?.refreshLogInBackground()
            }
        }
        
        // only update if screen is visible
        guard let _ = view.window else {
            updateBlock()
            return
        }
        
        vpn.requestDebugLog(fallback: fallback) {
            let wasEmpty = self.textLog.string.isEmpty
            self.textLog.string = $0
            updateBlock()
            if wasEmpty {
                self.textLog.scrollToEnd()
            }
        }
    }

    // MARK: Notifications
    
    @objc private func vpnDidPrepare() {
        startRefreshingLog()
    }
    
    @objc private func vpnDidUpdate() {
        switch vpn.status {
        case .disconnected:
            if shouldDeleteLogOnDisconnection {
                service.eraseVpnLog()
                shouldDeleteLogOnDisconnection = false
            }
            
        default:
            break
        }

        refreshDataCount()
    }

    @objc private func serviceDidUpdateDataCount() {
        refreshDataCount()
    }
    
    // MARK: Helpers
    
    private func refreshDataCount() {
        if let count = service.vpnDataCount, vpn.status == .connected {
            let down = count.0.dataUnitDescription
            let up = count.1.dataUnitDescription
            labelExchanged.stringValue = "↓\(down) / ↑\(up)"
        } else {
            labelExchanged.stringValue = L10n.Core.Service.Cells.DataCount.none
        }
    }
}
