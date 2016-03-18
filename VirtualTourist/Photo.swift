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
    //@NSManaged var imageData: NSData?
    @NSManaged var dropPin: Pin?
    
    override init(entity: NSEntityDescription, insertIntoManagedObjectContext context: NSManagedObjectContext?) {
        super.init(entity: entity, insertIntoManagedObjectContext: context)
    }
    
    init(dictionary: [String : AnyObject], context: NSManagedObjectContext) {
        
        let entity =  NSEntityDescription.entityForName("Photo", inManagedObjectContext: context)!
        super.init(entity: entity, insertIntoManagedObjectContext: context)
        
        imageUrlString = dictionary["url_m"] as? String
    }
    
    var image: UIImage? {
        
        get {
            //return ImageCache.sharedInstance().imageWithIdentifier(imageUrlString)
            return FlickrClient.Caches.imageCache.imageWithIdentifier(imageUrlString)
        }
        set {
            //ImageCache.sharedInstance().storeImage(image, withIdentifier: imageUrlString!)
            FlickrClient.Caches.imageCache.storeImage(image, withIdentifier: imageUrlString!)
        }
    }
}
