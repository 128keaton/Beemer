//
//  Browser.swift
//  Beemer
//
//  Created by Keaton Burleson on 4/26/21.
//

import Foundation
import Network

protocol BrowserDelegate {
    func devicesChanged(devices: [NWBrowser.Result])
    func connectionReady()
    func dataSent(error: Error?)
}

class Browser: NSObject, NetServiceBrowserDelegate {

    var delegate: BrowserDelegate?

    private var devices: [NetService] = []

    private var nwBrowser: NWBrowser?

    private var currentConnection: NWConnection?

    override init() {
        super.init()

        let params = NWParameters()
        params.includePeerToPeer = true

        self.nwBrowser = NWBrowser(for: .bonjour(type: NetServiceType,
            domain: "local"), using: params)

        self.nwBrowser?.stateUpdateHandler = { newState in
            switch newState {
            case .failed(let error):
                self.nwBrowser!.cancel()
                // Handle restarting browser
                print("Browser - failed with %{public}@, restarting", error.localizedDescription)
            case .ready:
                print("Browser - ready")
            case .setup:
                print("Browser - setup")
            default:
                break
            }
        }

        // Used to browse for discovered endpoints.
        self.nwBrowser?.browseResultsChangedHandler = { results, changes in
            self.delegate?.devicesChanged(devices: results.map({ (r) -> NWBrowser.Result in
                print(r)
                return r
            }))
        }

        self.nwBrowser?.start(queue: .main)

    }


    func establishConnection(with nwEndpoint: NWEndpoint) {
        self.currentConnection = NWConnection(to: nwEndpoint, using: NWParameters(passcode: "abc123"))
        self.currentConnection?.stateUpdateHandler = { newState in

            switch newState {
            case .ready:
                print("Connection established")
                self.delegate?.connectionReady()
            case .preparing:
                print("Connection preparing")
            case .setup:
                print("Connection setup")
            case .waiting(let error):
                print("Connection waiting: %{public}@", error.localizedDescription)
            case .failed(let error):
                print("Connection failed: %{public}@", error.localizedDescription)

                // Cancel the connection upon a failure.
                self.currentConnection?.cancel()
                self.currentConnection = nil
                // Notify your delegate that the connection failed with an error message.
            default:
                break
            }
        }

        self.currentConnection?.start(queue: .main)

    }

    func send(item: BeemItem) {
        NSKeyedArchiver.setClassName("BeemItem", for: BeemItem.self)
        let beemItemData = try! NSKeyedArchiver.archivedData(withRootObject: item, requiringSecureCoding: false)

        self.currentConnection?.send(content: beemItemData, completion: NWConnection.SendCompletion.contentProcessed(({ (error) in
            print(error ?? "No error")
            self.delegate?.dataSent(error: error)
        })))

    }
    
    func stop() {
        self.currentConnection?.cancel()
        self.currentConnection = nil
    }
}

