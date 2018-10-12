//: Playground - noun: a place where people can play
Welcome to the blekit wiki!

//
//  BLE Singleton Test
//
//  Created by Joyal Serrao on 12/10/18.


import CoreBluetooth

@objc protocol BLEDelegate {
    func bleDidUpdateState(state: String?)
    func bleDidConnectToPeripheral()
    func bleDidDisconenctFromPeripheral()
    func bleDidReceiveData(data: Data?)
}

class BLEKit: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    
    let RBL_SERVICE_UUID = "713D0000-503E-4C75-BA94-3148F18D941E"
    let RBL_CHAR_TX_UUID = "713D0002-503E-4C75-BA94-3148F18D941E"
    let RBL_CHAR_RX_UUID = "713D0003-503E-4C75-BA94-3148F18D941E"
    
    var delegate: BLEDelegate?
    
    private var centralManager: CBCentralManager!
    private var activePeripheral: CBPeripheral?
    private var characteristics = [String: CBCharacteristic]()
    private var data: NSMutableData?
    private(set) var peripherals = [CBPeripheral]()
    private var RSSICompletionHandler: ((NSNumber?, Error?) -> ())?
    var scanedDevice: ((_ result: [CBPeripheral]) -> ())? //an optional function
    var isReconnect: Bool!
    
    
    
    
    override init() {
        super.init()
        self.centralManager = CBCentralManager(delegate: self, queue: nil)
        self.data = NSMutableData()
        isReconnect = true
    }
    
    
    
    @objc private func scanTimeout() {
        
        print("[DEBUG] Scanning stopped")
        self.centralManager.stopScan()
        scanedDevice!(peripherals)// call back
        
    }
    
    // MARK: Public methods
    func startScanning(timeout: Double) -> Bool {
        
        if self.centralManager.state != .poweredOn {
            
            print("[ERROR] Couldn´t start scanning")
            return false
        }
        
        print("[DEBUG] Scanning started")
        
        // CBCentralManagerScanOptionAllowDuplicatesKey
        
        //you're good to go on calling centralManager methods
        
        
        Timer.scheduledTimer(timeInterval: timeout, target: self, selector: #selector(BLEKit.scanTimeout), userInfo: nil, repeats: false)
        
        let services: [CBUUID] = [CBUUID(string: RBL_SERVICE_UUID)]
        self.centralManager.scanForPeripherals(withServices: services, options: nil)
        
        return true
        
    }
    
    func connectToPeripheral(peripheral: CBPeripheral) -> Bool {
        
        if self.centralManager.state != .poweredOn {
            
            print("[ERROR] Couldn´t connect to peripheral")
            return false
        }
        
        print("[DEBUG] Connecting to peripheral: \(peripheral.identifier.uuidString)")
        
        
        self.centralManager.connect(peripheral, options: [CBConnectPeripheralOptionNotifyOnDisconnectionKey: NSNumber(value: true)])
        
        return true
    }
    
    func read() {
        
        guard let char = self.characteristics[RBL_CHAR_TX_UUID] else { return }
        
        self.activePeripheral?.readValue(for: char)
    }
    
    func write(data: Data) {
        guard let char = self.characteristics[RBL_CHAR_RX_UUID] else { return }
        self.activePeripheral?.delegate = self
        self.activePeripheral?.writeValue(data as Data, for: char, type: .withResponse)
        
        
        
    }
    
    
    func enableNotifications(enable: Bool) {
        
        guard let char = self.characteristics[RBL_CHAR_TX_UUID] else { return }
        
        self.activePeripheral?.setNotifyValue(enable, for: char)
        
    }
    func readRSSI(completion: @escaping (_ RSSI: NSNumber?, _ error: Error?) -> ()) {
        
        self.RSSICompletionHandler = completion
        self.activePeripheral?.readRSSI()
    }
    
    // MARK: CBCentralManager delegate
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        
        
        switch central.state {
        case .unknown:
            print("[DEBUG] Central manager state: Unknown")
            self.delegate?.bleDidUpdateState(state: "unknown")
            break
            
        case .resetting:
            print("[DEBUG] Central manager state: Resseting")
            self.delegate?.bleDidUpdateState(state: "resetting")
            
            
            break
            
        case .unsupported:
            print("[DEBUG] Central manager state: Unsopported")
            self.delegate?.bleDidUpdateState(state: "unsupported")
            
            break
            
        case .unauthorized:
            print("[DEBUG] Central manager state: Unauthorized")
            self.delegate?.bleDidUpdateState(state: "unauthorized")
            
            
            break
            
        case .poweredOff:
            print("[DEBUG] Central manager state: Powered off")
            self.delegate?.bleDidUpdateState(state: "poweredOff")
            break
            
        case .poweredOn:
            print("[DEBUG] Central manager state: Powered on")
            self.delegate?.bleDidUpdateState(state: "poweredOn")
            
            break
        }
        
    }
    
    
    func centralManager(_ central: CBCentralManager,
                        didFailToConnect peripheral: CBPeripheral,
                        error: Error?) {
        print("[ERROR] Could not connecto to peripheral \(peripheral.identifier.uuidString) error: \(error!.localizedDescription)")
    }
    
    
    internal func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        
        print("[DEBUG] Find peripheral: \(String(describing: peripheral.name)) RSSI: \(RSSI)")
        
        
        let index = peripherals.index { $0.identifier.uuidString == peripheral.identifier.uuidString }
        
        if let index = index {
            peripherals[index] = peripheral
        } else {
            peripherals.append(peripheral)
        }
        
        scanedDevice!(peripherals)// call back
        
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("[DEBUG] Connected to peripheral \(peripheral.identifier.uuidString)")
        
        self.activePeripheral = peripheral
        
        self.activePeripheral?.delegate = self
        self.activePeripheral?.discoverServices([CBUUID(string: RBL_SERVICE_UUID)])
        
        self.delegate?.bleDidConnectToPeripheral()
        
        UserSession.connectedUUID(uuid: peripheral.identifier.uuidString)
        self.isReconnect = true
        
    }
    
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        
        var text = "[DEBUG] Disconnected from peripheral: \(peripheral.identifier.uuidString)"
        
        if error != nil {
            text += ". Error: \(error!.localizedDescription)"
        }
        
        print(text)
        self.delegate?.bleDidDisconenctFromPeripheral()
        
        if isReconnect {
            // if it is true i will reconnect
            central.connect(peripheral, options: nil)
        } else {
            self.activePeripheral?.delegate = nil
            self.activePeripheral = nil
            self.characteristics.removeAll(keepingCapacity: false)
        }
        
        
    }
    
    
    
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        
        
        if error != nil {
            print("[ERROR] Error discovering services. \(error!.localizedDescription)")
            return
        }
        
        print("[DEBUG] Found services for peripheral: \(peripheral.identifier.uuidString)")
        
        
        for service in peripheral.services! {
            let theCharacteristicsUIUID = [CBUUID(string: RBL_CHAR_RX_UUID), CBUUID(string: RBL_CHAR_TX_UUID)]
            peripheral.discoverCharacteristics(theCharacteristicsUIUID, for: service)
        }
        
        
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if error != nil {
            print("[ERROR] Error discovering characteristics. \(error!.localizedDescription)")
            return
        }
        
        print("[DEBUG] Found characteristics for peripheral: \(peripheral.identifier.uuidString)")
        
        for characteristic in service.characteristics! {
            self.characteristics[characteristic.uuid.uuidString] = characteristic
        }
        
        enableNotifications(enable: true)
    }
    
    
    // to know data recevice from ble
    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        
        print("the recive \(characteristics)")
        
        if error != nil {
            
            print("[ERROR] Error updating value. \(String(describing: error))")
            return
        }
        
        if characteristic.uuid.uuidString == RBL_CHAR_TX_UUID {
            
            self.delegate?.bleDidReceiveData(data: characteristic.value!)
        }
        
    }
    
    
    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateValueFor descriptor: CBDescriptor,
                    error: Error?) {
        
        
    }
    // extra method
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if ((error) != nil) {
            print("Error changing notification state: \(String(describing: error?.localizedDescription))")
        }
        
        // Notification has started
        if (characteristic.isNotifying) {
            print("Notification began on: \(characteristic)")
        }
    }
    
    
    
    func peripheral(_ peripheral: CBPeripheral,
                    didReadRSSI RSSI: NSNumber,
                    error: Error?) {
        self.RSSICompletionHandler?(RSSI, error)
        self.RSSICompletionHandler = nil
    }
    
    
    
    func disConnect() {
        
        if activePeripheral != nil {
            self.centralManager.cancelPeripheralConnection(activePeripheral!)
            self.isReconnect = false
            
        }
    }
    
    func autoConnect() {
        
        let uuidString = UserSession.getUserUUID()
        
        guard uuidString.count > 1 else {
            print("Scan")
            return
        }
        
        let uuid = UUID.init(uuidString: uuidString)
        let listOfPeripherals: [CBPeripheral] =
            self.centralManager.retrievePeripherals(withIdentifiers: [uuid!])
        if listOfPeripherals.count > 0 {
            let peripheral: CBPeripheral = listOfPeripherals.first!
            
            if peripheral.state == .disconnected {
                DispatchQueue.global().async {
                    peripheral.delegate = self
                    self.activePeripheral = peripheral
                    _ = self.connectToPeripheral(peripheral: peripheral)
                }
                
                
            }
            
        }
        
    }
    
}






