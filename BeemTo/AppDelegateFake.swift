//
//  AppDelegateFake.swift
//  BeemTo
//
//  Created by Keaton Burleson on 4/26/21.
//

import Foundation
import CoreData

class AppDelegate {
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
}
