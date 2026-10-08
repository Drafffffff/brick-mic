import Foundation

// The runner compiles the full production Bluetooth state machine against these
// doubles. No real BLE, device preferences, microphone or GUI is accessed.
let fixtureSuite="brick-mic-pairing-fixture-"+UUID().uuidString
let fixtureDefaults=UserDefaults(suiteName:fixtureSuite)!
protocol CBCentralManagerDelegate:AnyObject {}
protocol CBPeripheralDelegate:AnyObject {}
struct CBUUID:Equatable {let value:String;init(string:String){value=string}}
enum CBManagerState {case poweredOn,poweredOff,unauthorized,unknown}
enum CBManagerAuthorization {case notDetermined,denied,restricted,allowedAlways}
enum CBCharacteristicWriteType {case withoutResponse,withResponse}
let CBCentralManagerScanOptionAllowDuplicatesKey="duplicates"
let CBAdvertisementDataServiceUUIDsKey="services"
final class CBCentralManager {
    static var authorization=CBManagerAuthorization.allowedAlways
    static var latest:CBCentralManager!
    var state=CBManagerState.poweredOn
    var scanning=false
    var connections=[UUID](),cancellations=[UUID]()
    var available=[UUID:CBPeripheral]()
    init(delegate:CBCentralManagerDelegate,queue:DispatchQueue?){Self.latest=self}
    func scanForPeripherals(withServices:[CBUUID]?,options:[String:Any]?){scanning=true}
    func stopScan(){scanning=false}
    func retrievePeripherals(withIdentifiers ids:[UUID])->[CBPeripheral]{ids.compactMap{available[$0]}}
    func connect(_ p:CBPeripheral,options:[String:Any]?){connections.append(p.identifier)}
    func cancelPeripheralConnection(_ p:CBPeripheral){cancellations.append(p.identifier)}
}
final class CBCharacteristic {
    let uuid:CBUUID
    var isNotifying=true
    var value:Data?
    init(_ uuid:CBUUID){self.uuid=uuid}
}
final class CBService {
    let uuid:CBUUID
    var characteristics:[CBCharacteristic]?
    init(_ uuid:CBUUID,characteristics:[CBCharacteristic]){self.uuid=uuid;self.characteristics=characteristics}
}
final class CBPeripheral {
    let identifier=UUID()
    var name:String?
    weak var delegate:CBPeripheralDelegate?
    var services:[CBService]?
    var writes=[Data]()
    init(_ name:String){self.name=name}
    func discoverServices(_ ids:[CBUUID]){}
    func discoverCharacteristics(_ ids:[CBUUID],for service:CBService){}
    func setNotifyValue(_ value:Bool,for c:CBCharacteristic){}
    func maximumWriteValueLength(for type:CBCharacteristicWriteType)->Int{185}
    func writeValue(_ data:Data,for c:CBCharacteristic,type:CBCharacteristicWriteType){writes.append(data)}
}

// INJECT_PRODUCTION_BLUETOOTH

func advertise(_ b:BrickBluetooth,_ p:CBPeripheral){
    b.centralManager(CBCentralManager.latest,didDiscover:p,advertisementData:[CBAdvertisementDataServiceUUIDsKey:[BrickBluetooth.service]],rssi:0)
}
@discardableResult func subscribe(_ b:BrickBluetooth,_ p:CBPeripheral)->CBCharacteristic {
    let audio=CBCharacteristic(BrickBluetooth.audio),control=CBCharacteristic(BrickBluetooth.control)
    let service=CBService(BrickBluetooth.service,characteristics:[audio,control])
    p.services=[service]
    b.peripheral(p,didDiscoverCharacteristicsFor:service,error:nil)
    b.peripheral(p,didUpdateNotificationStateFor:audio,error:nil)
    return control
}
func hello(_ p:CBPeripheral)->[String:Any]{(try! JSONSerialization.jsonObject(with:p.writes.last!)) as! [String:Any]}

