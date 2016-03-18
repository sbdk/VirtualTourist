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
    
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var flowLayout: UICollectionViewFlowLayout!
    
    var pin: Pin!
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
    
        centerMapOnLocation(CLLocation(latitude: pin.latitude, longitude: pin.longitude))
        mapView.addAnnotation(pin)
        do {
            try fetchedResultsController.performFetch()
        } catch {}
        fetchedResultsController.delegate = self
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        if pin.photos.isEmpty {
            
            FlickrClient.sharedInstance().getPhotosFromFlickr(pin.latitude, dropPinLongitude: pin.longitude, completionHandler: {(success, parsedResult, errorString) in
                
                if let error = errorString {
                    print(error)
                } else {
                    if let photosDictionaries = parsedResult!["photo"] as? [[String:AnyObject]]{
                        
                        _ = photosDictionaries.map(){(dictionary: [String: AnyObject]) -> Photo in
                        
                            let photo = Photo(dictionary: dictionary, context: self.sharedContext)
                            photo.dropPin = self.pin
                            print(photo.imageUrlString!)
                            
                            CoreDataStackManager.sharedInstance().saveContext()
                            return photo
                        }
                        dispatch_async(dispatch_get_main_queue()) {
                            self.collectionView.reloadData()
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
        
        collectionCell.photoImageView.contentMode = .ScaleAspectFill
        //asyncLoadPhotoImage(photo, imageView: collectionCell.photoImageView)
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
        /*collectionView.performBatchUpdates({
            
            for indexPath in self.insertedIndexPaths{
                self.collectionView.insertItemsAtIndexPaths([indexPath])
            }
            for indexPath in self.deletedIndexPaths {
                self.collectionView.deleteItemsAtIndexPaths([indexPath])
            }
            for indexPath in self.updatedIndexPaths {
                self.collectionView.reloadItemsAtIndexPaths([indexPath])
            }
            
            },completion: nil)*/
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
    
    func configureCell(cell: PhotoAlbumCollectionViewCell, photo: Photo) {
        
        var cellImage = UIImage(named: "noImage")
        
        cell.photoImageView.image = nil
        
        if photo.imageUrlString == nil || photo.imageUrlString == "" {
            cellImage = UIImage(named: "noImage")
        } else if photo.image != nil {
            cellImage = photo.image
        }
            
        else {
            let task = FlickrClient.sharedInstance().taskForImage(photo.imageUrlString!) { data, error in
                
                if let error = error {
                    print("Image download error: \(error.localizedDescription)")
                }
                
                if let data = data {
                    // Craete the image
                    let image = UIImage(data: data)
                    
                    // update the model
                    photo.image = image
                    
                    // update the cell later, on the main thread
                    dispatch_async(dispatch_get_main_queue()) {
                        cell.photoImageView.image = image
                    }
                }
            }
            cell.taskToCancelifCellIsReused = task

        }
        
        cell.photoImageView.image = cellImage
    }
    
    func asyncLoadPhotoImage(photo: Photo, imageView: UIImageView){
        let downloadQueue = dispatch_queue_create("virtualTourist", nil)
        
        dispatch_async(downloadQueue) {
            guard let data = NSData(contentsOfURL: NSURL(string: photo.imageUrlString!)!) else {
                print("get error when get image from URL")
                return
            }
            var image: UIImage?
            image = UIImage(data: data)
            photo.image = image
            
            dispatch_async(dispatch_get_main_queue()){
                imageView.image = image
            }
        }
    }
}
