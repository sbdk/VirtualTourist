//
//  mapRegion.swift
//  VirtualTourist
//
//  Created by Li Yin on 3/20/16.
//  Copyright © 2016 Li Yin. All rights reserved.
//

import Foundation
import CoreData
import MapKit

class MapRegion: NSManagedObject {
    
    @NSManaged var centerLat: Double
    @NSManaged var centerLon: Double
    @NSManaged var spanLat: Double
    @NSManaged var spanLon: Double
    
    override init(entity: NSEntityDescription, insertIntoManagedObjectContext context: NSManagedObjectContext?) {
        super.init(entity: entity, insertIntoManagedObjectContext: context)
    }
    
    init(mapView: MKMapView, context: NSManagedObjectContext){
        let entity =  NSEntityDescription.entityForName("MapRegion", inManagedObjectContext: context)!
        super.init(entity: entity,insertIntoManagedObjectContext: context)
        centerLat = mapView.region.center.latitude
        centerLon = mapView.region.center.longitude
        spanLat = mapView.region.span.latitudeDelta
        spanLon = mapView.region.span.longitudeDelta
    }
}