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
//    var totalPages: Int = 0
    var randomPage: Int = 0
    var photosToBeLoaded: Int = 0
//    var preloadedImageCount: Int = 0
    var selectedIndexes = [NSIndexPath]()
    var insertedIndexPaths: [NSIndexPath]!
    var deletedIndexPaths: [NSIndexPath]!
    var updatedIndexPaths: [NSIndexPath]!
    
    func centerMapOnLocation(location: CLLocation){
        let regionRadius: CLLocationDistance = 2000
        let coordinateRegion = MKCoordinateRegionMakeWithDistance(location.coordinate, regionRadius * 2.0, regionRadius * 2.0)
        mapView.setRegion(coordinateRegion, animated: true)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
    
        //set mapView
        centerMapOnLocation(CLLocation(latitude: pin.latitude, longitude: pin.longitude))
        mapView.addAnnotation(pin)
        
        //get associated photos objects from CoreData
        do {
            try fetchedResultsController.performFetch()
        } catch {}
        fetchedResultsController.delegate = self
        
        
        collectionView.allowsMultipleSelection = true
//        totalPages = Int(pin.totalPages)
        photosToBeLoaded = pin.photos.count
        
//        print("preloaded \(self.preloadedImageCount) photos")
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        //get photo urls from Flickr if the Pin has no linked photo object yet
        //works best when user drop pin on the map without network connection and later open the photoAlubm view with network connection.
        if pin.photos.isEmpty {
            
            //set noImageLabel to show when pin has no photos reference
            noImageLabel.hidden = false
            noImageLabel.layer.zPosition = 2
            newCollectionButton.enabled = false
            
            FlickrClient.sharedInstance().getPhotosFromFlickr(pin.latitude, dropPinLongitude: pin.longitude, pageToReturn: 1, completionHandler: {(success, parsedResult, errorString) in
                
                if let error = errorString {
                    print(error)
                } else {
                    //set totalPages property for later use
                    if let returnedTotalPages = parsedResult!["pages"] as? Int {
                        self.pin.totalPages = returnedTotalPages
                    }
                    if let photosDictionaries = parsedResult!["photo"] as? [[String:AnyObject]]{
                        
                        _ = photosDictionaries.map(){(dictionary: [String: AnyObject]) -> Photo in
                        
                            let photo = Photo(dictionary: dictionary, context: self.sharedContext)
                            photo.dropPin = self.pin
                            return photo
                        }
                        self.photosToBeLoaded = self.pin.photos.count
                        print("there are \(self.photosToBeLoaded) photos need to be loaded")
                        CoreDataStackManager.sharedInstance().saveContext()
                        dispatch_async(dispatch_get_main_queue()) {
                            if self.photosToBeLoaded > 0 {
                            self.noImageLabel.hidden = true
                            }
                        }
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
        let sessionInfo = fetchedResultsController.sections![section]
        return sessionInfo.numberOfObjects
    }
    
    
    func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        
        let collectionCell = collectionView.dequeueReusableCellWithReuseIdentifier("PhotoAlbumCollectionViewCell", forIndexPath: indexPath) as! PhotoAlbumCollectionViewCell
        let photo = fetchedResultsController.objectAtIndexPath(indexPath) as! Photo
        if collectionCell.selected{
            collectionCell.photoImageView.alpha = 0.5
        } else {
            collectionCell.photoImageView.alpha = 1
        }
        collectionCell.photoImageView.contentMode = .ScaleAspectFill
        configureCell(collectionCell, photo: photo)
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
    //
    // This is the most interesting method. Take particular note of way the that newIndexPath
    // parameter gets unwrapped and put into an array literal: [newIndexPath!]
    //
    
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
    
    //set convenience var for sharedContext
    lazy var sharedContext: NSManagedObjectContext = {
        return CoreDataStackManager.sharedInstance().managedObjectContext
    }()
    
    //set lazy var for fetchedResultsController
    lazy var fetchedResultsController: NSFetchedResultsController = {
        
        let fetchRequest = NSFetchRequest(entityName: "Photo")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "imageUrlString", ascending: true)]
        fetchRequest.predicate = NSPredicate(format: "dropPin == %@", self.pin)
        let fetchedResultController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: self.sharedContext, sectionNameKeyPath: nil, cacheName: nil)
        return fetchedResultController
    }()
    
    
    //collectionView help function
    func configureCell(cell: PhotoAlbumCollectionViewCell, photo: Photo) {
        
        var cellImage = UIImage(named: "placeHolder")
        
        cell.photoImageView.image = nil
        
        if photo.imageUrlString == nil || photo.imageUrlString == "" {
            cellImage = UIImage(named: "placeHolder")
        } else if photo.imageData != nil {
            cellImage = UIImage(data: photo.imageData!)
        }
        //if photo object has Url info but don' have stored image info:
        else {
            self.newCollectionButton.enabled = false
            let task = FlickrClient.sharedInstance().taskForImage(photo.imageUrlString!) { data, error in
                
                if let error = error {
                    print("Image download error: \(error.localizedDescription)")
                }
                
                if let returnedData = data {
                    
                    // update the model
                    photo.imageData = returnedData

                    // update the cell later, on the main thread
                    dispatch_async(dispatch_get_main_queue()) {
                        cell.photoImageView.image = UIImage(data: returnedData)
                        self.photosToBeLoaded--
                        print("loaded 1 photo, there are \(self.photosToBeLoaded) photos left to be loaded")
                        //if all photos have been loaded into cell, we set newCollectonButton status to enable
                        if (self.photosToBeLoaded) == 0 {
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
            for indexPath in self.collectionView.indexPathsForSelectedItems()!{
                photoToDelete.append(self.fetchedResultsController.objectAtIndexPath(indexPath) as! Photo)
            }
            for photo in photoToDelete{
                photo.imageData = nil
                sharedContext.deleteObject(photo)
            }
            CoreDataStackManager.sharedInstance().saveContext()
        }
        // if no photo has been selected, perform update functioin
        else {
            //each time press newCollectionButton, we set it back to disable again for cell load status check
            self.newCollectionButton.enabled = false
            self.photosToBeLoaded = 0
//            self.preloadedImageCount = 0
            
            for photo in pin.photos {
                //imageData is not stored in CoreData, so need to be removed manually from Memory and Disk
                photo.imageData = nil
                sharedContext.deleteObject(photo)
            }
            CoreDataStackManager.sharedInstance().saveContext()
            
            print("Total pages available in PhotoAlbumView: \(pin.totalPages)")
            //dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)){
                
                //here we define a randomPage variable to be within 1-50, since Flickr has total image return limit and performance issue
                self.randomPage = Int(arc4random_uniform(UInt32(50))) + 1
                
                //also we need to check that the randomPage will not be bigger than totalPages for this Pin.
                if self.randomPage > Int(pin.totalPages) {
                    self.randomPage = Int(arc4random_uniform(UInt32(Int(self.pin.totalPages)))) + 1
                } else {}
                
                print("update with randomPage: \(self.randomPage)")
                
                FlickrClient.sharedInstance().getPhotosFromFlickr(self.pin.latitude, dropPinLongitude: self.pin.longitude, pageToReturn: self.randomPage, completionHandler: {(success, parsedResult, errorString) in
                    
                    if let error = errorString {
                        print(error)
                    } else {
                        //load new data into CoreData
                        if let photosDictionaries = parsedResult!["photo"] as? [[String:AnyObject]]{
                            _ = photosDictionaries.map(){(dictionary: [String: AnyObject]) -> Photo in
                                let photo = Photo(dictionary: dictionary, context: self.sharedContext)
                                photo.dropPin = self.pin
                                CoreDataStackManager.sharedInstance().saveContext()
                                return photo
                            }
                        }
                        self.photosToBeLoaded = self.pin.photos.count
                        print("there are \(self.photosToBeLoaded) photos need to be loaded")
                    }
                })
            //}
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
}
