//
//  ServiceViewController.swift
//  Passepartout-macOS
//
//  Created by Davide De Rosa on 7/29/18.
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
import Convenience

private let log = SwiftyBeaver.self

class ServiceViewController: NSViewController {
    @IBOutlet private weak var labelWelcome: NSTextField!

    @IBOutlet private weak var viewVPN: NSView!
    
    @IBOutlet private weak var viewProfile: NSView!
    
    @IBOutlet private weak var viewFooter: NSView!
    
    @IBOutlet private weak var labelStatusCaption: NSTextField!

    @IBOutlet private weak var labelStatus: NSTextField!
    
    @IBOutlet private weak var labelServiceDescription: NSTextField!
    
    @IBOutlet private weak var buttonToggle: NSButton!
    
    @IBOutlet private weak var activityVPN: NSProgressIndicator!
    
    @IBOutlet private weak var buttonCustomize: NSButton!
    
    @IBOutlet private weak var buttonAccount: NSButton!

    @IBOutlet private weak var viewProfileContainer: NSView!
    
    private lazy var viewProvider: ProviderServiceView = .get()
    
    private lazy var viewHost: HostServiceView = .get()

    private var profile: ConnectionProfile?
    
    private let service = TransientStore.shared.service
    
    private lazy var vpn = GracefulVPN(service: service)
    
    private var isPendingConnection = false
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    func setProfile(_ profile: ConnectionProfile?) {
        defer {
            let hasProfile = (self.profile != nil)
            labelWelcome.isHidden = hasProfile
            viewProfile.isHidden = !hasProfile
            viewProfileContainer.isHidden = !hasProfile
            viewFooter.isHidden = !hasProfile
            reloadVpnStatus()
        }

        if let profile = profile, let currentProfile = self.profile {
            guard (profile.context != currentProfile.context) || (profile.id != currentProfile.id) else {
                return
            }
        }

        self.profile = profile
        guard let _ = profile else {
            return
        }

        let view: NSView
        if let providerProfile = profile as? ProviderConnectionProfile {
            viewProvider.profile = providerProfile
            viewProvider.delegate = self
            view = viewProvider
        } else if let hostProfile = profile as? HostConnectionProfile {
            viewHost.profile = hostProfile
            viewHost.delegate = self
            view = viewHost
        } else {
            fatalError("Unexpected profile type")
        }
        
        view.translatesAutoresizingMaskIntoConstraints = false
        viewProfileContainer.subviews.forEach {
            $0.removeFromSuperview()
        }
        viewProfileContainer.addSubview(view)
        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: viewProfileContainer.topAnchor),
//            view.bottomAnchor.constraint(equalTo: viewProfileContainer.bottomAnchor),
//            view.centerYAnchor.constraint(equalTo: viewProfileContainer.centerYAnchor),
            view.rightAnchor.constraint(equalTo: viewProfileContainer.rightAnchor),
            view.leftAnchor.constraint(equalTo: viewProfileContainer.leftAnchor),
        ])
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if profile == nil {
            setProfile(service.activeProfile)
        }

        // enforce on macOS
        service.preferences.disconnectsOnSleep = true
        
        labelWelcome.stringValue = L10n.Core.Service.Welcome.message
        labelStatusCaption.stringValue = L10n.Core.Service.Cells.ConnectionStatus.caption.asCaption
        labelServiceDescription.stringValue = L10n.Core.Service.Sections.Vpn.footer
        buttonToggle.title = L10n.App.Service.Cells.Vpn.TurnOn.caption
        buttonCustomize.image = NSImage(named: NSImage.actionTemplateName)
        buttonAccount.title = L10n.Core.Account.title.asContinuation

        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(vpnDidUpdate), name: .VPNDidChangeStatus, object: nil)
        nc.addObserver(self, selector: #selector(vpnDidReinstall), name: .VPNDidReinstall, object: nil)

        vpn.profile = profile
        vpn.prepare {
            self.reloadVpnStatus()
        }
    }
    
    @IBAction private func toggleVpnService(_ sender: Any?) {
        guard let profile = profile else {
            return
        }

        let status: VPNStatus
        if service.isActiveProfile(profile) {
            status = vpn.status ?? .disconnected
        } else {

            // force reconnection when activating a different profile
            status = .disconnected
        }
        vpn.profile = profile
        service.activateProfile(profile)
        reloadVpnStatus()

        switch status {
        case .disconnected:
            guard !service.needsCredentials(for: uncheckedProfile) else {
                isPendingConnection = true
                perform(segue: StoryboardSegue.Service.accountSegueIdentifier)
                return
            }
            vpn.reconnect(completionHandler: nil)
            
        default:
            buttonToggle.isEnabled = false
            vpn.disconnect(completionHandler: nil)
        }
    }

