//
//  PhotoAlbumViewViewController.swift
//  VirtualTourist
//
//  Created by Li Yin on 3/11/16.
//  Copyright © 2016 Li Yin. All rights reserved.
//

import UIKit
import MapKit
import CoreData

class PhotoAlbumViewController: UIViewController {
    
    @IBOutlet weak var mapView: MKMapView!
    let regionRadius: CLLocationDistance = 2000
    var pin: Pin? = nil
    var pinCoordinate: CLLocationCoordinate2D? = nil

    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationController?.navigationBar.hidden = false
        
        centerMapOnLocation(CLLocation(latitude: (pinCoordinate?.latitude)!, longitude: (pinCoordinate?.longitude)!))
        let annotation = MKPointAnnotation()
        annotation.coordinate = pinCoordinate!
        mapView.addAnnotation(annotation)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    //set convenience var for sharedContext
    lazy var sharedContext: NSManagedObjectContext = {
        
        return CoreDataStackManager.sharedInstance().managedObjectContext
    }()
    
    //set lazy var for fetchedResultsController
    lazy var fetchedResultsController: NSFetchedResultsController = {
        
        let fetchRequest = NSFetchRequest(entityName: "Photo")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "", ascending: true)]
        let fetchedResultController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: self.sharedContext, sectionNameKeyPath: nil, cacheName: nil)
        return fetchedResultController
    }()
    
    func backFunction(){
        self.dismissViewControllerAnimated(true, completion: nil)
    }
    
    func centerMapOnLocation(location: CLLocation){
        let coordinateRegion = MKCoordinateRegionMakeWithDistance(location.coordinate, regionRadius * 2.0, regionRadius * 2.0)
        mapView.setRegion(coordinateRegion, animated: true)
    }

}
