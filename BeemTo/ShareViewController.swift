//
//  ShareViewController.swift
//  BeemTo
//
//  Created by Keaton Burleson on 4/26/21.
//

import UIKit
import Social
import MobileCoreServices
import CoreData
import Network

class ShareViewController: SLComposeServiceViewController {

    private var urlString: String?
    private var textString: String?
    private var browser: Browser?
    private var selectedDestination: NWBrowser.Result?

    var devices: [NWBrowser.Result] = []
    var currentItem: BeemItem?
    
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

       let storeUrl =  FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.kbrleson.beemer")!.appendingPathComponent("Beemer.sqlite")


       let description = NSPersistentStoreDescription()
       description.shouldInferMappingModelAutomatically = true
       description.shouldMigrateStoreAutomatically = true
       description.url = storeUrl

       container.persistentStoreDescriptions = [NSPersistentStoreDescription(url:  FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.kbrleson.beemer")!.appendingPathComponent("Beemer.sqlite"))]

       container.loadPersistentStores(completionHandler: { (storeDescription, error) in
           if let error = error as NSError? {
               fatalError("Unresolved error \(error), \(error.userInfo)")
           }
       })
       return container
   }()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.browser = Browser.init()
        self.browser?.delegate = self


        let extensionItem = extensionContext?.inputItems[0] as! NSExtensionItem
        let contentTypeURL = kUTTypeURL as String
        let contentTypeText = kUTTypeText as String

        for attachment in extensionItem.attachments! {
            if attachment.hasItemConformingToTypeIdentifier(contentTypeURL) {
                attachment.loadItem(forTypeIdentifier: contentTypeURL, options: nil, completionHandler: { (results, error) in
                    let url = results as! URL?
                    self.urlString = url!.absoluteString
                })
            }
            if attachment.hasItemConformingToTypeIdentifier(contentTypeText) {
                attachment.loadItem(forTypeIdentifier: contentTypeText, options: nil, completionHandler: { (results, error) in
                    let text = results as! String
                    self.textString = text
                    _ = self.isContentValid()
                })
            }
        }
        
        for item in (self.navigationController?.navigationBar.items)! {
            if let rightItem = item.rightBarButtonItem {
                rightItem.title = "Beem"
                break
            }
        }
    }

    
    override func isContentValid() -> Bool {
        if (urlString != nil || textString != nil) && self.selectedDestination != nil {
            if !contentText.isEmpty {
                return true
            }
        }
        
        return false
    }

    override func didSelectPost() {
        NSKeyedArchiver.setClassName("BeemItem", for: BeemItem.self)
        
        let managedContext = self.persistentContainer.viewContext
        self.currentItem = BeemItem(message: self.textString ?? self.contentText, url: self.urlString!, source: UIDevice.current.name, on: Date(), context: managedContext)
      
        
        do {
            try managedContext.save()
          } catch let error as NSError {
            print("Could not save. \(error), \(error.userInfo)")
          }
        
        guard let destination = self.selectedDestination?.endpoint else {
            return
        }
        
        self.browser?.establishConnection(with: destination)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            super.didSelectPost()
        }
    }

    override func configurationItems() -> [Any]! {
        let item = SLComposeSheetConfigurationItem()
        item?.title = "Destination"
        item?.value = self.formatName(endpoint: self.selectedDestination?.endpoint) ?? "None"

        item?.tapHandler = {
            let selectViewController = SelectDestinationViewController()
            selectViewController.delegate = self
            selectViewController.destinations = self.devices
            self.pushConfigurationViewController(selectViewController)
        }

        return [item!]
    }

    func reloadAndSelect() {
        if self.selectedDestination == nil {
            self.selectedDestination = self.devices.first
        }
        
        self.reloadConfigurationItems()
    }
    
    private func formatName(endpoint: NWEndpoint?) -> String? {
        if let endpoint = endpoint {
            return "\(endpoint)".replacingOccurrences(of: "._beemer._udplocal.", with: "")
        }
        
        return nil
    }
}

extension ShareViewController: BrowserDelegate {
    func devicesChanged(devices: [NWBrowser.Result]) {
        self.devices = devices
        self.reloadAndSelect()
    }

    func connectionReady() {
        print("Sending item: \(String(describing: self.currentItem))")
        self.browser?.send(item: self.currentItem!)
    }

    func dataSent(error: Error?) {
        if let error = error {
            print("Error sending data: \(error)")
        } else {
            print("Data sent successfully")
            self.browser?.stop()
        }
    }
}


extension ShareViewController: SelectDestinationViewControllerDelegate {
    func selected(destination: NWBrowser.Result) {
        self.selectedDestination = destination
        self.reloadAndSelect()
        self.popConfigurationViewController()
    }


}
