//
//  SelectDestinationViewController.swift
//  BeemTo
//
//  Created by Keaton Burleson on 4/26/21.
//

import Foundation
import UIKit
import Network

protocol SelectDestinationViewControllerDelegate: AnyObject {
    func selected(destination: NWBrowser.Result)
}

class SelectDestinationViewController: UITableViewController, URLSessionDelegate {


    var destinations: [NWBrowser.Result]!
    let reuseIdentifier = "destinationCell"

    weak var delegate: SelectDestinationViewControllerDelegate?


    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Select Destination"

        tableView.register(UITableViewCell.self, forCellReuseIdentifier: reuseIdentifier)

    }

    // MARK: - Table view data source
    override func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        return destinations.count
    }


    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier, for: indexPath)
        cell.textLabel?.text = self.formatName(endpoint: destinations[indexPath.row].endpoint) ?? "Beemer"

        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let delegate = delegate {
            delegate.selected(destination: destinations[indexPath.row])
        }
    }
    
    private func formatName(endpoint: NWEndpoint?) -> String? {
        if let endpoint = endpoint {
            return "\(endpoint)".replacingOccurrences(of: "._beemer._tcplocal.", with: "")
        }
        
        return nil
    }
    
}

