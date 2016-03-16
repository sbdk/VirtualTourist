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
    
    @NSManaged var imageUrlString: String
    @NSManaged var image: UIImage
    @NSManaged var dropPin: Pin
    
    override init(entity: NSEntityDescription, insertIntoManagedObjectContext context: NSManagedObjectContext?) {
        super.init(entity: entity, insertIntoManagedObjectContext: context)
    }
    
    init(dictionary: [String : AnyObject], context: NSManagedObjectContext) {
        
        // Core Data
        let entity =  NSEntityDescription.entityForName("Photo", inManagedObjectContext: context)!
        super.init(entity: entity, insertIntoManagedObjectContext: context)
        
        // Dictionary
        imageUrlString = dictionary["url_m"] as! String
        
        guard let imageURL = NSURL(string: imageUrlString) else {
            print("error when transform Url String")
            return
        }
        if let imageData = NSData(contentsOfURL: imageURL) {
            image = UIImage(data: imageData)!
        }
    }
}