@main enum BluetoothPairingHarness {
    static func main(){
        defer{fixtureDefaults.removePersistentDomain(forName:fixtureSuite)}
        let old=CBPeripheral("Brick"),new=CBPeripheral("Brick"),third=CBPeripheral("Other Brick")
        fixtureDefaults.set(old.identifier.uuidString,forKey:"brickPeripheral")
        fixtureDefaults.set(old.identifier.uuidString,forKey:"controlPeer")
        fixtureDefaults.set(true,forKey:"controlPeerMigrated")
        let b=BrickBluetooth();b.start();let manager=CBCentralManager.latest!
        advertise(b,new)
        precondition(manager.connections.isEmpty,"Normal reconnect must not silently connect to another Brick")
        advertise(b,old);let oldTX=subscribe(b,old)
        b.peripheral(old,didWriteValueFor:oldTX,error:nil)
        precondition(b.controlsAllowed && b.deviceID==old.identifier.uuidString)

        var candidates=[UUID]()
        b.onReplacementCandidates={rows,_ in candidates=rows.map{$0.id}}
        precondition(b.beginReplacementSearch())
        advertise(b,new);advertise(b,third)
        precondition(Set(candidates)==Set([new.identifier,third.identifier]))
        precondition(manager.connections==[old.identifier] && manager.cancellations.isEmpty,"Browsing must preserve current connection")
        precondition(!b.selectReplacement(UUID()),"Only a discovered, explicitly selected device is accepted")
        b.cancelReplacementSearch()
        precondition(!manager.scanning && b.deviceID==old.identifier.uuidString && b.controlsAllowed)
        precondition(fixtureDefaults.string(forKey:"brickPeripheral")==old.identifier.uuidString)

        precondition(b.beginReplacementSearch());advertise(b,new)
        precondition(b.selectReplacement(new.identifier))
        precondition(manager.cancellations==[old.identifier])
        precondition(fixtureDefaults.string(forKey:"brickPeripheral")==old.identifier.uuidString,"Selection alone must not persist an unconfirmed pair")
        b.centralManager(manager,didDisconnectPeripheral:old,error:nil)
        precondition(b.deviceID==new.identifier.uuidString && manager.connections.last==new.identifier)
        let newTX=subscribe(b,new)
        precondition(!b.controlsAllowed && hello(new)["remote"] as? Bool==false,"Old device editing trust must never transfer")
        b.peripheral(old,didWriteValueFor:oldTX,error:nil)
        b.centralManager(manager,didDisconnectPeripheral:old,error:nil)
        precondition(b.deviceID==new.identifier.uuidString && fixtureDefaults.string(forKey:"brickPeripheral")==old.identifier.uuidString,"Late old callbacks must not commit or disconnect the new pair")
        b.peripheral(new,didWriteValueFor:newTX,error:NSError(domain:"fixture",code:1))
        precondition(fixtureDefaults.string(forKey:"brickPeripheral")==old.identifier.uuidString,"A rejected hello must preserve the old saved pair")
        b.centralManager(manager,didDisconnectPeripheral:new,error:nil)
        advertise(b,third);precondition(b.deviceID==nil,"A retry stays restricted to the explicitly selected replacement")
        advertise(b,new);let retryTX=subscribe(b,new)
        b.peripheral(new,didWriteValueFor:retryTX,error:nil)
        precondition(fixtureDefaults.string(forKey:"brickPeripheral")==new.identifier.uuidString && !b.controlsAllowed)
        precondition(fixtureDefaults.string(forKey:"controlPeer")==old.identifier.uuidString)

        b.trustCurrent(true)
        b.centralManager(manager,didDisconnectPeripheral:new,error:nil)
        advertise(b,new);let trustedTX=subscribe(b,new)
        precondition(b.controlsAllowed && hello(new)["remote"] as? Bool==true)
        b.peripheral(new,didWriteValueFor:trustedTX,error:nil)
        b.stop()
        let restarted=BrickBluetooth();restarted.start();let restoredManager=CBCentralManager.latest!
        restoredManager.available[new.identifier]=new
        restarted.centralManagerDidUpdateState(restoredManager)
        precondition(restoredManager.connections==[new.identifier],"Restart must retrieve the newly saved Brick")
        let restoredTX=subscribe(restarted,new)
        restarted.peripheral(new,didWriteValueFor:restoredTX,error:nil)
        precondition(restarted.beginReplacementSearch());advertise(restarted,third)
        restarted.centralManager(restoredManager,didDisconnectPeripheral:new,error:nil)
        precondition(restoredManager.scanning,"Losing the old connection while browsing must not terminate replacement discovery")
        restarted.cancelReplacementSearch()
        precondition(restoredManager.connections.last==new.identifier && fixtureDefaults.string(forKey:"brickPeripheral")==new.identifier.uuidString)
        restoredManager.state = .poweredOff
        precondition(!restarted.beginReplacementSearch())
        restarted.stop()
        print("PASS: pinned reconnect, explicit discovery/selection, cancel preservation, failed hello rollback, stale callback isolation, per-device edit trust and restart persistence")
    }
}
