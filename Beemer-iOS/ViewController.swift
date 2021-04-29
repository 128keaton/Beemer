//
//  ViewController.swift
//  Beemer-iOS
//
//  Created by Keaton Burleson on 4/15/21.
//

import UIKit
import Network
import CoreData

class ViewController: UITableViewController, NSFetchedResultsControllerDelegate {
    var devices: [NWBrowser.Result] = []

    var browser: Browser?
    var selectedItem: BeemItem?
    var currentAlert: UIAlertController?
    var dataSource: UITableViewDiffableDataSource<Int, NSManagedObjectID>?

    var offset: Int = 0
    var limit: Int = 20
    var isLoadingItems = false

    lazy var fetchedResultsController: NSFetchedResultsController<BeemItem> = {
        let fetchRequest = NSFetchRequest<BeemItem>(entityName: "BeemItem")
        guard let appDelegate =
            UIApplication.shared.delegate as? AppDelegate else {
            fatalError("App delegate should be available")
        }

        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "on", ascending: false)]
        fetchRequest.fetchOffset = self.offset
        fetchRequest.fetchLimit = self.limit

        let fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest,
            managedObjectContext: appDelegate.persistentContainer.viewContext,
            sectionNameKeyPath: nil,
            cacheName: "BeemItemCache")
        fetchedResultsController.delegate = self
        return fetchedResultsController
    }()

    lazy var fetchedCountController: NSFetchedResultsController<BeemItem> = {
        let fetchRequest = NSFetchRequest<BeemItem>(entityName: "BeemItem")
        guard let appDelegate =
            UIApplication.shared.delegate as? AppDelegate else {
            fatalError("App delegate should be available")
        }

        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "on", ascending: false)]
        let fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest,
            managedObjectContext: appDelegate.persistentContainer.viewContext,
            sectionNameKeyPath: nil,
            cacheName: nil)
        return fetchedResultsController
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        self.dataSource = UITableViewDiffableDataSource<Int, NSManagedObjectID>(tableView: self.tableView!) { tableView, indexPath, objectID in
            guard let appDelegate =
                UIApplication.shared.delegate as? AppDelegate else {
                fatalError("App delegate should be available")
            }

            let beemItem = appDelegate.persistentContainer.viewContext.object(with: objectID) as! BeemItem

            let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath) as! ItemCell
            cell.item = beemItem

            return cell
        }

        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(self, selector: #selector(appMovedToForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
        
        self.tableView.dataSource = self.dataSource
        self.browser = Browser.init()
        self.browser?.delegate = self
    }
    
    @objc func appMovedToForeground() {
        self.performFetch()
    }

    func currentCount() -> Int {
        return fetchedResultsController.fetchedObjects?.count ?? 0
    }

    func totalCount() -> Int {
        return fetchedCountController.fetchedObjects?.count ?? 0
    }
    
    func deleteAllData(_ entity: String) {
        guard let appDelegate =
            UIApplication.shared.delegate as? AppDelegate else {
            fatalError("App delegate should be available")
        }

        
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entity)
        fetchRequest.returnsObjectsAsFaults = false
        do {
            let results = try appDelegate.persistentContainer.viewContext.fetch(fetchRequest)
            for object in results {
                guard let objectData = object as? NSManagedObject else { continue }
                appDelegate.persistentContainer.viewContext.delete(objectData)
            }
            
            try appDelegate.persistentContainer.viewContext.save()
        } catch let error {
            print("Detele all data in \(entity) error :", error)
        }
    }

    func performFetch(_ initial: Bool = true) {
        do {
            NSFetchedResultsController<BeemItem>.deleteCache(withName: fetchedResultsController.cacheName)


            if initial {
                
                try fetchedResultsController.performFetch()
                try fetchedCountController.performFetch()
                
                self.title = "History - \(self.totalCount())"
            } else {
                let lastLimit = self.limit + 3
                self.limit = lastLimit

                fetchedResultsController.fetchRequest.fetchOffset = self.offset
                fetchedResultsController.fetchRequest.fetchLimit = lastLimit

                try fetchedResultsController.performFetch()
                
                self.isLoadingItems = false
            }
        } catch {
            print("Could not fetch. \(error), \(error.localizedDescription)")
        }
    }


    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.currentCount()
    }


    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let items = fetchedResultsController.fetchedObjects {
            let item = items[indexPath.row]

            self.showActionAlert(item: item)
        }
    }
    
    override func scrollViewDidScroll(_ scrollView: UIScrollView) {
      let isReachingEnd = scrollView.contentOffset.y >= 0
          && scrollView.contentOffset.y >= (scrollView.contentSize.height - scrollView.frame.size.height)
        
        if (isReachingEnd && !self.isLoadingItems && self.currentCount() < self.totalCount()) {
            self.isLoadingItems = true
            self.performFetch(false)
        }
    }

    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChangeContentWith snapshot: NSDiffableDataSourceSnapshotReference) {
        guard let dataSource = self.tableView?.dataSource as? UITableViewDiffableDataSource<Int, NSManagedObjectID> else {
            assertionFailure("The data source has not implemented snapshot support while it should")
            return
        }

        DispatchQueue.main.async {
            dataSource.apply(snapshot as NSDiffableDataSourceSnapshot<Int, NSManagedObjectID>, animatingDifferences: true)
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.performFetch()
    }
    
    @IBAction func clearItems() {
        self.deleteAllData("BeemItem")
        self.title = "History - 0"
    }

    func showActionAlert(item: BeemItem) {
        if let items = fetchedResultsController.fetchedObjects {
            let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
            let row = items.firstIndex(of: item)!

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

                    let row = items.firstIndex(of: self.selectedItem!)!

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
        guard let appDelegate =
            UIApplication.shared.delegate as? AppDelegate else {
            return
        }


        let managedContext = appDelegate.persistentContainer.viewContext
        let item = BeemItem(message: self.selectedItem?.message ?? "", url: self.selectedItem?.url ?? "", source: UIDevice.current.name, on: Date(), context: managedContext)
        self.browser?.send(item: item)
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
