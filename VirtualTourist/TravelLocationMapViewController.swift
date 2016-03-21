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
    
    var readyForNextView: Bool = true
    
    //mapView help function
    func centerMapOnLocation(location: CLLocation){
        let regionRadius: CLLocationDistance = 10000
        let coordinateRegion = MKCoordinateRegionMakeWithDistance(location.coordinate, regionRadius * 2.0, regionRadius * 2.0)
        mapView.setRegion(coordinateRegion, animated: true)
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        let initialLocation = CLLocation(latitude: 40.709299, longitude: -74.006562)
        centerMapOnLocation(initialLocation)
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
    
    //mapView
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
        
    }
    
    func mapView(mapView: MKMapView, didSelectAnnotationView view: MKAnnotationView) {
        
        if editing{
            
            let pin = view.annotation as! Pin
            sharedContext.deleteObject(pin)
            mapView.removeAnnotation(view.annotation!)
            CoreDataStackManager.sharedInstance().saveContext()
            
        } else {
            let controller = self.storyboard?.instantiateViewControllerWithIdentifier("PhotoAlbumViewController") as! PhotoAlbumViewController
            let pin = view.annotation as! Pin
            controller.pin = pin
//            for photo in pin.photos{
//                if photo.imageData == nil{
//                    readyForNextView = false
//                }
//            }
//            if !readyForNextView {
//                pin.photos = []
//            }
            self.navigationController?.pushViewController(controller, animated: true)
            mapView.deselectAnnotation(view.annotation, animated: true)
        }
    }
    
    func dropNewPin(gestureRecognizer: UIGestureRecognizer){
        //get new pin coordinate
        if gestureRecognizer.state != .Began {return}
        let point = gestureRecognizer.locationInView(self.mapView)
        let pointCoordinate = mapView.convertPoint(point, toCoordinateFromView: mapView)
        
        //add new Pin object into sharedContext
        let newPin = Pin(newPinlatitude: pointCoordinate.latitude, newPinlongitude: pointCoordinate.longitude, context: sharedContext)
        mapView.addAnnotation(newPin)
        CoreDataStackManager.sharedInstance().saveContext()
        
        //start to download image once new Pin object was created
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)){
            
            FlickrClient.sharedInstance().getPhotosFromFlickr(newPin.latitude, dropPinLongitude: newPin.longitude, pageToReturn: 1, completionHandler: {(success, parsedResult, errorString) in
                
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

                            FlickrClient.sharedInstance().taskForImage(photo.imageUrlString!, completionHandler: {(data, error) in
                                    
                                if let error = error {
                                    print("Image download error: \(error.localizedDescription)")
                                }
                                if let data = data {
                                    photo.imageData = data
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
    
    override func setEditing(editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        if editing{
            self.deletePinAlertLabel.hidden = false
        } else {
            self.deletePinAlertLabel.hidden = true
        }
    }
}
