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
    @IBOutlet var headerView: NSView?
    @IBOutlet var titleLabel: NSTextField?

    public var popover: PinnablePopover?
    public var appDelegate: AppDelegate?

    var offset: Int = 0
    var limit: Int = 20
    var scrollView: NSScrollView?
    var isLoadingMore = false

    private var optionsMenu: NSMenu!

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

    lazy var fetchedCountController: NSFetchedResultsController<BeemItem> = {
        let fetchRequest = NSFetchRequest<BeemItem>(entityName: "BeemItem")

        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "on", ascending: false)]
        let fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest,
            managedObjectContext: self.appDelegate!.persistentContainer.viewContext,
            sectionNameKeyPath: nil,
            cacheName: nil)
        return fetchedResultsController
    }()

    var dataSource: NSTableViewDiffableDataSource<Int, NSManagedObjectID>?

    override func viewDidLoad() {
        super.viewDidLoad()

        if let hostname = Host.current().localizedName {
            self.titleLabel?.stringValue = "Beemer - \(hostname)"
        } else {
            self.titleLabel?.stringValue = "Beemer"
        }

        self.dataSource = NSTableViewDiffableDataSource<Int, NSManagedObjectID>(tableView: self.tableView!) { tableView, column, indexPath, objectID in
            guard let beemItem = self.appDelegate?.persistentContainer.viewContext.object(with: objectID) else {
                fatalError("Managed object should be available")
            }

            return self.createCell(item: beemItem as! BeemItem, tableColumn: column)
        }

        self.tableView?.delegate = self
        self.tableView?.dataSource = self.dataSource
        self.tableView?.doubleAction = #selector(doubleClicked)
        self.scrollView = self.tableView?.enclosingScrollView

        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(self, selector: #selector(scrollViewDidScroll), name: NSView.boundsDidChangeNotification, object: self.scrollView?.contentView)

        self.view.wantsLayer = true
        self.view.superview?.wantsLayer = true

        self.headerView?.wantsLayer = true
        self.headerView?.shadow = NSShadow()
        self.headerView?.layer?.shadowColor = NSColor.black.cgColor
        self.headerView?.layer?.shadowOpacity = 1.0
        self.headerView?.layer?.shadowOffset = NSMakeSize(0, 1)
        self.headerView?.layer?.shadowRadius = 20

        self.performFetch()
    }

    func performFetch(_ initial: Bool = true) {
        do {
            NSFetchedResultsController<BeemItem>.deleteCache(withName: fetchedResultsController.cacheName)


            if initial {
                try fetchedResultsController.performFetch()
                try fetchedCountController.performFetch()
                self.updateView()
            } else {
                let lastLimit = self.limit + 3
                self.limit = lastLimit

                fetchedResultsController.fetchRequest.fetchOffset = self.offset
                fetchedResultsController.fetchRequest.fetchLimit = lastLimit

                try fetchedResultsController.performFetch()

                self.isLoadingMore = false
            }
        } catch {
            print("Could not fetch. \(error), \(error.localizedDescription)")
        }
    }


    @objc func scrollViewDidScroll(_ notification: NSNotification) {
        if let scrollView = self.scrollView,
            let documentView = scrollView.documentView {

            let clipView = scrollView.contentView

            if (clipView.bounds.origin.y + clipView.bounds.height == documentView.bounds.height) &&
                !self.isLoadingMore && currentCount() < totalCount() {

                self.isLoadingMore = true
                self.limit += 20
                self.performFetch(false)
            }
        }
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

    @objc func quitApp() {
        NSApp.terminate(self)
    }

    @objc func showAbout() {
        NSApp.orderFrontStandardAboutPanel(self)
    }

    @objc func clear() {
        self.deleteAllData("BeemItem")
        do {
            try fetchedCountController.performFetch()
            self.updateView()
        } catch {
            print("Could not fetch. \(error), \(error.localizedDescription)")
        }
    }

    func updateView() {
        DispatchQueue.main.async {
            self.countLabel?.stringValue = "\(self.totalCount()) \(self.totalCount() == 1 ? "item" : "items")"
        }
    }

    @IBAction func openMenu(_ sender: NSButton) {
        self.optionsMenu = NSMenu()

        let quitItem = NSMenuItem(title: "Quit", action: #selector(self.quitApp), keyEquivalent: "")
        quitItem.target = self

        let aboutItem = NSMenuItem(title: "About", action: #selector(self.showAbout), keyEquivalent: "")
        aboutItem.target = self

        let clearItem = NSMenuItem(title: "Clear", action: #selector(self.clear), keyEquivalent: "")
        clearItem.target = self

        self.optionsMenu.addItem(quitItem)
        self.optionsMenu.addItem(aboutItem)
        self.optionsMenu.addItem(clearItem)

        let location = NSPoint(x: 0, y: sender.frame.height + 5) // Magic number to adjust the height.
        self.optionsMenu.popUp(positioning: nil, at: location, in: sender)
    }

    func currentCount() -> Int {
        return fetchedResultsController.fetchedObjects?.count ?? 0
    }

    func totalCount() -> Int {
        return fetchedCountController.fetchedObjects?.count ?? 0
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        return self.currentCount()
    }

    func deleteAllData(_ entity: String) {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entity)
        fetchRequest.returnsObjectsAsFaults = false
        do {
            let results = try self.appDelegate!.persistentContainer.viewContext.fetch(fetchRequest)
            for object in results {
                guard let objectData = object as? NSManagedObject else { continue }
                self.appDelegate!.persistentContainer.viewContext.delete(objectData)
            }
            
            try self.appDelegate!.persistentContainer.viewContext.save()
        } catch let error {
            print("Detele all data in \(entity) error :", error)
        }
    }

    private func createCell(item: BeemItem, tableColumn: NSTableColumn) -> NSTableCellView {
        var cell: NSTableCellView? = nil

        if let tableView = self.tableView {
            let column = tableView.column(withIdentifier: tableColumn.identifier)

            switch column {
            case 0:
                cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "messageCell"), owner: self) as? NSTableCellView
                if let message = item.message, message.count > 0 {
                    cell!.textField?.stringValue = message
                } else if let source = item.source {
                    cell!.textField?.stringValue = source
                } else {
                    cell!.textField?.stringValue = "Unknown"
                }
            case 1:
                cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "urlCell"), owner: self) as? NSTableCellView
                cell!.textField?.stringValue = item.url ?? ""
            case 2:
                cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "dateCell"), owner: self) as? NSTableCellView

                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "MM/dd/yy h:mm a"

                cell!.textField?.stringValue = dateFormatter.string(from: item.on ?? Date())
            default:
                break
            }
        }

        return cell ?? NSTableCellView()
    }

    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChangeContentWith snapshot: NSDiffableDataSourceSnapshotReference) {
        guard let dataSource = self.tableView?.dataSource as? NSTableViewDiffableDataSource<Int, NSManagedObjectID> else {
            assertionFailure("The data source has not implemented snapshot support while it should")
            return
        }

        dataSource.apply(snapshot as NSDiffableDataSourceSnapshot<Int, NSManagedObjectID>, animatingDifferences: true)
    }
}
