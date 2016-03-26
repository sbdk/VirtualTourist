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

class PhotoAlbumViewController: UIViewController, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout, UICollectionViewDataSource, NSFetchedResultsControllerDelegate {
    
    @IBOutlet weak var newCollectionButton: UIBarButtonItem!
    @IBOutlet weak var noImageLabel: UILabel!
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var flowLayout: UICollectionViewFlowLayout!
    
    var pin: Pin!
    var randomPage: Int = 0
    var photosToBeLoaded: Int = 0
    var preloadedImageCount: Int = 0
    var pinObjectID: NSManagedObjectID!
    var selectedIndexes = [NSIndexPath]()
    var insertedIndexPaths: [NSIndexPath]!
    var deletedIndexPaths: [NSIndexPath]!
    var updatedIndexPaths: [NSIndexPath]!

    override func viewDidLoad() {
        super.viewDidLoad()
        //set mapView
        centerMapOnLocation(CLLocation(latitude: pin.latitude, longitude: pin.longitude))
        mapView.addAnnotation(pin)

        //set collectionView
        collectionView.allowsMultipleSelection = true
        photosToBeLoaded = pin.photos.count
        print("new view preloaded \(preloadedImageCount) photos")
        print("new view has \(pin.photos.count) photos to be loaded")
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        //get photo urls from Flickr if the Pin has no linked photo object yet
        //works best when user drop pin on the map without network connection and later open the photoAlubm view with network connection.
//        sharedContext.refreshObject(pin, mergeChanges: true)
        backgroundContext.performBlockAndWait{
            self.backgroundContext.reset()
            do {
                try self.fetchedResultsController.performFetch()
            } catch {}
            self.fetchedResultsController.delegate = self
        }
        
        if pin.photos.isEmpty {
            
            //set noImageLabel to show when pin has no photos reference
            noImageLabel.hidden = false
            noImageLabel.layer.zPosition = 2
            newCollectionButton.enabled = false
            var photo: Photo!
            
            FlickrClient.sharedInstance().getPhotosFromFlickr(pin.latitude, dropPinLongitude: pin.longitude, pageToReturn: 1, completionHandler: {(success, parsedResult, errorString) in
                if let error = errorString {
                    print(error)
                } else {
                    //set totalPages property for later use
                    if let returnedTotalPages = parsedResult!["pages"] as? Int {
                        self.sharedContext.performBlockAndWait{
                            self.pin.totalPages = returnedTotalPages
                            self.pinObjectID = self.pin.objectID
                            CoreDataStackManager.sharedInstance().saveContext()
                        }
                    }
                    if let photosDictionaries = parsedResult!["photo"] as? [[String:AnyObject]]{
                        _ = photosDictionaries.map(){(dictionary: [String: AnyObject]) -> Photo in
                            self.backgroundContext.performBlockAndWait{
                                let photo = Photo(dictionary: dictionary, context: self.backgroundContext)
                                photo.dropPin = self.backgroundContext.objectWithID(self.pinObjectID) as? Pin
                                CoreDataStackManager.sharedInstance().saveContext()
                            }
                            return photo
                        }
                        dispatch_async(dispatch_get_main_queue()){
                            self.sharedContext.refreshObject(self.pin, mergeChanges: true)
                            self.photosToBeLoaded = self.pin.photos.count
                            if self.photosToBeLoaded > 0 {
                                self.noImageLabel.hidden = true
                            }
                            print("there are \(self.photosToBeLoaded) photos need to be loaded")
                            CoreDataStackManager.sharedInstance().saveContext()
                            
                        }
//                        dispatch_async(dispatch_get_main_queue()) {
//                            
//                        }
                    }
                }
            })
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    //comfigure collection View
    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        
        var itemCount: Int!
        backgroundContext.performBlockAndWait{
            let sessionInfo = self.fetchedResultsController.sections![section]
            itemCount = sessionInfo.numberOfObjects
        }
        print("collection view will have \(itemCount) items to be loaded")
        return itemCount
    }
    
    func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        var photo: Photo!
        let collectionCell = collectionView.dequeueReusableCellWithReuseIdentifier("PhotoAlbumCollectionViewCell", forIndexPath: indexPath) as! PhotoAlbumCollectionViewCell
        if collectionCell.selected{
            collectionCell.photoImageView.alpha = 0.5
        } else {
            collectionCell.photoImageView.alpha = 1
        }
        collectionCell.photoImageView.contentMode = .ScaleAspectFill
        
        backgroundContext.performBlockAndWait{
            photo = self.fetchedResultsController.objectAtIndexPath(indexPath) as! Photo
            self.configureCell(collectionCell, photo: photo)
        }
        return collectionCell
    }
    
    func collectionView(collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAtIndexPath indexPath: NSIndexPath) -> CGSize {
        let space: CGFloat = 3.0
        var dimension: CGFloat
        flowLayout.minimumInteritemSpacing = space
        flowLayout.minimumLineSpacing = space
        
        dimension = (view.frame.size.width - (2 * space)) / 3.0
        flowLayout.itemSize = CGSizeMake(dimension, dimension)
        return flowLayout.itemSize
    }
    