//    @IBAction private func cycleConnection(_ sender: Any?) {
//        guard vpn.isEnabled else {
//            return
//        }
////        guard vpn.status == .disconnected else {
////            let alert = Macros.alert(
////                L10n.Core.Service.Cells.ConnectionStatus.caption,
////                L10n.Core.Service.Alerts.ReconnectVpn.message
////            )
////            alert.addDefaultAction(L10n.Core.Global.ok) {
////                self.vpn.reconnect(configuration: self.currentVpnConfiguration(), completionHandler: nil)
////            }
////            alert.addCancelAction(L10n.Core.Global.cancel)
////            present(alert, animated: true, completion: nil)
////            return
////        }
//        vpn.reconnect(completionHandler: nil)
//    }

    @IBAction private func customizeProfile(_ sender: Any?) {
        perform(segue: StoryboardSegue.Service.customizeSegueIdentifier)
    }

    override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
        if let accountVC = segue.destinationController as? AccountViewController {
            accountVC.profile = profile
            accountVC.delegate = self
        } else if let customVC = segue.destinationController as? ProfileCustomizationContainerViewController {
            customVC.profile = profile
        }
    }
    
    // MARK: Notifications
    
    @objc private func vpnDidUpdate() {
        reloadVpnStatus()

        guard let status = vpn.status else {
            return
        }
        log.debug("VPN.status: \(status)")
        switch status {
        case .connected:
            Reviewer.shared.reportEvent()
            
        default:
            break
        }
    }
    
    @objc private func vpnDidReinstall() {
        viewProvider.reloadData()
        viewHost.reloadData()
    }
    
    // MARK: Helpers
    
    private func reloadVpnStatus() {
        guard let profile = profile else {
            return
        }
        let isActive = service.isActiveProfile(profile)
        guard isActive && vpn.isEnabled else {
            labelStatus.applyVPN(Theme.current, isActive: isActive, with: nil, error: nil)
            buttonToggle.title = L10n.App.Service.Cells.Vpn.TurnOn.caption
            buttonToggle.isEnabled = true
            activityVPN.stopAnimation(nil)
            return
        }

        labelStatus.applyVPN(Theme.current, isActive: isActive, with: vpn.status, error: service.vpnLastError)

        switch vpn.status ?? .disconnected {
        case .connected:
            buttonToggle.title = L10n.App.Service.Cells.Vpn.TurnOff.caption
            buttonToggle.isEnabled = true
            activityVPN.stopAnimation(nil)

        case .disconnected:
            buttonToggle.title = L10n.App.Service.Cells.Vpn.TurnOn.caption
            buttonToggle.isEnabled = true
            activityVPN.stopAnimation(nil)

        case .connecting:
            buttonToggle.title = L10n.App.Service.Cells.Vpn.TurnOff.caption
            buttonToggle.isEnabled = true
            activityVPN.startAnimation(nil)

        case .disconnecting:
            buttonToggle.isEnabled = false
            activityVPN.startAnimation(nil)
        }
    }
}

extension ServiceViewController: AccountViewControllerDelegate {
    func accountController(_ accountController: AccountViewController, shouldUpdateCredentials credentials: Credentials, forProfile profile: ConnectionProfile) -> Bool {
        guard profile.requiresCredentials else {
            return true
        }
        return credentials.isValid
    }

    func accountController(_ accountController: AccountViewController, didUpdateCredentials credentials: Credentials, forProfile profile: ConnectionProfile) {
        if isPendingConnection {
            isPendingConnection = false
            vpn.reconnect(completionHandler: nil)
        }
        StatusMenu.shared.setActiveProfile(profile)
    }
    
    func accountControllerDidCancel(_ accountController: AccountViewController) {
        isPendingConnection = false
    }
}

extension ServiceViewController: ProviderServiceViewDelegate {
    func providerView(_ providerView: ProviderServiceView, didSelectPool pool: Pool) {

        // fall back to a supported preset
        let supportedPresets = pool.supportedPresetIds(in: uncheckedProviderProfile.infrastructure)
        if let presetId = uncheckedProviderProfile.preset?.id, !supportedPresets.contains(presetId),
            let fallback = supportedPresets.first {
            
            uncheckedProviderProfile.presetId = fallback
        }

        uncheckedProviderProfile.poolId = pool.id
        vpn.reinstallIfEnabled()
    }
    
    func providerViewDidRequestInfrastructureRefresh(_ providerView: ProviderServiceView) {
        let name = uncheckedProviderProfile.name
        
        viewProvider.isRefreshingInfrastructure = true
        let isUpdating = InfrastructureFactory.shared.update(name, notBeforeInterval: AppConstants.Services.minimumUpdateInterval) { (response, error) in
            self.viewProvider.isRefreshingInfrastructure = false
            guard let _ = response else {
                return
            }
            self.viewProvider.reloadData()
        }
        if !isUpdating {
            viewProvider.isRefreshingInfrastructure = false
        }
    }
}

extension ServiceViewController: HostServiceViewDelegate {
}

private extension ServiceViewController {
    private var uncheckedProfile: ConnectionProfile {
        guard let profile = profile else {
            fatalError("Expected non-nil profile here")
        }
        return profile
    }

    private var uncheckedProviderProfile: ProviderConnectionProfile {
        guard let profile = profile as? ProviderConnectionProfile else {
            fatalError("Expected ProviderConnectionProfile (found: \(type(of: self.profile)))")
        }
        return profile
    }
    
    private var uncheckedHostProfile: HostConnectionProfile {
        guard let profile = profile as? HostConnectionProfile else {
            fatalError("Expected HostConnectionProfile (found: \(type(of: self.profile)))")
        }
        return profile
    }
}
