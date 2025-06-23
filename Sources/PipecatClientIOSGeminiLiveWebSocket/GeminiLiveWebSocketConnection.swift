import Foundation
import PipecatClientIOS

protocol GeminiLiveWebSocketConnectionDelegate: AnyObject {
    func connectionDidFinishModelSetup(
        _: GeminiLiveWebSocketConnection
    )
    func connection(
        _: GeminiLiveWebSocketConnection,
        didReceiveModelAudioBytes audioBytes: Data
    )
    func connectionDidDetectUserInterruption(_: GeminiLiveWebSocketConnection)
}

class GeminiLiveWebSocketConnection: NSObject, URLSessionWebSocketDelegate {
    
    // MARK: - Public
    
    struct Options {
        let apiKey: String
        let initialMessages: [WebSocketMessages.Outbound.TextInput]
        let generationConfig: Value?
    }
    
    public weak var delegate: GeminiLiveWebSocketConnectionDelegate? = nil
    
    init(options: Options) {
        self.options = options
    }
    
    func connect() async throws {
        guard socket == nil else {
            assertionFailure()
            return
        }
        
        // Create web socket
        let urlSession = URLSession(
            configuration: .default,
            delegate: self,
            delegateQueue: OperationQueue()
        )
        let host = "preprod-generativelanguage.googleapis.com"
        let url = URL(string: "wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent?key=\(options.apiKey)")
        let socket = urlSession.webSocketTask(with: url!)
        self.socket = socket
        
        // Connect
        // NOTE: at this point no need to wait for socket to open to start sending events
        socket.resume()
        
        // Send initial setup message
        let model = "models/gemini-2.5-flash-preview-native-audio-dialog" // TODO: make this configurable someday
        try await sendMessage(
            message: WebSocketMessages.Outbound.Setup(
                model: model,
                generationConfig: options.generationConfig
                systemInstruction: """
"## 1. الشخصية والسلوك
                                                   - **اللغة**: استخدم دائماً **العربية الفصحى**، بصوتٍ موازنٍ ورصينٍ ومهنيٍّ.
                                                   - **النبرة**: رسمية، مهذبة، محدودة النطاق، دون الانحراف إلى مواضيع خارج إطار خدمات ما بعد البيع أو استعلامات المنتجات.
                                                   - **الردود القصيرة والواضحة**: أجب بإيجاز وبتركيز على المطلوب فقط، مع تجنب الحشو أو المصطلحات الدعائية.

                                                   ## 2. نطاق العمل
                                                   يساعدك هذا النظام في:
                                                   - **تسجيل الأجهزة**: مسح رمز الاستجابة السريعة (QR)، إدخال البيانات يدوياً.
                                                   - **متابعة الطلبات**: جدولة الصيانة أو التركيب، عرض حالة الطلبات الجارية.
                                                   - **طلب الخدمات**: تنظيف، فحص أداء، إصلاح، تعبئة غاز التبريد.
                                                   - **فحص الجودة بعد الخدمة**: عرض نموذج تقييم وطرح أسئلة محددة (كم نسبة الرضا عن الوقت، جودة العمل…).
                                                   - **دعم عام**: استفسارات حول الضمان، الدليل الرقمي، برنامج الولاء.
                                                   - **استرجاع بيانات المستخدم**: العمر، الجنس، الأجهزة المثبتة والمشتراة، الطلبات الجارية.

                                                   لا تخوض في أي موضوعات خارج هذه القائمة.

                                                   ## 3. إدارة الوظائف (Function Calling)
                                                   - عند الحاجة لاستدعاء واجهة برمجة تطبيقات (API) أو تنفيذ وظيفة داخلية مثل:
                                                     - `scan_qr_code()`
                                                     - `get_user_profile(age, gender, devices, active_requests)`
                                                     - `schedule_service(product_id, service_type, datetime_slot)`
                                                     - `submit_quality_check(request_id, ratings, comments)`
                                                     - `query_loyalty_points(user_id)`
                                                     - `send_notification(channel, message)`

                                                     اتبع السياسة التالية:
                                                     - **أقل فترة بين الدعوات**: لا تستدعي أي دالة أكثر من مرة كل 5 ثوانٍ (`tool_cooldown: 5s`).
                                                     - **التأكد من المعطيات**: اسأل المستخدم إذا كان هناك نقص في البيانات المطلوبة قبل الاستدعاء.
                                                     - **معالجة الأخطاء**: إذا فشلت أي دالة، أعلم المستخدم باللغة العربية الفصحى بلطف وقدم خيار المحاولة مجدداً أو التواصل مع مركز الدعم.

                                                   ## 4. سلوك التفاعل وتفاصيل البيانات
                                                   - **استرجاع بيانات المستخدم** قبل أي تفاعل: العمر (`age`)، الجنس (`gender`)، الأجهزة المثبتة والمشتراة (`devices`)، والطلبات النشطة (`active_requests`).
                                                   - **تقديم ملخص**: عند استدعاء API، اعرض للمستخدم نبذة موجزة (مثال: “لديك حالياً طلب تركيب واحد مجدول غداً الساعة 10:00 صباحاً”).
                                                   - **الخصوصية**: لا تعرض معلومات شخصية حساسة أو تتجاوز صلاحياتك، ولا تخزن بيانات جديدة من خارج نطاق وظائفك.

                                                   ## 5. تحسين تجربة المستخدم
                                                   - **التوضيح الذكي**: إذا طلب المستخدم خدمة غير واضحة، قدّم خيارات محددة (مثلاً: “هل ترغب في طلب خدمة تنظيف أم إصلاح؟”).
                                                   - **الاستخدام الأمثل للوظائف الصوتية**: ادعم الاستماع لأوامر متعددة في جملة واحدة (“برجاء حجز صيانة للثلاجة يوم الخميس صباحاً وعلمني برقم الطلب”).
                                                   - **التثبيت والتعلم المستمر**: اعلم المستخدم بإمكان تعديل البيانات عبر “تعديل ملفي الشخصي” أو “تحديث الأجهزة”.

                                                   ## 6. قواعد إضافية
                                                   - **لا تستخدم كلمة “elevate”.**
                                                   - **حافظ على الخصوصية والأمان**: أبلغ المستخدم بإجراءات الأمان عند التعامل مع كلمة المرور أو تأكيد الهوية.
                                                   - **لا تنشأ محادثات جانبية**: كل رد يجب أن يكون مرتبطًا بالخدمات والوظائف المعرفة فقط.

"""
            )
        )
        try Task.checkCancellation()
        
        // Send initial context messages
        for message in options.initialMessages {
            try await sendMessage(message: message)
            try Task.checkCancellation()
        }
        
        // Listen for server messages
        Task {
            while true {
                do {
                    let decoder = JSONDecoder()
                    
                    let message = try await socket.receive()
                    try Task.checkCancellation()
                    
                    switch message {
                    case .data(let data):
//                        print("received server message: \(String(data: data, encoding: .utf8)?.prefix(50))")
                        
                        // Check for setup complete message
                        let setupCompleteMessage = try? decoder.decode(
                            WebSocketMessages.Inbound.SetupComplete.self,
                            from: data
                        )
                        if let setupCompleteMessage {
                            delegate?.connectionDidFinishModelSetup(self)
                            continue
                        }
                        
                        // Check for audio output message
                        let audioOutputMessage = try? decoder.decode(
                            WebSocketMessages.Inbound.AudioOutput.self,
                            from: data
                        )
                        if let audioOutputMessage, let audioBytes = audioOutputMessage.audioBytes() {
                            delegate?.connection(
                                self,
                                didReceiveModelAudioBytes: audioBytes
                            )
                        }
                        
                        // Check for interrupted message
                        let interruptedMessage = try? decoder.decode(
                            WebSocketMessages.Inbound.Interrupted.self,
                            from: data
                        )
                        if let interruptedMessage {
                            delegate?.connectionDidDetectUserInterruption(self)
                            continue
                        }
                        continue
                    case .string(let string):
                        Logger.shared.warn("Received server message of unexpected type: \(string)")
                        continue
                    }
                } catch {
                    // Socket is known to be closed (set to nil), so break out of the socket receive loop
                    if self.socket == nil {
                        break
                    }
                    // Otherwise wait a smidge and loop again
                    try? await Task.sleep(nanoseconds: 250_000_000)
                }
            }
        }
        
        // We finished all the connect() steps
        didFinishConnect = true
    }
    
    func sendUserAudio(_ audio: Data) async throws {
        // Only send user audio once the connect() steps (which includes model setup) have finished
        if !didFinishConnect {
            return
        }
        try await sendMessage(
            message: WebSocketMessages.Outbound.AudioInput(audio: audio)
        )
    }
    
    func sendMessage(message: Encodable) async throws {
        let encoder = JSONEncoder()
        
        let messageString = try! String(
            data: encoder.encode(message),
            encoding: .utf8
        )!
//        print("sending message: \(messageString.prefix(50))")
        try await socket?.send(.string(messageString))
    }
    
    func disconnect() {
        // This will trigger urlSession(_:webSocketTask:didCloseWith:reason:), where we will nil out socket and thus cause the socket receive loop to end
        socket?.cancel(with: .normalClosure, reason: nil)
    }
    
    func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didOpenWithProtocol protocol: String?
    ) {
//        print("web socket opened!")
    }
    
    func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
        reason: Data?
    ) {
//        print("web socket closed! close code \(closeCode)")
        socket = nil
        didFinishConnect = false
    }
    
    // MARK: - Private
    
    private let options: GeminiLiveWebSocketConnection.Options
    private var socket: URLSessionWebSocketTask?
    private var didFinishConnect = false
}
