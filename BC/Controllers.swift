//
//  Bluetooth.swift
//  BC
//
//  Created by Khrob Edmonds on 2/26/21.
//

import GameController

class Game_Controller
{
    var controllers:[GCController] = []
    
    init()
    {
        NotificationCenter.default.addObserver(self, selector: #selector(connect_controller),    name: .GCControllerDidConnect,    object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(disconnect_controller), name: .GCControllerDidDisconnect, object: nil)
    }
    
    deinit
    {
        NotificationCenter.default.removeObserver(self, name: .GCControllerDidConnect,    object: nil)
        NotificationCenter.default.removeObserver(self, name: .GCControllerDidDisconnect, object: nil)
    }

    @objc func connect_controller (notification: Notification)
    {
        print(#function)
        let cc = GCController.controllers()
        for c in cc {
            
            c.microGamepad?.valueChangedHandler = {
                (gamepad:GCMicroGamepad, _) in
                print (gamepad.allButtons)
                print ()
            }
            
            print (c.extendedGamepad ?? "No extended gamepad")
            
            controllers.append(c)
        }
    }
    
    @objc func disconnect_controller (notification: Notification)
    {
        print(#function)
        let c = notification.object as! GCController
        print("Controllers before removal:")
        print(controllers)
        if let index = controllers.firstIndex(of: c) { controllers.remove(at: index) }
        print("Controllers after removal:")
        print(controllers)
    }
}
