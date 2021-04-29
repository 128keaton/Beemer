//
//  ItemCell.swift
//  Beemer-iOS
//
//  Created by Keaton Burleson on 4/28/21.
//

import Foundation
import UIKit

class ItemCell: UITableViewCell {
    @IBOutlet weak var messageLabel: UILabel!
    @IBOutlet weak var urlLabel: UILabel!
    @IBOutlet weak var atLabel: UILabel!

    private var _item: BeemItem?

    var item: BeemItem {
        get {
            self._item!
        }
        set(newItem) {
            self._item = newItem

            if let message = newItem.message, message.count > 0 {
                self.messageLabel.text = message
            } else {
                self.messageLabel.textColor = .tertiaryLabel
                self.messageLabel.text = "No Message"
            }

            if let on = newItem.on {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "MM/dd/yy h:mm a"

                self.atLabel.text = dateFormatter.string(from: on)
            }
            
            if let url = newItem.url {
                self.urlLabel.text = url
            } else {
                self.urlLabel.text = "No URL"
            }
        }
    }
}
