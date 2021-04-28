//
//  BeemItem.swift
//  Beemer
//
//  Created by Keaton Burleson on 4/26/21.
//

import Foundation
import CoreData

#if os(OSX)
    import Cocoa
#elseif os(iOS)
    import UIKit
#endif

class BeemItem: NSManagedObject, Codable, NSCoding, NSSecureCoding {
    static var supportsSecureCoding: Bool = true

    enum CodingKeys: CodingKey {
        case url, source, message, on
    }

    required convenience init(from decoder: Decoder) throws {
        guard let context = decoder.userInfo[CodingUserInfoKey.context!] as? NSManagedObjectContext else { fatalError() }
        guard let entity = NSEntityDescription.entity(forEntityName: "BeemItem", in: context) else { fatalError() }

        self.init(entity: entity, insertInto: context)

        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.url = try container.decode(String.self, forKey: .url)
        self.source = try container.decode(String.self, forKey: .source)
        self.message = try container.decode(String.self, forKey: .message)
        self.on = try container.decode(Date.self, forKey: .on)
    }

    convenience init(message: String, url: String, source: String, on: Date, context: NSManagedObjectContext) {
        guard let entity = NSEntityDescription.entity(forEntityName: "BeemItem", in: context) else { fatalError() }

        self.init(entity: entity, insertInto: context)
        self.message = message
        self.url = url
        self.source = source
        self.on = on
    }

    convenience init(message: String, url: String, source: String, on: Date) {
        self.init()

        self.message = message
        self.url = url
        self.source = source
        self.on = on
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(url, forKey: .url)
        try container.encode(message, forKey: .message)
        try container.encode(source, forKey: .source)
        try container.encode(on, forKey: .on)
    }

    required convenience init?(coder decoder: NSCoder) {
        guard let message = decoder.decodeObject(forKey: "message") as? String,
            let url = decoder.decodeObject(forKey: "url") as? String,
            let source = decoder.decodeObject(forKey: "source") as? String,
            let on = decoder.decodeObject(of: NSDate.self, forKey: "on")
            else { return nil }


        #if os(OSX)
            let context = (NSApp.delegate as! AppDelegate).persistentContainer.viewContext
            let entity = NSEntityDescription.entity(forEntityName: "BeemItem", in: context)!
            self.init(entity: entity, insertInto: context)
            self.message = message
            self.url = url
            self.source = source
            self.on = on as Date
        #elseif os(iOS)
            self.init(message: message, url: url, source: source, on: on as Date)
        #endif

    }

    func cloneWithContext(context: NSManagedObjectContext) -> BeemItem {
        return BeemItem(message: self.message!, url: self.url!, source: self.source!, on: self.on!, context: context)
    }

    func encode(with coder: NSCoder) {
        coder.encode(self.url, forKey: "url")
        coder.encode(self.message, forKey: "message")
        coder.encode(self.source, forKey: "source")
        coder.encode(self.on ?? Date() as NSDate, forKey: "on")
    }

}

extension CodingUserInfoKey {
    static let context = CodingUserInfoKey(rawValue: "context")
}
