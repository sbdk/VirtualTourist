//
//  TravelLocationMapView.swift
//  VirtualTourist
//
//  Created by Li Yin on 3/11/16.
//  Copyright © 2016 Li Yin. All rights reserved.
//

import UIKit
import MapKit
import CoreData


class TravelLocationMapViewController: UIViewController, MKMapViewDelegate {
    
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var deletePinAlertLabel: UILabel!
    var preloadedImageCount: Int = 0
    var photoNeedTobeLoaded: Int = 0

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        self.setMapViewRegion()
        preloadedImageCount = 0
        photoNeedTobeLoaded = 0
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        deletePinAlertLabel.hidden = true
        deletePinAlertLabel.layer.masksToBounds = true
        deletePinAlertLabel.layer.cornerRadius = 5
        navigationItem.rightBarButtonItem = self.editButtonItem()
        mapView.delegate = self
        self.mapView.addAnnotations(self.fetchAllPins())
        
        //add longPressRecogniser into mapView
        let longPressRecogniser = UILongPressGestureRecognizer(target: self, action: "dropNewPin:")
        longPressRecogniser.minimumPressDuration = 1.0
        mapView.addGestureRecognizer(longPressRecogniser)
        
        //reduce application's resource requirements to improve background thread performance
        backgroundContext.undoManager = nil
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        //whenever user tap a pin, save the current map region into CoreData
        //makesure even when the map region does not change(tap a pin right after re-launching the app), 
        //the present mapRegion data will still be stored in CoreData.
        _ = MapRegion(mapView: mapView, context: sharedContext) as MapRegion
        CoreDataStackManager.sharedInstance().saveContext()
    }
    
    //Whenever the mapView region changed, we save the final state into CoreData
    func mapView(mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        //whenever user change the map region, save this change into CoreData
        _ = MapRegion(mapView: mapView, context: sharedContext) as MapRegion
        CoreDataStackManager.sharedInstance().saveContext()
    }
    
    func mapView(mapView: MKMapView, viewForAnnotation annotation: MKAnnotation) -> MKAnnotationView? {
        let reuseId = "pin"
        var pinView = mapView.dequeueReusableAnnotationViewWithIdentifier(reuseId) as? MKPinAnnotationView
        if pinView == nil {
            pinView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: reuseId)
            pinView!.animatesDrop = true
            pinView!.draggable = true
            pinView!.pinTintColor = UIColor.redColor()
        }
        else {
            pinView!.annotation = annotation
        }
        return pinView
    }
    
    func mapView(mapView: MKMapView, annotationView view: MKAnnotationView, didChangeDragState newState: MKAnnotationViewDragState, fromOldState oldState: MKAnnotationViewDragState) {
        switch (newState){
        case .Starting:
            view.dragState = .Dragging
        case .Ending, .None:
            view.dragState = .None
        default: break
        }
    }
    
    func mapView(mapView: MKMapView, didSelectAnnotationView view: MKAnnotationView) {
        
        if editing{ //in editing state, pin will be removed once tapped by user
            let pin = view.annotation as! Pin
            let pinObjectID = pin.objectID
            backgroundContext.performBlockAndWait{
                let pinToRemove = self.backgroundContext.objectWithID(pinObjectID) as! Pin
                for photo in pinToRemove.photos {
                    //imageData is not stored in CoreData, so need to be removed manually from Memory and Disk
                    photo.imageData = nil
                    self.backgroundContext.deleteObject(photo)
                }
                CoreDataStackManager.sharedInstance().saveContext()
            }
            self.sharedContext.deleteObject(pin)
            CoreDataStackManager.sharedInstance().saveContext()
            mapView.removeAnnotation(view.annotation!)
            
            
        } else { // in normal state, perform follow functions
            let controller = self.storyboard?.instantiateViewControllerWithIdentifier("PhotoAlbumViewController") as! PhotoAlbumViewController
            let pin = view.annotation as! Pin
            controller.preloadedImageCount = self.preloadedImageCount
            if preloadedImageCount == photoNeedTobeLoaded {
                controller.pin = pin
                self.navigationController?.pushViewController(controller, animated: true)
                mapView.deselectAnnotation(view.annotation, animated: true)
            }
        }
    }
    
    //*** CoreData help function ***
    var sharedContext: NSManagedObjectContext {
        return CoreDataStackManager.sharedInstance().managedObjectMainContext
    }
    
    var backgroundContext: NSManagedObjectContext {
        return CoreDataStackManager.sharedInstance().managedObjectBackgroundContext
    }
    
    func fetchAllPins() -> [Pin]{
        let fetchRequest = NSFetchRequest(entityName: "Pin")
        do{
            return try sharedContext.executeFetchRequest(fetchRequest) as! [Pin]
        } catch let error as NSError {
            print("Error in fetchAllActors(): \(error)")
            return [Pin]()
        }
    }
    
    func fetchStoredMapRegion() -> [MapRegion] {
        let fetchRequest = NSFetchRequest(entityName: "MapRegion")
        do{
            return try sharedContext.executeFetchRequest(fetchRequest) as! [MapRegion]
        } catch let error as NSError {
            print("Error in fetchAllActors(): \(error)")
            return [MapRegion]()
        }
    }
    
    // *** mapView help function ***
    func dropNewPin(gestureRecognizer: UIGestureRecognizer){
        //get new pin coordinate
        if gestureRecognizer.state != .Began {return}
        let point = gestureRecognizer.locationInView(self.mapView)
        let pointCoordinate = mapView.convertPoint(point, toCoordinateFromView: mapView)
        var photo: Photo!
        var pinObjectID: NSManagedObjectID!
        
        //add new Pin object into sharedContext
        let newPin = Pin(newPinlatitude: pointCoordinate.latitude, newPinlongitude: pointCoordinate.longitude, context: self.sharedContext)
        CoreDataStackManager.sharedInstance().saveContext()
        self.mapView.addAnnotation(newPin)
        
        //initiate preloadedImageCount to 0, prepare to take photo load count for dropped new pin.
        self.preloadedImageCount = 0
        self.photoNeedTobeLoaded = 0
        
        //start to download image once new Pin object was created
        FlickrClient.sharedInstance().getPhotosFromFlickr(newPin.latitude, dropPinLongitude: newPin.longitude, pageToReturn: 1, completionHandler: {(success, parsedResult, errorString) in
            if let error = errorString {
                print(error)
            } else {
                if let returnedTotalPages = parsedResult!["pages"] as? Int {
                    self.sharedContext.performBlockAndWait{
                        newPin.totalPages = returnedTotalPages
                        print("total pages: \(newPin.totalPages)")
                        pinObjectID = newPin.objectID
                        CoreDataStackManager.sharedInstance().saveContext()
                    }
                }
                if let photosDictionaries = parsedResult!["photo"] as? [[String:AnyObject]]{
                    
                    _ = photosDictionaries.map(){(dictionary: [String: AnyObject]) -> Photo in
                        self.backgroundContext.performBlockAndWait{
                            photo = Photo(dictionary: dictionary, context: self.backgroundContext)
                            print(photo.imageUrlString!)
                            photo.dropPin = self.backgroundContext.objectWithID(pinObjectID) as? Pin
                            CoreDataStackManager.sharedInstance().saveContext()
                    
                            FlickrClient.sharedInstance().taskForImage(photo.imageUrlString!, completionHandler: {(data, error) in
                                if let error = error {
                                    print("Image download error: \(error.localizedDescription)")
                                }
                                if let data = data {
                                    self.backgroundContext.performBlockAndWait{
                                        photo.imageData = data
                                        print("preload one image")
                                        self.preloadedImageCount++
                                    }
                                }
                            })
                        }
                        return photo
                    }
                }
                dispatch_async(dispatch_get_main_queue()){
                    self.sharedContext.refreshObject(newPin, mergeChanges: true)
                    self.photoNeedTobeLoaded = newPin.photos.count
                    print("now we have \(newPin.photos.count) photos to be loaded in the background")
                    CoreDataStackManager.sharedInstance().saveContext()
                }
            }
        })
    }
    
    func setMapViewRegion(){
        
        //first check CoreData for stored map region,
        //if has value, initiate the mapView with last stored map region
        if !fetchStoredMapRegion().isEmpty {
            let savedMapRegion = fetchStoredMapRegion().last
            let savedRegionCenterCoordinate = CLLocationCoordinate2DMake(savedMapRegion!.centerLat, savedMapRegion!.centerLon)
            let savedRegionSpan = MKCoordinateSpanMake(savedMapRegion!.spanLat, savedMapRegion!.spanLon)
            let savedRegion = MKCoordinateRegionMake(savedRegionCenterCoordinate, savedRegionSpan)
            mapView.setRegion(savedRegion, animated: true)
            
            //once the latest stored map region has been used,
            //Clean teh whole MapRegion CoreData for late use.
            for region in fetchStoredMapRegion(){
                sharedContext.deleteObject(region)
            }
            CoreDataStackManager.sharedInstance().saveContext()
        } else {print("use default mapRegion")}
    }

    override func setEditing(editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        if editing{
            self.deletePinAlertLabel.hidden = false
        } else {
            self.deletePinAlertLabel.hidden = true
        }
    }
}
