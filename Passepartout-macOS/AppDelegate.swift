//
//  AppDelegate.swift
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
import SwiftyBeaver
import PassepartoutCore
import Convenience

// comment on release
import AppCenter
import AppCenterAnalytics
import AppCenterCrashes

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    private let appCenterSecret = GroupConstants.App.config?["appcenter_secret"] as? String
    
    private var importer: HostImporter?
    
    override init() {
        AppConstants.Log.configure()
//        AppConstants.Flags.isMockVPN = true
        InfrastructureFactory.shared.preload()
        super.init()
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        Reviewer.shared.eventCountBeforeRating = AppConstants.Rating.eventCount
        ProductManager.shared.listProducts(completionHandler: nil)

        NSApp.mainMenu = loadMainMenu()
        StatusMenu.shared.install()
        
        if let appCenterSecret = appCenterSecret, !appCenterSecret.isEmpty {
            MSAppCenter.start(appCenterSecret, withServices: [MSAnalytics.self, MSCrashes.self])
        }
    }
    
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        let alert = Macros.warning(
            L10n.App.Menu.Quit.title(GroupConstants.App.name),
            L10n.App.Menu.Quit.Messages.confirm
        )
        guard alert.presentModally(withOK: L10n.Core.Global.ok, cancel: L10n.Core.Global.cancel) else {
            return .terminateCancel
        }
        return .terminateNow
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        TransientStore.shared.serialize(withProfiles: true) // exit
    }
    
    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        let url = URL(fileURLWithPath: filename)
        importer = HostImporter(withConfigurationURL: url)
        importer?.importHost(withPassphrase: nil)
        return true
    }
    
    // MARK: Helpers
    
    private func loadMainMenu() -> NSMenu? {
        let nibName = "MainMenu"
        guard let nib = NSNib(nibNamed: nibName, bundle: nil) else {
            fatalError(nibName)
        }
        var objects: NSArray?
        guard nib.instantiate(withOwner: nil, topLevelObjects: &objects) else {
            fatalError(nibName)
        }
        guard let nonOptionalObjects = objects else {
            fatalError(nibName)
        }
        for o in nonOptionalObjects {
            if let menu = o as? NSMenu {
                return menu
            }
        }
        return nil
    }
}
