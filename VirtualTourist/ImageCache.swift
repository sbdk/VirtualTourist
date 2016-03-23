//
//  ImageCache.swift
//  VirtualTourist
//
//  Created by Li Yin on 3/16/16.
//  Copyright © 2016 Li Yin. All rights reserved.
//

import Foundation
import UIKit

class ImageCache {
    
    private var inMemoryCache = NSCache()
    
    // MARK: - Saving images
    func storeImageData(imageData: NSData?, withIdentifier identifier: String) {
        let path = pathForIdentifier(identifier)
        // If the image is nil, remove images from the cache
        if imageData == nil {
            inMemoryCache.removeObjectForKey(path)
            do {
                try NSFileManager.defaultManager().removeItemAtPath(path)
            } catch _ {}
            print("imageData removed from Memory and Disk")
            return
        }
        // Otherwise, keep the image in memory
        inMemoryCache.setObject(imageData!, forKey: path)
        
        // And in documents directory
        imageData!.writeToFile(path, atomically: true)
    }
    
    // MARK: - Retreiving images
    func imageDataWithIdentifier(identifier: String?) -> NSData? {
        
        // If the identifier is nil, or empty, return nil
        if identifier == nil || identifier! == "" {
            return nil
        }
        let path = pathForIdentifier(identifier!)

        // First try the memory cache
        if let data = inMemoryCache.objectForKey(path) as? NSData {
            return data
        }
        
        // Next Try the hard drive
        if let data = NSData(contentsOfFile: path) {
            return data
        }
        return nil
    }

    func pathForIdentifier(identifier: String) -> String {
        let documentsDirectoryURL: NSURL = NSFileManager.defaultManager().URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask).first!
        let fullURL = documentsDirectoryURL.URLByAppendingPathComponent(identifier)
        return fullURL.path!
    }
}