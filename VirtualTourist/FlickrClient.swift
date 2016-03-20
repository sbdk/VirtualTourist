//
//  VirtualTouristClient.swift
//  VirtualTourist
//
//  Created by Li Yin on 3/15/16.
//  Copyright © 2016 Li Yin. All rights reserved.
//

import UIKit
import CoreData


class FlickrClient: NSObject {
    
    var session: NSURLSession
    
    class func sharedInstance() -> FlickrClient {
        struct Singleton {
            static var sharedInstance = FlickrClient()
        }
        return Singleton.sharedInstance
    }
    
    override init() {
        session = NSURLSession.sharedSession()
        super.init()
    }
    
    let BASE_URL = "https://api.flickr.com/services/rest/"
    
    func getPhotosFromFlickr(dropPinLatitude: Double, dropPinLongitude: Double, pageToReturn: Int, completionHandler: (success: Bool, parsedReuslt: [String: AnyObject]?, errorString: String?) -> Void) {
        
        let methodParameters = [
            "method": "flickr.photos.search",
            "api_key": "679cb48bf90f3cbda78b28b73721cf0e",
            "safe_search":"1",
            "content_type":"1",
            "extras": "url_s",
            "format": "json",
            "nojsoncallback": "1",
            "per_page":"15",
            "page":"\(pageToReturn)",
            "lat": "\(dropPinLatitude)",
            "lon": "\(dropPinLongitude)",
            "radius":"1"
        ]
        let session = NSURLSession.sharedSession()
        let urlString = BASE_URL + escapedParameters(methodParameters)
        let url = NSURL(string: urlString)!
        let request = NSURLRequest(URL: url)
        
        let task = session.dataTaskWithRequest(request) { (data, response, error) in
            guard (error == nil) else {
                print("there was an error with your request: \(error)")
                return
            }
            guard let statusCode = (response as? NSHTTPURLResponse)?.statusCode where statusCode >= 200 && statusCode <= 299 else {
                if let response = response as? NSHTTPURLResponse {
                    print("Your request returned an invalid response! Status code: \(response.statusCode)!")
                } else if let response = response {
                    print("Your request returned an invalid response! Response: \(response)!")
                } else {
                    print("Your request returned an invalid response!")
                }
                return
            }
            guard let data = data else {
                print("No data was returned by the request!")
                return
            }
            let parsedResult: AnyObject!
            do {
                parsedResult = try NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions.AllowFragments)
            } catch {
                parsedResult = nil
                print("Cound not parse the data as JSON: '\(data)'")
                completionHandler(success: false, parsedReuslt: nil, errorString: "Cound not parse the data as JSON")
                return
            }
            guard let stat = parsedResult["stat"] as? String where stat == "ok" else {
                print("Cannot find keys 'photo' in \(parsedResult)")
                completionHandler(success: false, parsedReuslt: nil, errorString: "Cannot find keys 'photo' in parsedResult")
                return
            }
            if let photosDictionary = parsedResult["photos"] as? [String:AnyObject]{
                
                completionHandler(success: true, parsedReuslt: photosDictionary, errorString: nil)
                } else {
                print("there is no photos returned in the result")
                completionHandler(success: true, parsedReuslt: nil, errorString: nil)
            }
        }
        task.resume()
    }
    
    func taskForImage(filePath: String, completionHandler: (imageData: NSData?, error: NSError?) ->  Void) -> NSURLSessionTask {
        
        let request = NSURLRequest(URL: NSURL(string: filePath)!)
        
        let task = session.dataTaskWithRequest(request) {data, response, downloadError in
            
            if let error = downloadError {
                //let newError = TheMovieDB.errorForData(data, response: response, error: error)
                completionHandler(imageData: nil, error: error)
            } else {
                completionHandler(imageData: data, error: nil)
            }
        }
        
        task.resume()
        
        return task
    }
    
    //convenience function for load image
    func getPhotos(pin: Pin, page: Int){
        
        getPhotosFromFlickr(pin.latitude, dropPinLongitude: pin.longitude, pageToReturn: page, completionHandler: {(success, parsedResult, errorString) in
        
            if let error = errorString{
                print(error.lowercaseString)
            } else {
                
                if let returnedTotalPages = parsedResult!["pages"] as? Int {
                    pin.totalPages = returnedTotalPages
                    print("total pages: \(pin.totalPages)")
                }
                if let photosDictionaries = parsedResult!["photo"] as? [[String:AnyObject]]{
                    
                    _ = photosDictionaries.map(){(dictionary: [String: AnyObject]) -> Photo in
                        let photo = Photo(dictionary: dictionary, context: self.sharedContext)
                        print(photo.imageUrlString!)
                        
                        //assign relationship between Pin and Photo object
                        photo.dropPin = pin
                        CoreDataStackManager.sharedInstance().saveContext()
                        
                        self.taskForImage(photo.imageUrlString!, completionHandler: {(data, error) in
                            
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
    
    /* Helper function: Given a dictionary of parameters, convert to a string for a url */
    func escapedParameters(parameters: [String : AnyObject]) -> String {
        var urlVars = [String]()
        for (key, value) in parameters {
            /* Make sure that it is a string value */
            let stringValue = "\(value)"
            /* Escape it */
            let escapedValue = stringValue.stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.URLQueryAllowedCharacterSet())
            /* Append it */
            urlVars += [key + "=" + "\(escapedValue!)"]
        }
        return (!urlVars.isEmpty ? "?" : "") + urlVars.joinWithSeparator("&")
    }
    
    lazy var sharedContext: NSManagedObjectContext = {
        return CoreDataStackManager.sharedInstance().managedObjectContext
    }()
    
    func pathForIdentifier(identifier: String) -> String {
        let documentsDirectoryURL: NSURL = NSFileManager.defaultManager().URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask).first!
        let fullURL = documentsDirectoryURL.URLByAppendingPathComponent(identifier)
        
        return fullURL.path!
    }
    
    // MARK: - Shared Image Cache
    
    struct Caches {
        static let imageCache = ImageCache()
    }

}
