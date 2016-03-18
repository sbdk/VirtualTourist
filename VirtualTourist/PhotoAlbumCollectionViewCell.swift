//
//  PhotoAlbumCollectionViewCell.swift
//  VirtualTourist
//
//  Created by Li Yin on 3/14/16.
//  Copyright © 2016 Li Yin. All rights reserved.
//

import UIKit

class PhotoAlbumCollectionViewCell: UICollectionViewCell {
    
    @IBOutlet weak var photoImageView: UIImageView!
    
    var imageName: String = ""
    var taskToCancelifCellIsReused: NSURLSessionTask? {
        
        didSet {
            if let taskToCancel = oldValue {
                taskToCancel.cancel()
            }
        }
    }
}