    func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath) {
        let selectedCell = collectionView.cellForItemAtIndexPath(indexPath) as! PhotoAlbumCollectionViewCell
        selectedCell.photoImageView.alpha = 0.5
        updateButtonTitile()
    }
    
    func collectionView(collectionView: UICollectionView, didDeselectItemAtIndexPath indexPath: NSIndexPath) {
        let selectedCell = collectionView.cellForItemAtIndexPath(indexPath) as! PhotoAlbumCollectionViewCell
        selectedCell.photoImageView.alpha = 1
        updateButtonTitile()
    }
    
    //implemente FetchedResultController Delegate Method
    func controllerWillChangeContent(controller: NSFetchedResultsController) {
        insertedIndexPaths = [NSIndexPath]()
        deletedIndexPaths = [NSIndexPath]()
        updatedIndexPaths = [NSIndexPath]()
    }
    func controller(controller: NSFetchedResultsController,
        didChangeObject anObject: AnyObject,
        atIndexPath indexPath: NSIndexPath?,
        forChangeType type: NSFetchedResultsChangeType,
        newIndexPath: NSIndexPath?) {
            switch type {
            case .Insert:
                insertedIndexPaths.append(newIndexPath!)
                break
            case .Delete:
                deletedIndexPaths.append(indexPath!)
                break
            case .Update:
                updatedIndexPaths.append(indexPath!)
                break
            case .Move:
                break
            default:
                break
            }
    }
    func controllerDidChangeContent(controller: NSFetchedResultsController) {
        collectionView.performBatchUpdates({
            for indexPath in self.insertedIndexPaths{
                self.collectionView.insertItemsAtIndexPaths([indexPath])
            }
            for indexPath in self.deletedIndexPaths {
                self.collectionView.deleteItemsAtIndexPaths([indexPath])
            }
            for indexPath in self.updatedIndexPaths {
                self.collectionView.reloadItemsAtIndexPaths([indexPath])
            }
        },completion: nil)
    }
    
    //set convenience var for CoreData Shared context
    var sharedContext: NSManagedObjectContext = {
        return CoreDataStackManager.sharedInstance().managedObjectMainContext
    }()
    
    var backgroundContext: NSManagedObjectContext = {
        return CoreDataStackManager.sharedInstance().managedObjectBackgroundContext
    }()
    
    //set lazy var for fetchedResultsController
    lazy var fetchedResultsController: NSFetchedResultsController = {

        let fetchRequest = NSFetchRequest(entityName: "Photo")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "imageUrlString", ascending: true)]
        fetchRequest.predicate = NSPredicate(format: "dropPin == %@", self.pin)
        let fetchedResultController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: self.backgroundContext, sectionNameKeyPath: nil, cacheName: nil)
        return fetchedResultController
    }()
    
