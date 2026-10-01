import AppKit
import ApplicationServices

if CommandLine.arguments.contains("--import-key-stdin") {
    let key=(readLine() ?? "").trimmingCharacters(in:.whitespacesAndNewlines)
    guard key.hasPrefix("sk-"),key.count>10 else {fputs("No valid Bailian key supplied\n",stderr);exit(1)}
    guard MicCredentials.save(key) else {fputs("Environment configuration save failed\n",stderr);exit(1)}
    print("Bailian key saved to ~/.zshrc");exit(0)
}

if let argument=CommandLine.arguments.first(where:{$0.hasPrefix("--asr-benchmark=")}) {
    let path=String(argument.dropFirst("--asr-benchmark=".count))
    guard let pcm=try? Data(contentsOf:URL(fileURLWithPath:path)),!pcm.isEmpty,pcm.count%2==0 else {exit(2)}
    let manual = !CommandLine.arguments.contains("--vad")
    let recognizer=BailianASR(manual:manual)
    var done=false,success=false,offset=0
    var metrics:ASRMetrics?
    var feed:Timer?
    let began=Date()
    recognizer.onMetrics={metrics=$0}
    recognizer.onError={message in fputs(message+"\n",stderr);done=true}
    recognizer.onFinal={text,latency in
        var receipt:[String:Any]=["mode":manual ? "manual":"vad","audio_seconds":Double(pcm.count)/32000,
            "elapsed_seconds":Date().timeIntervalSince(began),"end_to_final_ms":latency,"text_characters":text.count]
        if let m=metrics {receipt["connection_ms"]=m.connectionMS;receipt["queued_at_end_ms"]=m.queuedAtEndMS;
            receipt["upload_tail_ms"]=m.uploadTailMS;receipt["server_final_ms"]=m.serverFinalMS;receipt["preview_events"]=m.previews}
        if let data=try? JSONSerialization.data(withJSONObject:receipt,options:[.prettyPrinted,.sortedKeys]),let output=String(data:data,encoding:.utf8){print(output)}
        done=true;success = !text.isEmpty
    }
    recognizer.start(key:MicCredentials.load(),endpoint:UserDefaults.standard.string(forKey:"asrEndpoint") ?? "wss://dashscope.aliyuncs.com/api-ws/v1/realtime",model:UserDefaults.standard.string(forKey:"asrModel") ?? "qwen3-asr-flash-realtime")
    feed=Timer.scheduledTimer(withTimeInterval:0.02,repeats:true){timer in
        if done {timer.invalidate();return}
        if offset<pcm.count {let end=min(offset+640,pcm.count);recognizer.append(pcm.subdata(in:offset..<end));offset=end}
        else {timer.invalidate();recognizer.end()}
    }
    while !done && Date().timeIntervalSince(began)<35 {RunLoop.current.run(until:Date().addingTimeInterval(0.02))}
    feed?.invalidate();recognizer.cancel();exit(success ? 0:1)
}

