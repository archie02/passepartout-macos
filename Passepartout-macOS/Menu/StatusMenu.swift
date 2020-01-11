//
//  StatusMenu.swift
//  Passepartout-macOS
//
//  Created by Davide De Rosa on 8/14/19.
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

import Cocoa
import PassepartoutCore
import TunnelKit
import Convenience

class StatusMenu: NSObject {
    static let shared = StatusMenu()

    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

    let menu = NSMenu()
    
    private let service = TransientStore.shared.service
    
    private var vpn: GracefulVPN {
        return GracefulVPN(service: service)
    }

    // MARK: Button images

    private let imageStatus = Asset.Assets.statusBarButtonImage.image

    private lazy var imageStatusActive: NSImage = imageStatus.tinted(withColor: Theme.current.palette.colorOn)

    private lazy var imageStatusInactive: NSImage = imageStatus.tinted(withColor: Theme.current.palette.colorPrimaryText)

    private lazy var imageStatusInProgress: NSImage = imageStatus.tinted(withColor: Theme.current.palette.colorIndeterminate)

    // MARK: Item references
    
    private var itemProfileName: NSMenuItem?

    private var itemsProfile: [NSMenuItem] = []

    private var itemToggleVPN: NSMenuItem?

    private var itemReconnectVPN: NSMenuItem?
    
