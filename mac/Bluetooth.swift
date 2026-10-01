import Foundation
import CoreBluetooth

final class BrickBluetooth:NSObject,CBCentralManagerDelegate,CBPeripheralDelegate {
    static let service=CBUUID(string:"BA1C0000-7E89-4C31-A2D0-4F923CB1A100")
    static let audio=CBUUID(string:"BA1C0001-7E89-4C31-A2D0-4F923CB1A100")
    static let control=CBUUID(string:"BA1C0002-7E89-4C31-A2D0-4F923CB1A100")
    var onState:((String)->Void)?
    var onMessage:((UInt8,Int,Int,Data)->Void)?
    var onDisconnect:(()->Void)?
    private var manager:CBCentralManager!
    private var peripheral:CBPeripheral?
    private var tx:CBCharacteristic?
    private var rx:CBCharacteristic?
    private let assembler=MicAssembler()
    private var writes:[Data]=[]
    private var writing=false
    private var stopped=false
    private var ready=false
    private var scanTimeout:DispatchWorkItem?
    private var retry:DispatchWorkItem?
    private var useCached=true
    private func stopDiscovery() {manager?.stopScan();scanTimeout?.cancel();scanTimeout=nil;retry?.cancel();retry=nil}
    private func find() {
        guard !stopped,manager.state == .poweredOn,peripheral==nil else{return}
        if useCached,let value=UserDefaults.standard.string(forKey:"brickPeripheral"),let id=UUID(uuidString:value),
           let known=manager.retrievePeripherals(withIdentifiers:[id]).first {
            stopDiscovery();peripheral=known;known.delegate=self
            onState?("正在等待上次的 Brick…");manager.connect(known,options:nil)
        } else {scan()}
    }
    func start() {
        stopped=false
        switch CBCentralManager.authorization {
        case .notDetermined:onState?("请确认 Brick Mic 的蓝牙授权")
        case .denied,.restricted:onState?("请在系统设置中允许 Brick Mic 使用蓝牙")
        default:onState?("正在连接 Brick…")
        }
        manager=CBCentralManager(delegate:self,queue:nil)
    }
    func reconnect() {stopped=false;useCached=false;if let p=peripheral {manager.cancelPeripheralConnection(p)} else {find()}}
    private func scan() {
        guard !stopped,manager.state == .poweredOn,peripheral==nil else{return}
        stopDiscovery();onState?("正在寻找 Brick…")
        manager.scanForPeripherals(withServices:CommandLine.arguments.contains("--scan-all") ? nil:[Self.service],options:[CBCentralManagerScanOptionAllowDuplicatesKey:false])
        let timeout=DispatchWorkItem{[weak self] in
            guard let self=self,self.peripheral==nil,!self.stopped else{return}
            self.manager.stopScan();self.onState?("等待 Brick · 暂停扫描")
            let again=DispatchWorkItem{[weak self] in self?.find()};self.retry=again
            DispatchQueue.main.asyncAfter(deadline:.now()+12,execute:again)
        }
        scanTimeout=timeout;DispatchQueue.main.asyncAfter(deadline:.now()+8,execute:timeout)
    }
    func centralManagerDidUpdateState(_ central:CBCentralManager) {
        switch central.state {case .poweredOn:find();case .unauthorized:onState?("请在系统设置中允许 Brick Mic 使用蓝牙");case .poweredOff:onState?("请打开 Mac 蓝牙");default:onState?("蓝牙暂不可用")}
    }
    func centralManager(_ central:CBCentralManager,didDiscover peripheral:CBPeripheral,advertisementData:[String:Any],rssi RSSI:NSNumber) {
        if CommandLine.arguments.contains("--scan-all") {print("discovered name=\(peripheral.name ?? "unnamed") services=\(advertisementData[CBAdvertisementDataServiceUUIDsKey] ?? []) rssi=\(RSSI)");fflush(stdout)}
        guard (advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] ?? []).contains(Self.service) else{return}
        guard self.peripheral==nil else{return};self.peripheral=peripheral;peripheral.delegate=self;stopDiscovery();onState?("正在连接 Brick…");central.connect(peripheral,options:nil)
    }
    func centralManager(_ central:CBCentralManager,didConnect peripheral:CBPeripheral) {peripheral.discoverServices([Self.service])}
    func centralManager(_ central:CBCentralManager,didFailToConnect peripheral:CBPeripheral,error:Error?) {useCached=false;disconnected()}
    func centralManager(_ central:CBCentralManager,didDisconnectPeripheral peripheral:CBPeripheral,error:Error?) {disconnected()}
    private func disconnected() {
        stopDiscovery();peripheral=nil;tx=nil;rx=nil;ready=false;writes.removeAll();writing=false;assembler.reset();onDisconnect?()
        if !stopped {let again=DispatchWorkItem{[weak self] in self?.find()};retry=again;DispatchQueue.main.asyncAfter(deadline:.now()+1,execute:again)}
    }
    func peripheral(_ peripheral:CBPeripheral,didDiscoverServices error:Error?) {
        guard error==nil else{onState?("读取蓝牙服务失败");manager.cancelPeripheralConnection(peripheral);return}
        for service in peripheral.services ?? [] where service.uuid==Self.service {peripheral.discoverCharacteristics([Self.audio,Self.control],for:service)}
    }
    func peripheral(_ peripheral:CBPeripheral,didDiscoverCharacteristicsFor service:CBService,error:Error?) {
        guard error==nil else{onState?("读取音频通道失败");manager.cancelPeripheralConnection(peripheral);return}
        for characteristic in service.characteristics ?? [] {if characteristic.uuid==Self.audio {rx=characteristic};if characteristic.uuid==Self.control {tx=characteristic}}
        if let rx=rx,tx != nil {peripheral.setNotifyValue(true,for:rx)}
    }
    func peripheral(_ peripheral:CBPeripheral,didUpdateNotificationStateFor characteristic:CBCharacteristic,error:Error?) {
        guard error==nil,characteristic.isNotifying else{onState?("无法订阅音频通道");manager.cancelPeripheralConnection(peripheral);return}
        // Without-response write size is the ATT payload capacity, unlike long writes.
        let packet=min(244,peripheral.maximumWriteValueLength(for:.withoutResponse))
        write(["op":"hello","packet":packet,"acks":true]);print("BLE notification payload=\(packet)")
    }
    func peripheral(_ peripheral:CBPeripheral,didWriteValueFor characteristic:CBCharacteristic,error:Error?) {
        writing=false
        if error != nil {onState?("蓝牙控制消息发送失败");manager.cancelPeripheralConnection(peripheral);return}
        if !ready {ready=true;useCached=true;UserDefaults.standard.set(peripheral.identifier.uuidString,forKey:"brickPeripheral");stopDiscovery();onState?("已连接 · 在 Brick 上按住 A 说话")}
        pump()
    }
    func peripheral(_ peripheral:CBPeripheral,didUpdateValueFor characteristic:CBCharacteristic,error:Error?) {
        guard error==nil,let value=characteristic.value else{return}
        do {if let m=try assembler.append(value) {onMessage?(m.kind,m.session,m.frame,m.data)}} catch {onState?("音频分片丢失，本次输入已取消");onDisconnect?()}
    }
    func write(_ object:[String:Any]) {
        guard tx != nil,let data=try? JSONSerialization.data(withJSONObject:object),data.count<=512 else{return}
        writes.append(data);pump()
    }
    private func pump() {guard !writing,!writes.isEmpty,let p=peripheral,let tx=tx else{return};writing=true;p.writeValue(writes.removeFirst(),for:tx,type:.withResponse)}
    func result(session:Int,text:String) {
        var chunk="";var chunks:[String]=[]
        // Character boundaries are preserved; packets stay below a 185-byte ATT MTU.
        for character in text {let c=String(character);if chunk.utf8.count+c.utf8.count>90 {chunks.append(chunk);chunk=""};chunk+=c}
        chunks.append(chunk)
        for (i,part) in chunks.enumerated() {write(["op":i==0 ? "result":"append","session":session,"text":part,"final":i==chunks.count-1])}
    }
    func stop() {stopped=true;stopDiscovery();if let p=peripheral {manager.cancelPeripheralConnection(p)}}
}
