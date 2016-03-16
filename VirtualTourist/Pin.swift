//
//  Pin.swift
//  VirtualTourist
//
//  Created by Li Yin on 3/11/16.
//  Copyright © 2016 Li Yin. All rights reserved.
//

import UIKit
import MapKit
import CoreData

class Pin: NSManagedObject, MKAnnotation {
    
    @NSManaged var latitude: Double
    @NSManaged var longitude: Double
    //@NSManaged var title: String
    @NSManaged var photos: [Photo]
    
    //Standard Core Data init method.
    override init(entity: NSEntityDescription, insertIntoManagedObjectContext context: NSManagedObjectContext?) {
        super.init(entity: entity, insertIntoManagedObjectContext: context)
    }
    
    init(newPinlatitude: CLLocationDegrees, newPinlongitude: CLLocationDegrees, context: NSManagedObjectContext){
        let entity =  NSEntityDescription.entityForName("Pin", inManagedObjectContext: context)!
        super.init(entity: entity,insertIntoManagedObjectContext: context)
        latitude = newPinlatitude
        longitude = newPinlongitude
        
        //let formatter = NSDateFormatter()
        //formatter.dateStyle = NSDateFormatterStyle.MediumStyle
        //formatter.timeStyle = .LongStyle
        //let titleString = formatter.stringFromDate(NSDate())
        //title = titleString
    }
    
    var coordinate: CLLocationCoordinate2D {
        
        return CLLocationCoordinate2DMake(latitude, longitude)
    }
}
