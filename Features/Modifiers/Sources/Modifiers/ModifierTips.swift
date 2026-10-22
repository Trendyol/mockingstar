import SwiftUI
import TipKit

struct ModifierResponseTip: Tip {
    var title: Text { Text("Edit one response field") }
    var message: Text? {
        Text("Run a preview to compare the original response on the left with the transformed response on the right. Right-click a key or value on the right: Edit in JavaScript changes that field; Copy Object Notation copies its enclosing object structure and path.")
    }
    var image: Image? { Image(systemName: "curlybraces") }
    var options: [TipOption] { MaxDisplayCount(1) }
}

struct ModifierJavaScriptTip: Tip {
    var title: Text { Text("Transform and preview") }
    var message: Text? {
        Text("Use chain.proceed(req) to get the response, change res.body, and return res. Run (⌘Return) tests your unsaved changes. Save (⌘S) persists the modifier. Metadata controls which requests match and the execution order.")
    }
    var image: Image? { Image(systemName: "play.fill") }
    var options: [TipOption] { MaxDisplayCount(1) }
}

struct ModifierPreviewRequestTip: Tip {
    var title: Text { Text("Choose the response source") }
    var message: Text? {
        Text("Mock uses the Sample Mock ID; Live calls the real API. Off disables this modifier for app traffic. Set the URL, method, headers, and body below, then Run to preview. Copy cURL copies this request.")
    }
    var image: Image? { Image(systemName: "network") }
    var options: [TipOption] { MaxDisplayCount(1) }
}
