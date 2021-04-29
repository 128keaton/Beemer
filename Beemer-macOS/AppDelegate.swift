//
//  AppDelegate.swift
//  Beemer-macOS
//
//  Created by Keaton Burleson on 4/15/21.
//

import Cocoa
import UserNotifications

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet var menuBarManager: MenuBarManager?

    var canSendNotifications = false
    var server: Server?

    lazy var persistentContainer: NSPersistentContainer = {
        /*
        The persistent container for the application. This implementation
        creates and returns a container, having loaded the store for the
        application to it. This property is optional since there are legitimate
        error conditions that could cause the creation of the store to fail.
        */
        let container = NSPersistentContainer(name: "Beemer")

        let appName: String = "Beemer"
        var persistentStoreDescriptions: NSPersistentStoreDescription

        let storeUrl = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.kbrleson.beemer")!.appendingPathComponent("Beemer.sqlite")

        print("storeURL: \(storeUrl)")

        let description = NSPersistentStoreDescription()
        description.shouldInferMappingModelAutomatically = true
        description.shouldMigrateStoreAutomatically = true
        description.url = storeUrl

        container.persistentStoreDescriptions = [NSPersistentStoreDescription(url: FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.kbrleson.beemer")!.appendingPathComponent("Beemer.sqlite"))]

        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        return container
    }()


    func applicationDidFinishLaunching(_ aNotification: Notification) {
        self.server = Server.init()
        self.server?.delegate = self

        let center = UNUserNotificationCenter.current()
        let options: UNAuthorizationOptions = [.alert, .badge, .sound]

        center.delegate = self
        center.requestAuthorization(options: options) { (granted, error) in
            self.canSendNotifications = granted
            if granted {
                print("We can send notifications")
                let openURLChoice = UNNotificationAction(identifier: "openURL", title: "Open in Browser", options: [.foreground])
                let newItemSentCategory = UNNotificationCategory(identifier: "newItemSentCategory", actions: [openURLChoice], intentIdentifiers: [], options: [])
                UNUserNotificationCenter.current().setNotificationCategories([newItemSentCategory])
            }

            if let error = error {
                print(error)
            }
        }
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    // MARK: Bonjour Client Handling
    func displayNotification(forItem item: BeemItem) {
        let notificationContent = UNMutableNotificationContent()
        notificationContent.title = "Beemer"

        if let message = item.message, message.count > 0 {
            notificationContent.subtitle = "\(item.source ?? "Anonymous") sent:"
            notificationContent.body = message
        } else if let url = item.url, url.count > 0 {
            notificationContent.subtitle = "\(item.source ?? "Anonymous") sent:"
            notificationContent.body = url
        }
        
        notificationContent.badge = 1
        notificationContent.categoryIdentifier = "newItemSentCategory"
        notificationContent.userInfo["objectID"] = item.objectID.uriRepresentation().absoluteString

        let notificationTrigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)

        let request = UNNotificationRequest(identifier: "beemItem", content: notificationContent, trigger: notificationTrigger)

        UNUserNotificationCenter.current().add(request) { (err) in
            if let error = err {
                print("Could not add notification: \(error.localizedDescription)")
            }
        }

    }


    func handleItemReceived(item: BeemItem) {
        let managedContext = self.persistentContainer.viewContext
        do {
            try managedContext.save()


            if self.canSendNotifications {
                self.displayNotification(forItem: item)
            }

            print("Saved")
        } catch let error as NSError {
            print("Error saving: \(error.localizedDescription)")
        }

    }

    func openURLForObjectID(objectID: String) {
        guard let uriRepresentation = URL(string: objectID) else {
            return
        }

        let storeCoordinator = self.persistentContainer.persistentStoreCoordinator
        let context = self.persistentContainer.viewContext

        guard let itemID = storeCoordinator.managedObjectID(forURIRepresentation: uriRepresentation) else {
            return
        }

        do {
            guard let item = try context.existingObject(with: itemID) as? BeemItem else {
                return
            }

            print(item)

            if let urlString = item.url, let url = URL(string: urlString) {
                print("Opening: \(url)")
                DispatchQueue.main.async {
                    NSWorkspace.shared.open(url)
                }
            }
        } catch {
            print("Could not find item: \(error.localizedDescription)")
        }
    }

}

extension AppDelegate: ServerDelegate {
    func itemReceived(item: BeemItem?, error: Error?) {
        if let item = item {
            self.handleItemReceived(item: item)
        } else if let error = error {
            print("Error! \(error.localizedDescription)")
        }
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.list, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        if let objectID = response.notification.request.content.userInfo["objectID"] as? String {
            if response.actionIdentifier == "openURL" {
                self.openURLForObjectID(objectID: objectID)
            } else {
                self.menuBarManager?.pop()
            }

        }
        completionHandler()
    }

}
