//
//  ViewController.swift
//  Beemer-iOS
//
//  Created by Keaton Burleson on 4/15/21.
//

import UIKit
import Network
import CoreData

class ViewController: UITableViewController {


    var items: [BeemItem] = []
    var devices: [NWBrowser.Result] = []

    var browser: Browser?
    var selectedItem: BeemItem?
    var currentAlert: UIAlertController?


    override func viewDidLoad() {
        super.viewDidLoad()

        self.browser = Browser.init()
        self.browser?.delegate = self
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.items.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let item = self.items[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        cell.textLabel?.text = item.message
        cell.detailTextLabel?.text = item.url

        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let item = self.items[indexPath.row]

        self.showActionAlert(item: item)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        guard let appDelegate =
            UIApplication.shared.delegate as? AppDelegate else {
            return
        }

        let managedContext = appDelegate.persistentContainer.viewContext
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "BeemItem")

        do {
            self.items = try managedContext.fetch(fetchRequest) as! [BeemItem]
        } catch let error as NSError {
            print("Could not fetch. \(error), \(error.userInfo)")
        }
    }

    func showActionAlert(item: BeemItem) {
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        let row = self.items.firstIndex(of: item)!

        self.selectedItem = item
        self.currentAlert = alert

        self.devices.forEach({ (device) in
            alert.addAction(UIAlertAction(title: "Send to \(self.formatName(endpoint: device.endpoint))", style: .default) { _ in
                    self.tableView.deselectRow(at: IndexPath(row: row, section: 0), animated: true)
                    self.browser?.establishConnection(with: device.endpoint)
                })
        })

        alert.addAction(UIAlertAction(title: "Open in Safari", style: .default) { _ in
                guard let url = URL(string: item.url!) else {
                    return
                }

                let row = self.items.firstIndex(of: self.selectedItem!)!

                self.tableView.deselectRow(at: IndexPath(row: row, section: 0), animated: true)
                self.resetAlert()

                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            })

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
                self.tableView.deselectRow(at: IndexPath(row: row, section: 0), animated: true)

                self.resetAlert()
                alert.dismiss(animated: true, completion: nil)
            })

        present(alert, animated: true)
    }

    private func resetAlert() {
        self.currentAlert = nil
        self.selectedItem = nil
    }

    private func formatName(endpoint: NWEndpoint) -> String {
        return "\(endpoint)".replacingOccurrences(of: "._beemer._udplocal.", with: "")
    }
}

extension ViewController: BrowserDelegate {
    func devicesChanged(devices: [NWBrowser.Result]) {
        self.devices = devices

        print(self.devices)

        if self.currentAlert != nil {
            self.currentAlert?.dismiss(animated: true, completion: {
                self.showActionAlert(item: self.selectedItem!)
            })
        }
    }

    func connectionReady() {
        print("connectionReady: \(self.selectedItem!)")
        self.browser?.send(item: self.selectedItem!)
    }

    func dataSent(error: Error?) {
        if let error = error {
            print("Error sending data: \(error)")
        } else {
            print("Data sent successfully")
            self.browser?.stop()
        }

        self.resetAlert()
    }
}
