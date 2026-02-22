//
// WPEWebKit.h
// CWebKit
//
// Swift bindings for WPE WebKit - Headless WebKit for Linux
//
// WPE (Web Platform for Embedded) is the official headless port of WebKit,
// designed for embedded systems and server-side rendering without a display.
//
// Key features:
// - Full WebKit rendering engine
// - JavaScript execution via JavaScriptCore
// - No display server required
// - Ideal for web scraping and automation
//
// Installation:
//   Ubuntu/Debian: sudo apt-get install libwpewebkit-1.1-dev
//   Fedora: sudo dnf install wpewebkit-devel
//
// Reference:
// - https://wpewebkit.org/
// - https://github.com/WebKit/WebKit/tree/main/Source/WebKit/WPE
//

#ifndef CWebKit_WPEWebKit_h
#define CWebKit_WPEWebKit_h

#ifdef __has_include
    #if __has_include(<wpe/webkit.h>)
        #include <wpe/webkit.h>
        #define CWEBKIT_HAS_WPE 1
    #elif __has_include(<wpewebkit-1.1/wpe/webkit.h>)
        // Versioned path
        #include <wpewebkit-1.1/wpe/webkit.h>
        #define CWEBKIT_HAS_WPE 1
    #elif __has_include(<wpe-webkit-1.1/wpe/webkit.h>)
        // Alternative naming
        #include <wpe-webkit-1.1/wpe/webkit.h>
        #define CWEBKIT_HAS_WPE 1
    #else
        #define CWEBKIT_HAS_WPE 0
    #endif
#else
    #define CWEBKIT_HAS_WPE 0
#endif

// GLib is required for WPE WebKit
#ifdef __has_include
    #if __has_include(<glib.h>)
        #include <glib.h>
        #include <gio/gio.h>
    #endif
#endif

#endif /* CWebKit_WPEWebKit_h */
