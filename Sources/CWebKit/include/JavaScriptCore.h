//
// JavaScriptCore.h
// CWebKit
//
// Swift bindings for JavaScriptCore - WebKit's JavaScript engine
//
// JavaScriptCore is the same JavaScript engine used by:
// - Safari on macOS/iOS
// - WKWebView on Apple platforms
// - WebKitGTK and WPE WebKit on Linux
//
// This ensures consistent JavaScript execution across all platforms.
//
// Reference: https://github.com/WebKit/WebKit/tree/main/Source/JavaScriptCore
//

#ifndef CWebKit_JavaScriptCore_h
#define CWebKit_JavaScriptCore_h

#ifdef __has_include
    #if __has_include(<JavaScriptCore/JavaScript.h>)
        #include <JavaScriptCore/JavaScript.h>
        #define CWEBKIT_HAS_JAVASCRIPTCORE 1
    #elif __has_include(<jsc/jsc.h>)
        // GLib-based JavaScriptCore (Linux)
        #include <jsc/jsc.h>
        #define CWEBKIT_HAS_JAVASCRIPTCORE 1
    #else
        #define CWEBKIT_HAS_JAVASCRIPTCORE 0
    #endif
#else
    #define CWEBKIT_HAS_JAVASCRIPTCORE 0
#endif

#endif /* CWebKit_JavaScriptCore_h */
