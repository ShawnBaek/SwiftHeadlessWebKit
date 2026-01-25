//
// WebKitGTK.h
// CWebKit
//
// Swift bindings for WebKitGTK - WebKit with GTK integration
//
// WebKitGTK is the GTK port of WebKit for Linux desktop applications.
// It provides the same WebKit engine as Safari but requires a display server.
//
// For headless operation, use one of:
// - xvfb-run (virtual framebuffer)
// - GDK_BACKEND=broadway (web-based display)
// - WPE WebKit (truly headless, see WPEWebKit.h)
//
// Installation:
//   Ubuntu/Debian: sudo apt-get install libwebkit2gtk-4.1-dev
//   Fedora: sudo dnf install webkit2gtk4.1-devel
//
// Reference:
// - https://webkitgtk.org/
// - https://github.com/WebKit/WebKit/tree/main/Source/WebKit/gtk
//

#ifndef CWebKit_WebKitGTK_h
#define CWebKit_WebKitGTK_h

#ifdef __has_include
    #if __has_include(<webkit2/webkit2.h>)
        #include <webkit2/webkit2.h>
        #include <gtk/gtk.h>
        #define CWEBKIT_HAS_GTK 1
    #else
        #define CWEBKIT_HAS_GTK 0
    #endif
#else
    #define CWEBKIT_HAS_GTK 0
#endif

#endif /* CWebKit_WebKitGTK_h */