//    func fetchPin() -> [Pin]{
//        let fetchRequest = NSFetchRequest(entityName: "Pin")
//        fetchRequest.predicate = NSPredicate(format: "latitude == %@", self.pin.latitude)
//        fetchRequest.predicate = NSPredicate(format: "longitude == %@", self.pin.longitude)
//        do{
//            return try sharedContext.executeFetchRequest(fetchRequest) as! [Pin]
//        } catch let error as NSError {
//            print("Error in fetchAllActors(): \(error)")
//            return [Pin]()
//        }
//    }
    
    //collectionView help function
    func configureCell(cell: PhotoAlbumCollectionViewCell, photo: Photo) {
        
        var photoImageData: NSData? = nil
        var photoImageUrl: String? = nil
        
        backgroundContext.performBlockAndWait{
            photoImageUrl = photo.imageUrlString
            photoImageData = photo.imageData
        }
        var cellImage = UIImage(named: "placeHolder")
        cell.photoImageView.image = nil
        
        if photoImageUrl == nil || photoImageUrl == "" {
            cellImage = UIImage(named: "placeHolder")
        } else if photoImageData != nil {
            cellImage = UIImage(data: photoImageData!)
            print("use stored imageData once")
        }
        //if photo object has Url info but don' have stored image info:
        else {
            self.newCollectionButton.enabled = false
            let task = FlickrClient.sharedInstance().taskForImage(photoImageUrl!) { data, error in
                if let error = error {
                    print("Image download error: \(error.localizedDescription)")
                }
                if let returnedData = data {
                    self.backgroundContext.performBlockAndWait{
                        photo.imageData = returnedData
                        print("photoID: \(photo.id)")
                    }
                    // update the cell later, on the main thread
                    dispatch_async(dispatch_get_main_queue()) {
                        cell.photoImageView.image = UIImage(data: returnedData)
                        self.photosToBeLoaded -= 1
                        print("downloaded 1 photo, \(self.photosToBeLoaded) photos left to be loaded from Flickr")
                        //if all photos have been loaded into cell, we set newCollectonButton status to enable
                        if self.photosToBeLoaded == 0 {
                            self.newCollectionButton.enabled = true
                            print("all photos are loaded, set new CollectionButton enable")
                        }
                    }
                }
            }
            cell.taskToCancelifCellIsReused = task
        }
        cell.photoImageView.image = cellImage
    }
    
    @IBAction func newCollectionButtonTouch(sender: AnyObject) {
        //if there is any photo selected, perform delete function
        if collectionView.indexPathsForSelectedItems()!.count > 0 {
            print("start to delete selected photos")
            var photoToDelete = [Photo]()
            backgroundContext.performBlockAndWait{
                for indexPath in self.collectionView.indexPathsForSelectedItems()!{
                    photoToDelete.append(self.fetchedResultsController.objectAtIndexPath(indexPath) as! Photo)
                }
                for photo in photoToDelete{
                    photo.imageData = nil
                    self.backgroundContext.deleteObject(photo)
                }
                CoreDataStackManager.sharedInstance().saveContext()
            }
        }
        // if no photo has been selected, perform update functioin
        else {
            //each time press newCollectionButton, we set newCollectionButton back to disable again and clear all the tracking counter
            newCollectionButton.enabled = false
            photosToBeLoaded = 0
            preloadedImageCount = 0
            let pinObjectID = pin.objectID
            let totalPages = Int(pin.totalPages)
            var photo: Photo!
            
            backgroundContext.performBlockAndWait{
                let pinToRemove = self.backgroundContext.objectWithID(pinObjectID) as! Pin
                for photo in pinToRemove.photos {
                    //imageData is not stored in CoreData, so need to be removed manually from Memory and Disk
                    photo.imageData = nil
                    self.backgroundContext.deleteObject(photo)
                }
                CoreDataStackManager.sharedInstance().saveContext()
//                self.backgroundContext.reset()
            }
            
            print("Total pages available in PhotoAlbumView: \(pin.totalPages)")
            //here we define a randomPage variable to be within 1-50, since Flickr has total image return limit and performance issue
            self.randomPage = Int(arc4random_uniform(UInt32(50))) + 1
                
            //We also need to check that the randomPage will not be bigger than totalPages for this Pin.
            if self.randomPage > Int(totalPages) {
                self.randomPage = Int(arc4random_uniform(UInt32(totalPages))) + 1
            } else {}
            print("update with randomPage: \(self.randomPage)")
            
            FlickrClient.sharedInstance().getPhotosFromFlickr(self.pin.latitude, dropPinLongitude: self.pin.longitude, pageToReturn: self.randomPage, completionHandler: {(success, parsedResult, errorString) in
                    if let error = errorString {
                        print(error)
                    } else {
                        if let photosDictionaries = parsedResult!["photo"] as? [[String:AnyObject]]{
                            
                            _ = photosDictionaries.map(){(dictionary: [String: AnyObject]) -> Photo in
                                self.backgroundContext.performBlockAndWait{
                                    photo = Photo(dictionary: dictionary, context: self.backgroundContext)
                                    print(photo.imageUrlString!)
                                    photo.dropPin = self.backgroundContext.objectWithID(pinObjectID) as? Pin
                                }
                                return photo
                            }
                            CoreDataStackManager.sharedInstance().saveContext()
                        }
                        dispatch_async(dispatch_get_main_queue()){
                            self.photosToBeLoaded = self.pin.photos.count
                            print("there are \(self.photosToBeLoaded) photos need to be loaded")
                        }
                    }
                })    
            
            
//            FlickrClient.sharedInstance().getPhotosFromFlickr(self.pin.latitude, dropPinLongitude: self.pin.longitude, pageToReturn: self.randomPage, completionHandler: {(success, parsedResult, errorString) in
//                if let error = errorString {
//                    print(error)
//                } else {
//                    //load new data into CoreData
//                    if let photosDictionaries = parsedResult!["photo"] as? [[String:AnyObject]]{
//                        _ = photosDictionaries.map(){(dictionary: [String: AnyObject]) -> Photo in
//                            self.backgroundContext.performBlockAndWait{
//                            photo = Photo(dictionary: dictionary, context: self.backgroundContext)
//                            photo.dropPin = self.backgroundContext.objectWithID(pinObjectID) as? Pin
//                                CoreDataStackManager.sharedInstance().saveContext()
//                            }
//                            return photo
//                        }
//                    }
//                    dispatch_async(dispatch_get_main_queue()){
//                        self.photosToBeLoaded = self.pin.photos.count
//                        print("there are \(self.photosToBeLoaded) photos need to be loaded")
//                    }
//                }
//            })
        }
        updateButtonTitile()
    }
    
    func updateButtonTitile(){
        if collectionView.indexPathsForSelectedItems()!.count > 0 {
            let count = collectionView.indexPathsForSelectedItems()!.count
            newCollectionButton.title = "Delete Selected \(count) Photos"
        } else {
            newCollectionButton.title = "New Collection"
        }
    }
    
    //mapView help function
    func centerMapOnLocation(location: CLLocation){
        let regionRadius: CLLocationDistance = 2000
        let coordinateRegion = MKCoordinateRegionMakeWithDistance(location.coordinate, regionRadius * 2.0, regionRadius * 2.0)
        mapView.setRegion(coordinateRegion, animated: true)
    }
}