final class AppDelegate:NSObject,NSApplicationDelegate {
    let ble=BrickBluetooth()
    var asr:BailianASR?
    var statusItem:NSStatusItem!
    var window:NSWindow!
    var settingsWindow:NSWindow!
    let status=NSTextField(labelWithString:"正在启动…")
    let detail=NSTextField(labelWithString:"按住掌机 A 键说话，松开结束")
    let transcript=NSTextView()
    let meter=NSLevelIndicator()
    let key=NSSecureTextField()
    let model=NSTextField(string:UserDefaults.standard.string(forKey:"asrModel") ?? "qwen3-asr-flash-realtime")
    let endpoint=NSTextField(string:UserDefaults.standard.string(forKey:"asrEndpoint") ?? "wss://dashscope.aliyuncs.com/api-ws/v1/realtime")
    let automatic=NSButton(checkboxWithTitle:"自动输入",target:nil,action:nil)
    let permissionButton=NSButton(title:"开启输入权限",target:nil,action:nil)
    let connectionDot=ConnectionDot()
    let resultScroll=NSScrollView()
    let emptyIcon=NSImageView()
    let progress=NSProgressIndicator()
    let emptyTitle=NSTextField(labelWithString:"")
    let emptyHint=NSTextField(labelWithString:"")
    var emptyState:NSStackView!
    var activityRow:NSStackView!
    var permissionRow:NSStackView!
    var copyButton:NSButton!
    var statusMenu:NSMenu!
    var advanced:NSStackView!
    var advancedButton:NSButton!
    let keyHint=NSTextField(labelWithString:"")
    let permissionState=NSTextField(labelWithString:"")
    let saveFeedback=NSTextField(labelWithString:"")
    var settingsPermissionButton:NSButton!
    var inputTestButton:NSButton!
    var connected=false
    var preview:String? {CommandLine.arguments.first(where:{$0.hasPrefix("--ui-preview=")}).map{String($0.dropFirst(13))}}
    var currentSession=0
    var frames=0
    var samples=0
    var broken=false
    var startAt=Date()
    var targetPID:pid_t?
    var audioFile:FileHandle?
    var probeOut:String? {CommandLine.arguments.first(where:{$0.hasPrefix("--probe-out=")}).map{String($0.dropFirst(12))}}
    var probeOnly:Bool {probeOut != nil && !CommandLine.arguments.contains("--probe-asr")}
    var watchdog:Timer?
    var lastPCMAt=Date()
    var stopAt:Date?
    var asrMetrics:ASRMetrics?
    var releaseDelayMS=0.0
    var launched=false
    func applicationDidFinishLaunching(_ notification:Notification) {
        guard !launched else{return};launched=true
        NSApp.setActivationPolicy(.accessory)
        buildUI()
        key.stringValue=probeOnly || preview != nil ? "":MicCredentials.load()
        automatic.state=UserDefaults.standard.bool(forKey:"automaticInput") ? .on:.off
        refreshInputPermission();updateResult();updateKeyHint()
        if preview != nil {showPreview();return}
        ble.onState={[weak self] message in self?.connectionChanged(message)}
        ble.onDisconnect={[weak self] in
            guard let self=self else{return};self.connected=false
            self.abort(self.currentSession==0 ? "等待掌机连接":"连接断开 · 本次输入已取消")
        }
        ble.onMessage={[weak self] kind,sid,seq,data in self?.message(kind,sid,seq,data)}
        ble.start()
        watchdog=Timer.scheduledTimer(withTimeInterval:1,repeats:true){[weak self] _ in
            guard let self=self else{return}
            self.refreshInputPermission()
            if self.currentSession != 0 && self.stopAt==nil && Date().timeIntervalSince(self.lastPCMAt)>4 {self.abort("音频传输超时，本次输入已取消")}
        }
        if probeOut != nil {print("Brick Mic diagnostic receiver started");fflush(stdout)}
    }
    @objc func show(){window.makeKeyAndOrderFront(nil);NSApp.activate(ignoringOtherApps:true)}
    @objc func showSettings(){refreshInputPermission();settingsWindow.makeKeyAndOrderFront(nil);NSApp.activate(ignoringOtherApps:true)}
    @objc func quit(){ble.stop();asr?.cancel();NSApp.terminate(nil)}
    @objc func copyText(){
        guard !transcript.string.isEmpty else{return}
        NSPasteboard.general.clearContents();NSPasteboard.general.setString(transcript.string,forType:.string)
        copyButton.title="已复制"
        DispatchQueue.main.asyncAfter(deadline:.now()+1.5){[weak self] in self?.copyButton.title="复制文字"}
    }
    @objc func reconnect(){connected=false;abort("重新连接中…");if preview==nil {ble.reconnect()} else {setStatus("等待掌机连接")}}
    @objc func save(){
        guard let url=URL(string:endpoint.stringValue),url.scheme=="wss",url.host?.isEmpty==false,!model.stringValue.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty else{saveFeedback.textColor = .systemRed;saveFeedback.stringValue="请检查模型和 wss:// 服务地址";return}
        // Preview never reads or writes real credentials or preferences.
        if preview==nil {
            guard MicCredentials.save(key.stringValue.trimmingCharacters(in:.whitespacesAndNewlines)) else{saveFeedback.textColor = .systemRed;saveFeedback.stringValue="保存失败，请检查 Key 和文件权限";return}
            UserDefaults.standard.set(model.stringValue,forKey:"asrModel");UserDefaults.standard.set(endpoint.stringValue,forKey:"asrEndpoint")
        }
        updateKeyHint();updateResult();saveFeedback.textColor = .secondaryLabelColor;saveFeedback.stringValue="已保存"
    }
    func inputAllowed()->Bool {preview != nil ? (preview != "permission" && !CommandLine.arguments.contains("--missing-permission")):(AXIsProcessTrusted() && CGPreflightPostEventAccess())}
    func refreshInputPermission(){
        let allowed=inputAllowed()
        permissionRow.isHidden=automatic.state != .on || allowed
        permissionState.stringValue=allowed ? "已允许自动输入":"允许辅助功能权限后，可直接填入文本框"
        settingsPermissionButton.isHidden=allowed;inputTestButton.isEnabled=allowed;updateWindowMinimum()
    }
    @objc func toggleAuto(){
        if preview==nil {UserDefaults.standard.set(automatic.state == .on,forKey:"automaticInput")}
        refreshInputPermission();updateResult()
    }
    @objc func permissions(){
        guard preview==nil else{return}
        _ = AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String:true] as CFDictionary)
        if let url=URL(string:"x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {NSWorkspace.shared.open(url)}
        setStatus("请在辅助功能中允许 Brick Mic");saveFeedback.stringValue="请在系统设置中允许 Brick Mic"
    }
    @objc func testInput(){
        if preview != nil {saveFeedback.stringValue="预览模式不发送文字";return}
        guard currentSession==0 else{setStatus("请先结束当前录音");return}
        guard inputAllowed() else{permissions();return}
        setStatus("3 秒后输入，请点击目标文本框");saveFeedback.stringValue="请在 3 秒内点击目标文本框"
        DispatchQueue.main.asyncAfter(deadline:.now()+3){[weak self] in
            guard let self=self,self.currentSession==0 else{return}
            let pid=NSWorkspace.shared.frontmostApplication?.processIdentifier
            self.targetPID=pid == getpid() ? nil:pid
            self.insert("Brick Mic 输入测试");self.saveFeedback.stringValue="测试已结束"
        }
    }
    func setStatus(_ text:String){status.stringValue=text;statusItem.button?.toolTip=text;if probeOut != nil {print(text);fflush(stdout)}}
    func message(_ kind:UInt8,_ sid:Int,_ seq:Int,_ data:Data){
        switch kind {
        case 1:
            asr?.cancel();asr=nil;currentSession=sid;frames=0;samples=0;broken=false;startAt=Date();lastPCMAt=Date();stopAt=nil;asrMetrics=nil;releaseDelayMS=0
            transcript.string="";setStatus("正在听…");detail.stringValue="0.0 秒";setRecording(true)
            let pid=NSWorkspace.shared.frontmostApplication?.processIdentifier;targetPID=pid == getpid() ? nil:pid
            if let path=probeOut {FileManager.default.createFile(atPath:path,contents:nil);audioFile=FileHandle(forWritingAtPath:path)}
            if !probeOnly {
                let a=BailianASR();asr=a
                a.onMetrics={[weak self] metrics in guard self?.currentSession==sid else{return};self?.asrMetrics=metrics}
                a.onFinal={[weak self] text,latency in self?.complete(sid,text,latency)}
                a.onError={[weak self] error in guard self?.currentSession==sid else{return};self?.ble.write(["op":"error","session":sid,"text":error]);self?.abort(error)}
                a.start(key:key.stringValue,endpoint:endpoint.stringValue,model:model.stringValue)
            }
        case 2:
            guard currentSession==sid,!broken else{return}
            guard seq==frames else{abort("蓝牙丢失了音频帧，本次输入已取消");return}
            do {
                let pcm=try MicCodec.decode(data);frames+=1;samples+=pcm.count/2;lastPCMAt=Date()
                if frames%10==0 {ble.write(["op":"ack","session":sid,"frame":frames])}
                if let f=audioFile {try f.write(contentsOf:pcm)}
                asr?.append(pcm)
                let b=[UInt8](pcm);var energy=0.0
                for i in stride(from:0,to:b.count,by:2){let v=Double(Int16(bitPattern:UInt16(MicCodec.u16(b,i))));energy+=v*v}
                meter.doubleValue=min(1,sqrt(energy/Double(pcm.count/2))/7000)
                detail.stringValue=String(format:"%.1f 秒",Double(samples)/16000)
            }catch{abort("音频数据损坏，本次输入已取消")}
        case 3:
            guard currentSession==sid,!broken else{return}
            guard let end=(try? JSONSerialization.jsonObject(with:data)) as? [String:Any],end["frames"] as? Int==frames,end["samples"] as? Int==samples else{abort("音频未传完整，本次输入已取消");return}
            stopAt=Date();releaseDelayMS=end["release_to_end_ms"] as? Double ?? 0;meter.doubleValue=0;setStatus("正在整理文字…");setRecording(true);try? audioFile?.close();audioFile=nil
            if probeOnly {complete(sid,"蓝牙音频测试通过",0)} else {asr?.end()}
        case 4:if currentSession==sid {abort("本次输入已取消")}
        case 5:if currentSession==sid {abort(String(data:data,encoding:.utf8) ?? "Brick 录音失败")}
        default:break
        }
    }
    func complete(_ sid:Int,_ text:String,_ latency:Double){
        guard currentSession==sid,!broken else{return}
        currentSession=0;asr=nil;transcript.string=text;ble.result(session:sid,text:text)
        setRecording(false);transcript.scrollRangeToVisible(NSRange(location:0,length:0))
        let audioSeconds=Double(samples)/16000
        let transportMS=max(0,(stopAt?.timeIntervalSince(startAt) ?? audioSeconds)-audioSeconds)*1000

        if let m=asrMetrics {
            print(String(format:"mic_timing audio_seconds=%.3f receive_extra_ms=%.0f release_to_end_ms=%.0f connection_ms=%.0f upload_tail_ms=%.0f server_final_ms=%.0f",audioSeconds,transportMS,releaseDelayMS,m.connectionMS,m.uploadTailMS,m.serverFinalMS));fflush(stdout)
        }
        if !text.isEmpty,automatic.state == .on,probeOut==nil {insert(text)} else {setStatus(text.isEmpty ? "没有识别到语音":"识别完成")}
        if let path=probeOut {
            var receipt:[String:Any]=["frames":frames,"samples":samples,"audio_seconds":Double(samples)/16000,"elapsed_seconds":Date().timeIntervalSince(startAt),"receive_extra_ms":transportMS,"end_to_final_ms":latency,"release_to_end_ms":releaseDelayMS,"text":text,"complete":true]
            if let m=asrMetrics {receipt["connection_ms"]=m.connectionMS;receipt["upload_tail_ms"]=m.uploadTailMS;receipt["server_final_ms"]=m.serverFinalMS}
            if let data=try? JSONSerialization.data(withJSONObject:receipt,options:[.prettyPrinted,.sortedKeys]) {try? data.write(to:URL(fileURLWithPath:path+".json"))}
            print("PROBE_OK frames=\(frames) samples=\(samples)");fflush(stdout)
        }
    }
    func abort(_ message:String){
        if currentSession != 0 {ble.write(["op":"error","session":currentSession,"text":message])}
        currentSession=0;broken=true;asr?.cancel();asr=nil;try? audioFile?.close();audioFile=nil;meter.doubleValue=0
        setRecording(false);setStatus(message)
    }
    func insert(_ text:String){
        guard inputAllowed() else{refreshInputPermission();setStatus("文字已保留 · 请允许自动输入");return}
        guard let pid=targetPID,NSWorkspace.shared.frontmostApplication?.processIdentifier==pid else{setStatus("前台应用已变化 · 文字已保留，可复制");return}
        // Unicode events avoid replacing the user's clipboard. Split at Character boundaries.
        var chunk=""
        func post(){guard !chunk.isEmpty else{return};let utf16=Array(chunk.utf16)
            let source=CGEventSource(stateID:.privateState)
            guard let down=CGEvent(keyboardEventSource:source,virtualKey:0,keyDown:true),let up=CGEvent(keyboardEventSource:source,virtualKey:0,keyDown:false) else{return}
            down.flags=[];up.flags=[]
            down.keyboardSetUnicodeString(stringLength:utf16.count,unicodeString:utf16);up.keyboardSetUnicodeString(stringLength:utf16.count,unicodeString:utf16)
            down.postToPid(pid);up.postToPid(pid);chunk=""
        }
        for c in text {if chunk.utf16.count+String(c).utf16.count>20 {post()};chunk.append(c)};post();setStatus("已输入")
    }
    func showPreview(){
        automatic.state = .on;connected=true;refreshInputPermission();setStatus("掌机已连接")
        NSApp.appearance=NSAppearance(named:CommandLine.arguments.contains("--dark") ? .darkAqua:.aqua)
        switch preview {
        case "result":transcript.string="今天的想法先记下来。\n\n把掌机放在手边，按住 A 说话，松开后文字就能直接填入正在使用的应用。";setStatus("已输入")
        case "processing":currentSession=1;stopAt=Date();setStatus("正在整理文字…")
        case "recording":currentSession=1;detail.stringValue="8.6 秒";meter.doubleValue=0.45;setStatus("正在听…")
        case "permission":transcript.string="文字已经识别完成，可以先复制使用。";permissionRow.isHidden=false;setStatus("文字已保留 · 请允许自动输入")
        case "waiting":connected=false;setStatus("等待掌机连接")
        default:break
        }
        if preview=="result" && CommandLine.arguments.contains("--long-text") {transcript.string=Array(repeating:transcript.string,count:12).joined(separator:"\n\n")}
        setRecording(currentSession != 0);show()
        if preview=="settings" {showSettings()}
    }
    func applicationWillTerminate(_ notification:Notification){watchdog?.invalidate();asr?.cancel();ble.stop();try? audioFile?.close()}
}
let app=NSApplication.shared
let delegate=AppDelegate();app.delegate=delegate
// Direct CLI diagnostics do not receive Launch Services' normal launch event.
withExtendedLifetime(delegate) {
    if delegate.probeOut != nil || delegate.preview != nil {
        delegate.applicationDidFinishLaunching(Notification(name:NSApplication.didFinishLaunchingNotification))
    }
    app.run()
}
