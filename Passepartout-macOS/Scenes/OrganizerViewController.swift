//
//  OrganizerViewController.swift
//  Passepartout-macOS
//
//  Created by Davide De Rosa on 6/6/18.
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
import SwiftyBeaver

private let log = SwiftyBeaver.self

class OrganizerViewController: NSViewController {
    @IBOutlet private weak var viewProfiles: NSView!

    private lazy var tableProfiles: OrganizerProfileTableView = .get()

    @IBOutlet private weak var buttonReconnect: NSButton!
    
    @IBOutlet private weak var buttonRemoveConfiguration: NSButton!

    @IBOutlet private weak var serviceController: ServiceViewController?

    private let service = TransientStore.shared.service

    private var profiles: [ConnectionProfile] = []
    
    private var importer: HostImporter?
    
    private var profilePendingRemoval: ConnectionProfile?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        service.delegate = self

        viewProfiles.addSubview(tableProfiles)
        tableProfiles.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            tableProfiles.topAnchor.constraint(equalTo: viewProfiles.topAnchor),
            tableProfiles.bottomAnchor.constraint(equalTo: viewProfiles.bottomAnchor),
            tableProfiles.leftAnchor.constraint(equalTo: viewProfiles.leftAnchor),
            tableProfiles.rightAnchor.constraint(equalTo: viewProfiles.rightAnchor),
        ])

        buttonReconnect.title = L10n.Core.Service.Cells.Reconnect.caption
        buttonRemoveConfiguration.title = L10n.Core.Organizer.Cells.Uninstall.caption

        tableProfiles.selectionBlock = { [weak self] in
            self?.serviceController?.setProfile($0)
        }
        tableProfiles.deselectionBlock = { [weak self] in
            self?.serviceController?.setProfile(nil)
        }
        tableProfiles.delegate = self
        reloadProfiles()
        tableProfiles.reloadData()
    }
    
    // MARK: Actions
    
    @objc private func addProvider(_ sender: Any?) {
        guard let item = sender as? NSMenuItem, let metadata = item.representedObject as? Infrastructure.Metadata else {
            return
        }
        perform(segue: StoryboardSegue.Main.enterAccountSegueIdentifier, sender: metadata.name)
    }
    
    @objc private func addHost() {
        let panel = NSOpenPanel()
        
        panel.title = L10n.App.Organizer.Alerts.OpenHostFile.title
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.canCreateDirectories = false
        panel.allowedFileTypes = ["ovpn"]
        
        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        importer = HostImporter(withConfigurationURL: url)
        importer?.importHost(withPassphrase: nil)
    }
    
    @IBAction private func reconnectVPN(_ sender: Any?) {
        GracefulVPN(service: service).reconnect(completionHandler: nil)
    }

    @IBAction private func confirmVpnProfileDeletion(_ sender: Any?) {
        let alert = Macros.warning(
            L10n.Core.Organizer.Cells.Uninstall.caption,
            L10n.Core.Organizer.Alerts.DeleteVpnProfile.message
        )
        alert.present(in: view.window, withOK: L10n.Core.Global.ok, cancel: L10n.Core.Global.cancel, handler: {
            VPN.shared.uninstall(completionHandler: nil)
        }, cancelHandler: nil)
    }
    
    override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
        if let vc = segue.destinationController as? ServiceViewController {
            serviceController = vc
        } else if let vc = segue.destinationController as? AccountViewController {

            // add provider -> account
            if let name = sender as? Infrastructure.Name {
                vc.profile = ProviderConnectionProfile(name: name)
            }
            // add host -> rename -> account
            else {
                vc.profile = sender as? ConnectionProfile
            }
            vc.delegate = self
        } else if let vc = segue.destinationController as? TextInputViewController {
            guard let profile = sender as? ConnectionProfile else {
                return
            }
            
            // rename host
            vc.caption = L10n.Core.Global.Host.TitleInput.message
            vc.text = service.screenTitle(forHostId: profile.id)
            vc.placeholder = L10n.Core.Global.Host.TitleInput.placeholder
            vc.object = profile
            vc.delegate = self
        }
    }
    
    // MARK: Helpers
    
    private func removePendingProfile() {
        guard let profile = profilePendingRemoval else {
            return
        }

        service.removeProfile(ProfileKey(profile))
        profilePendingRemoval = nil

        if profiles.isEmpty || !service.hasActiveProfile() {
            serviceController?.setProfile(nil)
        }
    }
    
    private func reloadProfiles() {
        let providerIds = service.ids(forContext: .provider)
        let hostIds = service.ids(forContext: .host)
        profiles.removeAll()
        for id in providerIds {
            guard let profile = service.profile(withContext: .provider, id: id) else {
                continue
            }
            profiles.append(profile)
        }
        for id in hostIds {
            guard let profile = service.profile(withContext: .host, id: id) else {
                continue
            }
            profiles.append(profile)
        }
        profiles.sort {
            service.screenTitle(ProfileKey($0)) < service.screenTitle(ProfileKey($1))
        }

        tableProfiles.rows = profiles
        for (i, p) in profiles.enumerated() {
            if service.isActiveProfile(p) {
                tableProfiles.selectedRow = i
                break
            }
        }
    }
}

