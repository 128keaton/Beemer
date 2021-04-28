//
//  PinnablePopover.swift
//  Beemer-macOS
//
//  Created by Keaton Burleson on 4/27/21.
//

import Foundation
import Cocoa

class PinnablePopover: NSPopover {
    
    fileprivate var _shouldClose: Bool = true
    
    var shouldClose: Bool {
        get {
            return self._shouldClose
        }
        set (newValue) {
            self._shouldClose = newValue
            
            if (newValue) {
                NSApplication.shared.activate(ignoringOtherApps: true)
                self.behavior = NSPopover.Behavior.transient
            } else {
                self.behavior = NSPopover.Behavior.applicationDefined
            }
            
            self.printBehavior()
        }
    }
    
     init(pinned: Bool = false) {
        super.init()
        
        self.shouldClose = !pinned
        self.printBehavior()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override func show(relativeTo positioningRect: NSRect, of positioningView: NSView, preferredEdge: NSRectEdge) {
        super.show(relativeTo: positioningRect, of: positioningView, preferredEdge: preferredEdge)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
    
    override func performClose(_ sender: Any?) {
        print("Performing close...")
        super.performClose(sender)
    }
    
    override func close() {
        print("Performing close...")
        super.close()
    }
    
    fileprivate func printBehavior() {
        switch behavior {
        case .applicationDefined:
            print("Application-defined (pinned)")
        case .semitransient:
            print("Semi-transient (pinned)")
        case .transient:
            print("Transient (unpinned)")
        default:
            print("Unknown")
        }
    }
    
}
