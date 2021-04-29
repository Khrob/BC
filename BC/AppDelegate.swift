//
//  AppDelegate.swift
//  BC
//
//  Created by Khrob Edmonds on 12/31/20.
//

import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate
{
    func applicationDidFinishLaunching(_ aNotification: Notification)
    {
        NotificationCenter.default.addObserver(self, selector: #selector(close_app), name: NSWindow.willCloseNotification, object: nil)
    }

    func applicationWillTerminate(_ aNotification: Notification)
    {
        // Insert code here to tear down your application
    }
    
    @objc func close_app ()
    {
        NSApp.terminate(self)
    }
}

