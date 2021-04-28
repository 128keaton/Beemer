//
//  ViewController.swift
//  Beemer-macOS
//
//  Created by Keaton Burleson on 4/15/21.
//

import Cocoa
import UserNotifications

class ViewController: NSViewController, UNUserNotificationCenterDelegate, NSTableViewDelegate, NSTableViewDataSource, NSFetchedResultsControllerDelegate {

    @IBOutlet var tableView: NSTableView?
    @IBOutlet var countLabel: NSTextField?

    public var popover: PinnablePopover?
    public var appDelegate: AppDelegate?

    var offset: Int = 0
    var limit: Int = 20

    lazy var fetchedResultsController: NSFetchedResultsController<BeemItem> = {
        let fetchRequest = NSFetchRequest<BeemItem>(entityName: "BeemItem")

        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "on", ascending: false)]
        fetchRequest.fetchOffset = self.offset
        fetchRequest.fetchLimit = self.limit

        let fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest,
            managedObjectContext: self.appDelegate!.persistentContainer.viewContext,
            sectionNameKeyPath: nil,
            cacheName: "BeemItemCache")
        fetchedResultsController.delegate = self
        return fetchedResultsController
    }()

    override func viewDidLoad() {
        super.viewDidLoad()


        self.tableView?.delegate = self
        self.tableView?.dataSource = self
        self.tableView?.doubleAction = #selector(doubleClicked)

        guard let appDelegate = self.appDelegate else {
            return
        }

        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(self, selector: #selector(managedObjectContextObjectsDidChange), name: NSNotification.Name.NSManagedObjectContextObjectsDidChange, object: appDelegate.persistentContainer.viewContext)


        do {
            NSFetchedResultsController<BeemItem>.deleteCache(withName: fetchedResultsController.cacheName)
            try fetchedResultsController.performFetch()
            self.updateView()
        } catch {
            print("Could not fetch. \(error), \(error.localizedDescription)")
        }
    }

    @objc func managedObjectContextObjectsDidChange(notification: NSNotification) {
        /*  guard let userInfo = notification.userInfo else { return }

        let refreshed = userInfo[NSRefreshedObjectsKey] as? Set<NSManagedObject>
        let updated = userInfo[NSUpdatedObjectsKey] as? Set<NSManagedObject>
        let deleted = userInfo[NSDeletedObjectsKey] as? Set<NSManagedObject>
        let inserted = userInfo[NSInsertedObjectsKey] as? Set<NSManagedObject>*/
        self.updateView()
    }

    @objc func doubleClicked() {
        let row = (self.tableView?.clickedRow)!
        let item = fetchedResultsController.fetchedObjects![row]
        
        if let urlString = item.url, let url = URL(string: urlString) {
            print("Opening: \(url)")
            DispatchQueue.main.async {
                NSWorkspace.shared.open(url)
            }
        }
    }

    func updateView() {
        DispatchQueue.main.async {
            self.countLabel?.stringValue = "\(self.historyCount()) \(self.historyCount() == 1 ? "item" : "items")"
        }
    }

    func historyCount() -> Int {
        return fetchedResultsController.fetchedObjects?.count ?? 0
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        return self.historyCount()
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cell: NSTableCellView!
        let column = tableView.tableColumns.firstIndex(of: tableColumn!)!
        switch column {
        case 0:
            cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "messageCell"), owner: self) as? NSTableCellView
        case 1:
            cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "urlCell"), owner: self) as? NSTableCellView
        default:
            return nil
        }

        configureCell(cell: cell, row: row, column: column)
        return cell
    }

    private func configureCell(cell: NSTableCellView, row: Int, column: Int) {
        let item = fetchedResultsController.fetchedObjects![row]
        switch column {
        case 0:
            cell.textField?.stringValue = item.message ?? ""
        case 1:
            cell.textField?.stringValue = item.url ?? ""
        default:
            break
        }
    }

    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView?.beginUpdates()
    }

    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView?.endUpdates()
    }

    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {

        switch type {
        case .insert:
            if let newIndexPath = newIndexPath {
                tableView!.insertRows(at: [newIndexPath.item], withAnimation: .effectFade)
            }
        case .delete:
            if let indexPath = indexPath {
                tableView!.removeRows(at: [indexPath.item], withAnimation: .effectFade)
            }
        case .update:
            if let indexPath = indexPath {
                let row = indexPath.item
                for column in 0..<tableView!.numberOfColumns {
                    if let cell = tableView!.view(atColumn: column, row: row, makeIfNecessary: true) as? NSTableCellView {
                        configureCell(cell: cell, row: row, column: column)
                    }
                }
            }
        case .move:
            if let indexPath = indexPath, let newIndexPath = newIndexPath {
                tableView!.removeRows(at: [indexPath.item], withAnimation: .effectFade)
                tableView!.insertRows(at: [newIndexPath.item], withAnimation: .effectFade)
            }
        @unknown default:
            fatalError()
        }

        self.updateView()
    }

}
