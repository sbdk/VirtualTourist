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
    
    var urlTask: NSURLSessionTask? = nil
    var imageDataTask: NSURLSessionTask? = nil
    var preloadedImageCount: Int = 0
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        setMapViewRegion()
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        deletePinAlertLabel.hidden = true
        deletePinAlertLabel.layer.masksToBounds = true
        deletePinAlertLabel.layer.cornerRadius = 5
        
        navigationItem.rightBarButtonItem = self.editButtonItem()
        mapView.delegate = self
        mapView.addAnnotations(fetchAllPins())
        
        //add longPressRecogniser into mapView
        let longPressRecogniser = UILongPressGestureRecognizer(target: self, action: "dropNewPin:")
        longPressRecogniser.minimumPressDuration = 1.0
        mapView.addGestureRecognizer(longPressRecogniser)
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
        
        if editing{
            
            let pin = view.annotation as! Pin
            for photo in pin.photos {
                //imageData is not stored in CoreData, so need to be removed manually from Memory and Disk
                photo.imageData = nil
                sharedContext.deleteObject(photo)
            }
            sharedContext.deleteObject(pin)
            mapView.removeAnnotation(view.annotation!)
            CoreDataStackManager.sharedInstance().saveContext()
            
        } else {
            urlTask?.cancel()
            imageDataTask?.cancel()
            
            let controller = self.storyboard?.instantiateViewControllerWithIdentifier("PhotoAlbumViewController") as! PhotoAlbumViewController
            let pin = view.annotation as! Pin
            controller.pin = pin
//            controller.preloadedImageCount = self.preloadedImageCount
            
            
            
            
//            for photo in pin.photos{
//                if photo.imageData == nil{
//                    readyForNextView = false
//                    self.downloadPhotoTask?.cancel()
//                }
//            }
//            if !readyForNextView {
//                    
//                for photo in controller.pin.photos {
//                    //imageData is not stored in CoreData, so need to be removed manually from Memory and Disk
//                    photo.imageData = nil
//                    sharedContext.deleteObject(photo)
//                }
//                CoreDataStackManager.sharedInstance().saveContext()
//            }
            self.navigationController?.pushViewController(controller, animated: true)
            mapView.deselectAnnotation(view.annotation, animated: true)
        }
    }
    
    func dropNewPin(gestureRecognizer: UIGestureRecognizer){
        //get new pin coordinate
        preloadedImageCount = 0
        if gestureRecognizer.state != .Began {return}
        let point = gestureRecognizer.locationInView(self.mapView)
        let pointCoordinate = mapView.convertPoint(point, toCoordinateFromView: mapView)
//        var newPin: Pin? = nil
//        
//        switch gestureRecognizer.state {
//            
//        case .Began:
//            print("began gesture state")
//            let newPin = Pin(newPinlatitude: pointCoordinate.latitude, newPinlongitude: pointCoordinate.longitude, context: sharedContext)
//            mapView.addAnnotation(newPin)
//            
//        case .Changed:
//            print("change gesture state")
//            newPin?.coordinate = pointCoordinate
//            
//        case .Ended:
//            print("ended gesture state")
//            newPin?.coordinate = pointCoordinate
//        
//        default: return
//            
//        }
        //add new Pin object into sharedContext
        let newPin = Pin(newPinlatitude: pointCoordinate.latitude, newPinlongitude: pointCoordinate.longitude, context: sharedContext)
        mapView.addAnnotation(newPin)
        
        CoreDataStackManager.sharedInstance().saveContext()
        
        //start to download image once new Pin object was created
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)){
        
                self.urlTask = FlickrClient.sharedInstance().getPhotosFromFlickr(newPin.latitude, dropPinLongitude: newPin.longitude, pageToReturn: 1, completionHandler: {(success, parsedResult, errorString) in
                
                if let error = errorString {
                    print(error)
                } else {
                    if let returnedTotalPages = parsedResult!["pages"] as? Int {
                        newPin.totalPages = returnedTotalPages
                        print("total pages: \(newPin.totalPages)")
                    }
                    if let photosDictionaries = parsedResult!["photo"] as? [[String:AnyObject]]{
                        
                        _ = photosDictionaries.map(){(dictionary: [String: AnyObject]) -> Photo in
                            let photo = Photo(dictionary: dictionary, context: self.sharedContext)
                            print(photo.imageUrlString!)
                            
                            //assign relationship between Pin and Photo object
                            photo.dropPin = newPin
                            CoreDataStackManager.sharedInstance().saveContext()

                            self.imageDataTask = FlickrClient.sharedInstance().taskForImage(photo.imageUrlString!, completionHandler: {(data, error) in
                                    
                                if let error = error {
                                    print("Image download error: \(error.localizedDescription)")
                                }
                                if let data = data {
                                    
                                    dispatch_async(dispatch_get_main_queue()){
                                        photo.imageData = data
                                        self.preloadedImageCount++}
                                }
                            })
                            return photo
                        }
                    } else {
                        print("there is no photo at this location")
                    }
                }
            })
        }
    }
    
    //CoreData help function
    lazy var sharedContext: NSManagedObjectContext = {
        return CoreDataStackManager.sharedInstance().managedObjectContext
    }()
    
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
            //since MapRegion CoreData will be cleaned once used, 
            //therefore the first item in fetched result will always be the only one and the most up-to-date MapRegion Object

            return try sharedContext.executeFetchRequest(fetchRequest) as! [MapRegion]
        } catch let error as NSError {
            print("Error in fetchAllActors(): \(error)")
            return [MapRegion]()
        }
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
        } else {
            
        }
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
