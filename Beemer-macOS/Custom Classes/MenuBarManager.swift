//
//  MenuBarManager.swift
//  Beemer-macOS
//
//  Created by Keaton Burleson on 4/27/21.
//

import Foundation
import AppKit

class MenuBarManager: NSObject {

    
    @IBOutlet weak var appDelegate: AppDelegate?
    
    var popover: PinnablePopover?
    var popoverVC: ViewController?

    let menuBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    let menuBarIcon = NSImage(named: "NSTouchBarOpenInBrowserTemplate")


    override init() {
        super.init()

        self.initPopover()
        self.initMenuBarItem()
    }

    fileprivate func initMenuBarItem() {
        self.menuBarItem.button?.image = menuBarIcon
        menuBarIcon?.isTemplate = true
        self.menuBarItem.button?.target = self
        self.menuBarItem.button?.action = #selector(showStationaryVC(sender:))
    }

    fileprivate func initPopover() {
        popover = PinnablePopover(pinned: false)
    }

    
    @objc fileprivate func showStationaryVC(sender: NSStatusBarButton) {
        guard let popover = popover else { return }

        // Checks if the popover is already shown and if the popover should close
        // If so, close the popover and return
        if (popover.isShown && popover.shouldClose) {
            popover.close()
            return
        }

        if (popoverVC == nil) {
            guard let vc = NSStoryboard(name: "Main", bundle: nil).instantiateController(withIdentifier: .init(stringLiteral: "viewController")) as? ViewController else { return }
            popoverVC = vc
            popoverVC?.popover = popover
            popoverVC?.appDelegate = self.appDelegate
        }

        popover.contentViewController = popoverVC
        popover.show(relativeTo: .zero, of: sender, preferredEdge: .minY)
    }

    func pop() {
        self.showStationaryVC(sender: self.menuBarItem.button!)
    }
}
