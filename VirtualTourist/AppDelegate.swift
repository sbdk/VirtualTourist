//
//  AppDelegate.swift
//  VirtualTourist
//
//  Created by Li Yin on 3/11/16.
//  Copyright © 2016 Li Yin. All rights reserved.
//

import UIKit
import CoreData

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
        CoreDataStackManager.sharedInstance().managedObjectBackgroundContext.parentContext = CoreDataStackManager.sharedInstance().managedObjectMainContext
        return true
    }

    func applicationWillTerminate(application: UIApplication) {
        CoreDataStackManager.sharedInstance().saveContext()
    }
}

