//
//  Photo.swift
//  VirtualTourist
//
//  Created by Li Yin on 3/11/16.
//  Copyright © 2016 Li Yin. All rights reserved.
//

import UIKit
import CoreData

class Photo: NSManagedObject {
    
    @NSManaged var imageUrlString: String?
    @NSManaged var id: String?
    @NSManaged var dropPin: Pin?
    
    override init(entity: NSEntityDescription, insertIntoManagedObjectContext context: NSManagedObjectContext?) {
        super.init(entity: entity, insertIntoManagedObjectContext: context)
    }
    
    init(dictionary: [String : AnyObject], context: NSManagedObjectContext) {
        let entity =  NSEntityDescription.entityForName("Photo", inManagedObjectContext: context)!
        super.init(entity: entity, insertIntoManagedObjectContext: context)
        imageUrlString = dictionary["url_s"] as? String
        id = dictionary["id"] as? String
    }
    
    var imageData: NSData? {
        get {
            return FlickrClient.Caches.imageCache.imageDataWithIdentifier(id)
        }
        set {
            FlickrClient.Caches.imageCache.storeImageData(newValue, withIdentifier: id!)
        }
    }
}