    private override init() {
        super.init()
        
        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(vpnDidUpdate), name: .VPNDidChangeStatus, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    func install() {
        guard let button = statusItem.button else {
            return
        }
        button.image = imageStatus
        
        VPN.shared.prepare {
            self.rebuild()
            self.statusItem.menu = self.menu
        }
    }
    
    private func rebuild() {
        menu.removeAllItems()

        // main windows
        
        let itemAbout = NSMenuItem(title: L10n.Core.Organizer.Cells.About.caption(GroupConstants.App.name), action: #selector(showAbout), keyEquivalent: "")
        let itemOrganizer = NSMenuItem(title: L10n.App.Menu.Organizer.title.asContinuation, action: #selector(showOrganizer), keyEquivalent: "o")
        let itemPreferences = NSMenuItem(title: L10n.App.Menu.Preferences.title.asContinuation, action: #selector(showPreferences), keyEquivalent: ",")
        itemAbout.target = self
        itemOrganizer.target = self
        itemPreferences.target = self
        menu.addItem(itemAbout)
        menu.addItem(itemOrganizer)
        menu.addItem(itemPreferences)
        menu.addItem(.separator())
        
        // active profile
        
        itemProfileName = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        menu.addItem(itemProfileName!)
        setActiveProfile(service.activeProfile)
        menu.addItem(.separator())
        
        // support
        
        let menuSupport = NSMenu()
        let itemCommunity = NSMenuItem(title: L10n.Core.Organizer.Cells.JoinCommunity.caption.asContinuation, action: #selector(joinCommunity), keyEquivalent: "")
        let itemReview = NSMenuItem(title: L10n.Core.Organizer.Cells.WriteReview.caption.asContinuation, action: #selector(writeReview), keyEquivalent: "")
        let itemDonate = NSMenuItem(title: L10n.Core.Organizer.Cells.Donate.caption.asContinuation, action: #selector(showDonations), keyEquivalent: "")
//        let itemPatreon = NSMenuItem(title: L10n.Core.Organizer.Cells.Patreon.caption.asContinuation, action: #selector(seePatreon), keyEquivalent: "")
        let itemTranslate = NSMenuItem(title: L10n.Core.Organizer.Cells.Translate.caption.asContinuation, action: #selector(offerToTranslate), keyEquivalent: "")
        let itemFAQ = NSMenuItem(title: L10n.Core.About.Cells.Faq.caption.asContinuation, action: #selector(visitFAQ), keyEquivalent: "")
        let itemReport = NSMenuItem(title: L10n.Core.Service.Cells.ReportIssue.caption.asContinuation, action: #selector(reportConnectivityIssue), keyEquivalent: "")
        itemCommunity.target = self
        itemReview.target = self
        itemDonate.target = self
//        itemPatreon.target = self
        itemTranslate.target = self
        itemFAQ.target = self
        itemReport.target = self
        menuSupport.addItem(itemDonate)
        menuSupport.addItem(itemCommunity)
        menuSupport.addItem(.separator())
//        menuSupport.addItem(itemPatreon)
//        menuSupport.addItem(itemTranslate)
        menuSupport.addItem(itemReview)
        menuSupport.addItem(.separator())
        menuSupport.addItem(itemFAQ)
        menuSupport.addItem(itemReport)
        let itemSupport = NSMenuItem(title: L10n.App.Menu.Support.title, action: nil, keyEquivalent: "")
        menu.setSubmenu(menuSupport, for: itemSupport)
        menu.addItem(itemSupport)
        menu.addItem(.separator())

        // quit
        
        let itemQuit = NSMenuItem(title: L10n.App.Menu.Quit.title(GroupConstants.App.name), action: #selector(quit), keyEquivalent: "q")
        itemQuit.target = self
        menu.addItem(itemQuit)
    }
    
    func setActiveProfile(_ profile: ConnectionProfile?) {
        let startIndex = menu.index(of: itemProfileName!)
        var i = startIndex + 1
        
        for item in itemsProfile {
            menu.removeItem(item)
        }
        itemsProfile.removeAll()

        guard let profile = profile else {
            itemProfileName?.title = L10n.App.Menu.ActiveProfile.Title.none
//            itemProfileName?.image = nil
            itemToggleVPN = nil
            itemReconnectVPN = nil
            return
        }
        
        itemProfileName?.title = profile.id
//        itemProfileName?.image = profile.image
        
        let needsCredentials = service.needsCredentials(for: profile)
        if !needsCredentials {
            itemToggleVPN = NSMenuItem(title: L10n.App.Service.Cells.Vpn.TurnOn.caption, action: nil, keyEquivalent: "")
            itemReconnectVPN = NSMenuItem(title: L10n.Core.Service.Cells.Reconnect.caption, action: #selector(reconnectVPN), keyEquivalent: "")
            itemToggleVPN?.indentationLevel = 1
            itemReconnectVPN?.indentationLevel = 1
            itemToggleVPN?.target = self
            itemReconnectVPN?.target = self
            menu.insertItem(itemToggleVPN!, at: i)
            i += 1
            menu.insertItem(itemReconnectVPN!, at: i)
            i += 1

            itemsProfile.append(itemToggleVPN!)
            itemsProfile.append(itemReconnectVPN!)
        } else {
            let itemMissingCredentials = NSMenuItem(title: L10n.App.Menu.ActiveProfile.Messages.missingCredentials, action: nil, keyEquivalent: "")
            itemMissingCredentials.indentationLevel = 1
            menu.insertItem(itemMissingCredentials, at: i)
            i += 1
            itemsProfile.append(itemMissingCredentials)
        }

        updateUIWithVPNStatus()

        if !needsCredentials, let providerProfile = profile as? ProviderConnectionProfile {

            // endpoint (port only)
            let itemEndpoint = NSMenuItem(title: L10n.Core.Endpoint.title, action: nil, keyEquivalent: "")
            itemEndpoint.indentationLevel = 1
            let menuEndpoint = NSMenu()
            
            // automatic
            let itemEndpointAutomatic = NSMenuItem(title: L10n.Core.Endpoint.Cells.AnyProtocol.caption, action: #selector(connectToEndpoint(_:)), keyEquivalent: "")
            itemEndpointAutomatic.target = self
            if providerProfile.manualProtocol == nil {
                itemEndpointAutomatic.state = .on
            }
            menuEndpoint.addItem(itemEndpointAutomatic)
            
            for proto in profile.protocols {
                let item = NSMenuItem(title: proto.description, action: #selector(connectToEndpoint(_:)), keyEquivalent: "")
                item.representedObject = proto
                item.target = self
                if providerProfile.manualProtocol == proto {
                    item.state = .on
                }
                menuEndpoint.addItem(item)
            }
            menu.setSubmenu(menuEndpoint, for: itemEndpoint)
            menu.insertItem(itemEndpoint, at: i)
            i += 1
            itemsProfile.append(itemEndpoint)

            let itemSep1: NSMenuItem = .separator()
            menu.insertItem(itemSep1, at: i)
            i += 1
            itemsProfile.append(itemSep1)

//            guard poolDescription = providerProfile.pool?.localizedId else {
//                fatalError("No pool selected?")
//            }
            let itemPool = NSMenuItem(title: providerProfile.pool?.localizedId ?? "", action: nil, keyEquivalent: "")
            menu.insertItem(itemPool, at: i)
            i += 1
            itemsProfile.append(itemPool)
            
            let infrastructure = providerProfile.infrastructure
            for category in infrastructure.categories {
                let title = category.name.isEmpty ? L10n.App.Global.Values.default : category.name.capitalized
                let submenu = NSMenu()
                let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
                item.indentationLevel = 1
                
                for group in category.groups.sorted() {
                    var title = group.localizedCountry
                    if let area = group.area?.uppercased() {
                        title = "\(title) - \(area)"
                    }

                    let itemGroup = NSMenuItem(title: title, action: #selector(connectToPool(_:)), keyEquivalent: "")
                    itemGroup.target = self
                    itemGroup.representedObject = group
                    
                    for pool in group.pools {
                        if pool.id == providerProfile.poolId {
                            itemGroup.state = .on
                            break
                        }
                    }
                    submenu.addItem(itemGroup)
                }
                menu.setSubmenu(submenu, for: item)
                menu.insertItem(item, at: i)
                i += 1
                itemsProfile.append(item)
            }
        } else {
            let itemSep1: NSMenuItem = .separator()
            menu.insertItem(itemSep1, at: i)
            i += 1
            itemsProfile.append(itemSep1)
        }
    }
    
    // MARK: Actions

    @objc private func showAbout() {
        WindowManager.shared.showAbout()
    }

    @objc private func showOrganizer() {
        WindowManager.shared.showOrganizer()
    }
    
    @objc private func showPreferences() {
        let organizer = WindowManager.shared.showOrganizer()
        let preferences = StoryboardScene.Preferences.initialScene.instantiate()
        organizer?.contentViewController?.presentAsModalWindow(preferences)
    }

    @objc private func enableVPN() {
        vpn.reconnect(completionHandler: nil)
    }

    @objc private func disableVPN() {
        vpn.disconnect(completionHandler: nil)
    }
    
    @objc private func reconnectVPN() {
        vpn.reconnect(completionHandler: nil)
    }
    
    @objc private func connectToPool(_ sender: Any?) {
        guard let item = sender as? NSMenuItem else {
            return
        }
        guard let group = item.representedObject as? PoolGroup else {
            return
        }
        guard let profile = service.activeProfile as? ProviderConnectionProfile else {
            return
        }
        assert(!group.pools.isEmpty)
        profile.poolId = group.pools.randomElement()!.id
        vpn.reconnect(completionHandler: nil)
        
        // update menu
        setActiveProfile(profile)
    }
    
    @objc private func connectToEndpoint(_ sender: Any?) {
        guard let item = sender as? NSMenuItem else {
            return
        }
        guard let profile = service.activeProfile as? ProviderConnectionProfile else {
            return
        }
        profile.manualProtocol = item.representedObject as? EndpointProtocol
        vpn.reconnect(completionHandler: nil)

        // update menu
        setActiveProfile(profile)
    }

    @objc private func joinCommunity() {
        NSWorkspace.shared.open(AppConstants.URLs.subreddit)
    }

    @objc private func writeReview() {
        let url = Reviewer.urlForReview(withAppId: AppConstants.App.appStoreId)
        NSWorkspace.shared.open(url)
    }
    
    @objc private func showDonations() {
        // TODO
    }

    @objc private func seePatreon() {
        NSWorkspace.shared.open(AppConstants.URLs.patreon)
    }

    @objc private func offerToTranslate() {
        let V = AppConstants.Translations.Email.self
        let recipient = V.recipient
        let subject = V.subject
        let body = V.body(V.template)

        guard let url = URL.mailto(to: recipient, subject: subject, body: body) else {
            return
        }
        NSWorkspace.shared.open(url)
    }
    
    @objc private func visitFAQ() {
        NSWorkspace.shared.open(AppConstants.URLs.faq)
    }
    
    @objc private func reportConnectivityIssue() {
        let issue = Issue(debugLog: true, profile: TransientStore.shared.service.activeProfile)
        IssueReporter.shared.present(withIssue: issue)
    }
    
    @objc private func quit() {
        NSApp.terminate(self)
    }

    // MARK: Notifications
    
    @objc private func vpnDidUpdate() {
        reloadVpnStatus()
    }
    
    // MARK: Helpers
    
    private func reloadVpnStatus() {
        guard service.hasActiveProfile() else {
            return
        }
        updateUIWithVPNStatus()
    }
    
    private func updateUIWithVPNStatus() {
        switch vpn.status ?? .disconnected {
        case .connected:
            itemToggleVPN?.title = L10n.App.Service.Cells.Vpn.TurnOff.caption
            itemToggleVPN?.action = #selector(disableVPN)
            statusItem.button?.image = imageStatusActive
            
            Reviewer.shared.reportEvent()

        case .connecting:
            itemToggleVPN?.title = L10n.App.Service.Cells.Vpn.TurnOff.caption
            itemToggleVPN?.action = #selector(disableVPN)
            statusItem.button?.image = imageStatusInProgress

        case .disconnected:
            itemToggleVPN?.title = L10n.App.Service.Cells.Vpn.TurnOn.caption
            itemToggleVPN?.action = #selector(enableVPN)
            statusItem.button?.image = imageStatusInactive

        case .disconnecting:
            itemToggleVPN?.action = nil
            statusItem.button?.image = imageStatusInProgress
        }
    }
}
