import Foundation
struct ASRMetrics {
    var connectionMS:Double
    var queuedAtEndMS:Double
    var uploadTailMS:Double
    var serverFinalMS:Double
    var endToFinalMS:Double
    var previews:Int
}
final class BailianASR {
    var onPreview: ((String)->Void)?
    var onFinal: ((String,Double)->Void)?
    var onError: ((String)->Void)?
    var onMetrics: ((ASRMetrics)->Void)?
    private let manual:Bool
    private var startedAt=Date()
    private var readyAt:Date?
    private var finishAt:Date?
    private var audioBytes=0
    private var queuedAtEndMS=0.0
    private var previews=0
    init(manual:Bool=true) {self.manual=manual}
    private var socket: URLSessionWebSocketTask?
    private var session: URLSession?
    private var queue: [Data] = []
    private var sending = false
    private var ready = false
    private var ended = false
    private var cancelled = false
    private var finished = false
    private var endAt: Date?
    private var results: [String:String] = [:]
    private var order: [String] = []
    private var timer: Timer?
    func start(key: String,endpoint: String,model: String) {
        startedAt=Date()
        guard !key.isEmpty else { fail("请先配置百炼 API Key");return }
        guard var components=URLComponents(string:endpoint),components.scheme=="wss" else { fail("识别地址必须是 wss://");return }
        components.queryItems=[URLQueryItem(name:"model",value:model)]
        guard let url=components.url else {fail("识别地址无效");return}
        var request=URLRequest(url:url);request.timeoutInterval=10
        request.setValue("Bearer \(key)",forHTTPHeaderField:"Authorization")
        request.setValue("BrickMic/0.1",forHTTPHeaderField:"User-Agent")
        let config=URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest=15;config.timeoutIntervalForResource=90
        let session=URLSession(configuration:config);self.session=session
        socket=session.webSocketTask(with:request);socket?.resume();receive()
        timer=Timer.scheduledTimer(withTimeInterval:10,repeats:false){[weak self] _ in if self?.ready != true {self?.fail("百炼连接超时，请检查网络、Key 和模型")}}
    }
    private func send(_ value:[String:Any],completion:@escaping (Error?)->Void = {_ in}) {
        guard let socket=socket,!cancelled else{return}
        var object=value;object["event_id"]=UUID().uuidString
        guard let data=try? JSONSerialization.data(withJSONObject:object),let text=String(data:data,encoding:.utf8) else {fail("识别请求编码失败");return}
        socket.send(.string(text)){error in DispatchQueue.main.async {completion(error)}}
    }
    func append(_ pcm:Data) {
        guard !cancelled,!ended else{return}
        audioBytes+=pcm.count;queue.append(pcm)
        // At 20ms/frame, 150 frames are three seconds. Stop instead of growing without bound.
        if queue.count>150 {fail("网络上传过慢，本次输入已停止");return}
        pump()
    }
    func end() {
        guard !cancelled,!ended else{return}
        ended=true;endAt=Date();queuedAtEndMS=Double(queue.reduce(0){$0+$1.count})/32;pump()
        timer?.invalidate();timer=Timer.scheduledTimer(withTimeInterval:15,repeats:false){[weak self] _ in self?.fail("等待最终识别结果超时")}
    }
    private func pump() {
        guard ready,!sending,!cancelled else{return}
        if !queue.isEmpty {
            // Group up to 100ms of PCM while preserving WebSocket send order.
            let count=min(5,queue.count);var pcm=Data();for data in queue.prefix(count){pcm.append(data)};queue.removeFirst(count)
            sending=true
            send(["type":"input_audio_buffer.append","audio":pcm.base64EncodedString()]){[weak self] error in
                guard let self=self else{return};self.sending=false
                if error != nil {self.fail("百炼音频上传失败")} else {self.pump()}
            }
        } else if ended && !finished {
            finished=true
            if manual && audioBytes>0 {
                send(["type":"input_audio_buffer.commit"]){[weak self] error in
                    if error != nil {self?.fail("提交录音失败")} else {self?.finishSession()}
                }
            } else {finishSession()}
        }
    }
    private func finishSession() {
        finishAt=Date()
        send(["type":"session.finish"]){[weak self] error in if error != nil {self?.fail("结束识别失败")}}
    }
    private func receive() {
        socket?.receive{[weak self] result in DispatchQueue.main.async {
            guard let self=self,!self.cancelled else{return}
            switch result {
            case .failure: self.fail("百炼连接中断，请检查 Key、网络和模型")
            case .success(let message):
                let data:Data
                switch message {case .string(let text):data=Data(text.utf8);case .data(let bytes):data=bytes;@unknown default:return}
                if let object=(try? JSONSerialization.jsonObject(with:data)) as? [String:Any] {self.handle(object)}
                if !self.cancelled {self.receive()}
            }
        }}
    }
    private func handle(_ value:[String:Any]) {
        switch value["type"] as? String ?? "" {
        case "session.created":
            // A release determines the utterance boundary; no silence timer.
            let detection:Any=manual ? NSNull():["type":"server_vad","threshold":0.2,"silence_duration_ms":600]
            send(["type":"session.update","session":["input_audio_format":"pcm","sample_rate":16000,"input_audio_transcription":["language":"zh"],"turn_detection":detection]]){[weak self] error in if error != nil {self?.fail("识别初始化失败")}}
        case "session.updated":ready=true;readyAt=Date();if !ended {timer?.invalidate()};pump()
        case "conversation.item.input_audio_transcription.text":
            let text=(value["text"] as? String ?? "")+(value["stash"] as? String ?? "")
            previews+=1;onPreview?(order.compactMap{results[$0]}.joined()+text)
        case "conversation.item.input_audio_transcription.completed":
            let id=value["item_id"] as? String ?? UUID().uuidString
            if results[id]==nil {order.append(id)};results[id]=value["transcript"] as? String ?? ""
            onPreview?(order.compactMap{results[$0]}.joined())
        case "session.finished":
            let text=order.compactMap{results[$0]}.joined();let latency=endAt.map{Date().timeIntervalSince($0)*1000} ?? 0
            let now=Date()
            onMetrics?(ASRMetrics(connectionMS:readyAt.map{$0.timeIntervalSince(startedAt)*1000} ?? 0,
                queuedAtEndMS:queuedAtEndMS,uploadTailMS:finishAt.flatMap{finish in endAt.map{finish.timeIntervalSince($0)*1000}} ?? 0,
                serverFinalMS:finishAt.map{now.timeIntervalSince($0)*1000} ?? 0,endToFinalMS:latency,previews:previews))
            cancel();onFinal?(text,latency)
        case "error":
            // Do not log server request dumps or credentials.
            let code=(value["error"] as? [String:Any])?["code"] as? String ?? "unknown"
            fail("百炼识别失败（\(code)）")
        default:break
        }
    }
    func cancel() {cancelled=true;timer?.invalidate();queue.removeAll();socket?.cancel(with:.normalClosure,reason:nil);session?.invalidateAndCancel();socket=nil;session=nil}
    private func fail(_ message:String) {guard !cancelled else{return};cancel();onError?(message)}
}
