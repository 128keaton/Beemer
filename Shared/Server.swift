//
//  Server.swift
//  Beemer-macOS
//
//  Created by Keaton Burleson on 4/26/21.
//

import Foundation
import Network

protocol ServerDelegate {
    func itemReceived(item: BeemItem?, error: Error?)
}

class Server {

    var delegate: ServerDelegate?

    private var listener: NWListener?
    private var currentConnection: NWConnection?

    init() {
        let udpOption = NWProtocolUDP.Options()
        let params = NWParameters(dtls: nil, udp: udpOption)
        params.includePeerToPeer = true

        self.listener = try! NWListener(using: params)

        self.listener?.service = NWListener.Service(name: "Yerba Buena",
            type: NetServiceType)

        self.listener?.stateUpdateHandler = { newState in
            switch newState {
            case .ready:
                if let port = self.listener?.port {
                    print("Listener active on port: \(port)")
                    // Listener setup on a port.  Active browsing for this service.
                }
            case .failed(let error):

                self.listener?.cancel()
                print("Listener - failed with %{public}@, restarting", error.localizedDescription)
                // Handle restarting listener
            default:
                break
            }
        }

        // Used for receiving a new connection for a service.
        // This is how the connection gets created and ultimately receives data from the browsing device.
        self.listener?.newConnectionHandler = { newConnection in
            // Send newConnection (NWConnection) back on a delegate to set it up for sending/receiving data

            print("New connection made: \(newConnection)")
            self.currentConnection = newConnection
            self.currentConnection?.stateUpdateHandler = { newState in


                switch newState {
                case .ready:
                    print("Connection established")
                    self.receiveData()
                case .preparing:
                    print("Connection preparing")
                case .setup:
                    print("Connection setup")
                case .waiting(let error):
                    print("Connection waiting: \(error.localizedDescription)")
                case .failed(let error):
                    print("Connection failed: \(error.localizedDescription)")
                    self.currentConnection?.cancel()
                default:
                    break
                }
            }
            self.currentConnection?.start(queue: .main)
        }

        // Start listening, and request updates on the main queue.
        self.listener?.start(queue: .main)
    }

    func receiveData() {
        print("Receive incoming data on connection")
        self.currentConnection?.receiveMessage(completion: { (data, context, isComplete, error) in
            if let err = error {
                print("Recieve error: \(err)")
                return
            }
            if let data = data {
         
                    NSKeyedUnarchiver.setClass(BeemItem.self, forClassName: "BeemItem")
                    if let beemItem = (try! NSKeyedUnarchiver.unarchivedObject(ofClass: BeemItem.self, from: data)) {
                        print("Item received: \(beemItem)")
                        self.delegate?.itemReceived(item: beemItem, error: nil)
                    }
               
            }
        })
    }
}