extension OrganizerViewController: OrganizerProfileTableViewDelegate {
    func profileTableViewDidRequestAdd(_ profileTableView: OrganizerProfileTableView, sender: NSView) {
        guard let event = NSApp.currentEvent else {
            return
        }

        let menu = NSMenu()

        let itemProvider = NSMenuItem(title: L10n.App.Organizer.Menus.provider, action: nil, keyEquivalent: "")
        let menuProvider = NSMenu()
        let availableMetadata = service.availableProviders()
        if !availableMetadata.isEmpty {
            for metadata in availableMetadata {
                let item = NSMenuItem(title: metadata.description, action: #selector(addProvider(_:)), keyEquivalent: "")
                item.image = metadata.logo
                item.representedObject = metadata
                menuProvider.addItem(item)
            }
        } else {
            let item = NSMenuItem(title: L10n.App.Organizer.Menus.Provider.unavailable, action: nil, keyEquivalent: "")
            item.isEnabled = false
            menuProvider.addItem(item)
        }
        menu.setSubmenu(menuProvider, for: itemProvider)
        menu.addItem(itemProvider)

        let menuHost = NSMenuItem(title: L10n.App.Organizer.Menus.host.asContinuation, action: #selector(addHost), keyEquivalent: "")
        menu.addItem(menuHost)

        NSMenu.popUpContextMenu(menu, with: event, for: sender)
    }
    
    func profileTableView(_ profileTableView: OrganizerProfileTableView, didRequestRemove profile: ConnectionProfile) {
        profilePendingRemoval = profile

        let alert = Macros.warning(
            L10n.App.Organizer.Alerts.RemoveProfile.title,
            L10n.App.Organizer.Alerts.RemoveProfile.message(service.screenTitle(forHostId: profile.id))
        )
        alert.present(in: view.window, withOK: L10n.Core.Global.ok, cancel: L10n.Core.Global.cancel, handler: {
            self.removePendingProfile()
        }, cancelHandler: nil)
    }
    
    func profileTableView(_ profileTableView: OrganizerProfileTableView, didRequestRename profile: HostConnectionProfile) {
        perform(segue: StoryboardSegue.Main.renameProfileSegueIdentifier, sender: profile)
    }
}

extension OrganizerViewController: AccountViewControllerDelegate {
    func accountController(_ accountController: AccountViewController, shouldUpdateCredentials credentials: Credentials, forProfile profile: ConnectionProfile) -> Bool {
        guard profile.requiresCredentials else {
            return true
        }
        return credentials.isValid
    }
    
    func accountController(_ accountController: AccountViewController, didUpdateCredentials credentials: Credentials, forProfile profile: ConnectionProfile) {
        service.addOrReplaceProfile(profile, credentials: credentials)

        if profiles.count == 1 {
            service.activateProfile(profile)
            serviceController?.setProfile(profile)
        }
    }
    
    func accountControllerDidCancel(_ accountController: AccountViewController) {
    }
}

// rename existing host profile
extension OrganizerViewController: TextInputViewControllerDelegate {
    func textInputController(_ textInputController: TextInputViewController, shouldEnterText text: String) -> Bool {
        return text.rangeOfCharacter(from: CharacterSet.filename.inverted) == nil
    }
    
    func textInputController(_ textInputController: TextInputViewController, didEnterText text: String) {
        guard let profile = textInputController.object as? ConnectionProfile else {
            return
        }
        if text != service.screenTitle(forHostId: profile.id) {
            service.renameProfile(profile, to: text)
        }
        dismiss(textInputController)
    }
}

extension OrganizerViewController: ConnectionServiceDelegate {
    func connectionService(didAdd profile: ConnectionProfile) {
        TransientStore.shared.serialize(withProfiles: false) // add

        reloadProfiles()
        tableProfiles.reloadData()
    }
    
    func connectionService(didRename profile: ConnectionProfile, to newTitle: String) {
        TransientStore.shared.serialize(withProfiles: false) // rename

        reloadProfiles()
        tableProfiles.reloadData()
    }
    
    func connectionService(didRemoveProfileWithKey key: ProfileKey) {
        TransientStore.shared.serialize(withProfiles: false) // delete

        reloadProfiles()
        tableProfiles.selectedRow = nil
        tableProfiles.reloadData()
    }
    
    func connectionService(willDeactivate profile: ConnectionProfile) {
        TransientStore.shared.serialize(withProfiles: false) // deactivate

        StatusMenu.shared.setActiveProfile(nil)
    }
    
    func connectionService(didActivate profile: ConnectionProfile) {
        TransientStore.shared.serialize(withProfiles: false) // activate

        for (i, p) in profiles.enumerated() {
            if p.id == profile.id {
                tableProfiles.selectedRow = i
                break
            }
        }
        tableProfiles.reloadData()

        StatusMenu.shared.setActiveProfile(profile)
    }
}
