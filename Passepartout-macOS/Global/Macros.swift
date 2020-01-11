//
//  Macros.swift
//  Passepartout-macOS
//
//  Created by Davide De Rosa on 7/30/18.
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

class Macros {
    static func warning(_ title: String, _ message: String) -> NSAlert {
        return genericAlert(.warning, title, message)
    }

    private static func genericAlert(_ style: NSAlert.Style, _ title: String, _ message: String) -> NSAlert {
        let alert = NSAlert()
        alert.alertStyle = style
        alert.messageText = title
        alert.informativeText = message
        return alert
    }
}

extension NSAlert {
    func present(in window: NSWindow?, withOK okTitle: String, handler: (() -> Void)?) {
        present(in: window, withOK: okTitle, cancel: nil, handler: handler, cancelHandler: nil)
    }

    func present(in window: NSWindow?, withOK okTitle: String, cancel cancelTitle: String?, handler: (() -> Void)?, cancelHandler: (() -> Void)?) {
        guard let window = window else {
            if presentModally(withOK: okTitle, cancel: cancelTitle) {
                handler?()
            } else {
                cancelHandler?()
            }
            return
        }

        addButton(withTitle: okTitle)
        if let cancelTitle = cancelTitle {
            addButton(withTitle: cancelTitle)
        }
        
        beginSheetModal(for: window) {
            switch $0 {
            case .alertFirstButtonReturn:
                handler?()
                
            default:
                cancelHandler?()
            }
        }
    }

    func presentModally(withOK okTitle: String, cancel cancelTitle: String?) -> Bool {
        addButton(withTitle: okTitle)
        if let cancelTitle = cancelTitle {
            addButton(withTitle: cancelTitle)
        }
        return runModal() == .alertFirstButtonReturn
    }
}

extension NSView {
    static func get<T: NSView>() -> T {
        let name = String(describing: T.self)
        guard let nib = NSNib(nibNamed: name, bundle: nil) else {
            fatalError()
        }
        var objects: NSArray?
        guard nib.instantiate(withOwner: nil, topLevelObjects: &objects) else {
            fatalError()
        }
        guard let nonOptionalObjects = objects else {
            fatalError()
        }
        for o in nonOptionalObjects {
            if let view = o as? T {
                return view
            }
        }
        fatalError()
    }
}

extension NSView {
    func endEditing() {
        window?.makeFirstResponder(nil)
    }
}

extension NSImage {
    func tinted(withColor color: NSColor) -> NSImage {
        let image = copy() as! NSImage
        image.lockFocus()
        
        color.set()
        
        let imageRect = NSRect(origin: NSZeroPoint, size: image.size)
        imageRect.fill(using: .sourceAtop)
        image.unlockFocus()
        
        return image
    }
}

extension String {
    var asCaption: String {
        return "\(self):"
    }

    var asContinuation: String {
        return "\(self)..."
    }
}
