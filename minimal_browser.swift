// Compile with:
//   swiftc minimal_browser.swift -o minimal_browser -framework Cocoa -framework WebKit
//
// Example usage:
//   ./minimal_browser --url "https://www.example.com" \
//                    --width 1024 --height 768 \
//                    --xpos 10 --ypos 10 \
//                    --maximized \
//                    --always-on-top \
//                    --debug
//
// After starting, you can type commands in the terminal, for example:
//   https://www.apple.com  -> Navigates to this URL
//   file:///path/to/file   -> Navigates to a local file
//   setpos 100 100         -> Moves the window to position (100, 100)
//   setsize 640 480        -> Resizes the window to 640x480
//   exit                   -> Quits the application

import Cocoa
import WebKit

// Debug mode flag
var debugMode = false

// Default parameters (overridden by command-line flags)
var startURL: String? = nil
var windowX: CGFloat = 100
var windowY: CGFloat = 100
var windowWidth: CGFloat = 800
var windowHeight: CGFloat = 600
var maximizeWindow = false
var alwaysOnTop = false  // New parameter for always-on-top functionality

// Embedded HTML with usage instructions and dark theme
let defaultHTML = """
<!DOCTYPE html>
<html lang="en-US">
<head>
    <meta charset="UTF-8">
    <title>Minimal Browser - Instructions</title>
    <style>
        body {
            background-color: #2E2E2E;
            color: #FFFFFF;
            font-family: Arial, sans-serif;
            padding: 20px;
        }
        h1 {
            color: #FFCC00;
        }
        code {
            background-color: #3E3E3E;
            padding: 2px 4px;
            border-radius: 4px;
        }
        pre {
            background-color: #3E3E3E;
            padding: 10px;
            border-radius: 4px;
            overflow-x: auto;
        }
        ul {
            list-style-type: square;
        }
    </style>
</head>
<body>
    <h1>Welcome to Minimal Browser</h1>
    <p>This is a minimalist command-line browser with a simplified interface.</p>
    
    <h2>How to Use</h2>
    <p>You can start the browser with different parameters:</p>
    <pre><code>./minimal_browser --url "https://www.example.com" --width 1024 --height 768 --xpos 10 --ypos 10 --maximized --always-on-top --debug</code></pre>
    
    <h2>Available Commands After Startup</h2>
    <ul>
        <li><code>exit</code> &mdash; Closes the application.</li>
        <li><code>http://</code> or <code>https://</code> &mdash; Navigates to the specified URL.</li>
        <li><code>file://</code> &mdash; Loads a local HTML file.</li>
        <li><code>setpos &lt;x&gt; &lt;y&gt;</code> &mdash; Moves the window to position (x, y).</li>
        <li><code>setsize &lt;width&gt; &lt;height&gt;</code> &mdash; Resizes the window to the specified width and height.</li>
    </ul>
    
    <h2>Examples</h2>
    <pre><code>https://www.apple.com</code></pre>
    <pre><code>file:///Users/yourusername/Documents/example.html</code></pre>
    <pre><code>setpos 200 150</code></pre>
    <pre><code>setsize 1280 720</code></pre>
    
    <p>For more information, refer to the documentation or contact the developer.</p>
</body>
</html>
"""

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    var webView: WKWebView!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Activate the application to bring the window to the front
        NSApp.activate(ignoringOtherApps: true)
        
        // Create a borderless window
        window = NSWindow(
            contentRect: NSMakeRect(windowX, windowY, windowWidth, windowHeight),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        
        // Set title for system reference
        window.title = "Minimal Browser"

        // If --maximized is set, occupy the entire visible screen
        if maximizeWindow, let screenFrame = NSScreen.main?.visibleFrame {
            window.setFrame(screenFrame, display: true)
        }
        
        // If --always-on-top is set, keep the window above others
        if alwaysOnTop {
            window.level = .floating
            if debugMode {
                print("Always-on-top mode enabled.")
            }
        }

        // Create WebView
        webView = WKWebView(frame: window.contentView!.bounds)
        webView.autoresizingMask = [.width, .height]
        window.contentView?.addSubview(webView)

        // Load the specified URL or the default HTML if no URL is provided
        if let urlString = startURL, let url = URL(string: urlString) {
            if url.scheme == "file" {
                webView.loadFileURL(url, allowingReadAccessTo: url)
            } else {
                webView.load(URLRequest(url: url))
            }
        } else {
            // Load the embedded HTML
            webView.loadHTMLString(defaultHTML, baseURL: nil)
        }

        // Show the window
        window.makeKeyAndOrderFront(nil)

        // Start reading commands from stdin on a background thread
        DispatchQueue.global(qos: .background).async {
            while let command = readLine(strippingNewline: true) {
                DispatchQueue.main.async { [weak self] in
                    self?.handleCommand(command)
                }
            }
        }
    }

    // Handles commands from stdin
    func handleCommand(_ command: String) {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Command to exit the application
        if trimmed.lowercased() == "exit" {
            NSApplication.shared.terminate(nil)
            return
        }
        
        // Navigate to HTTP/S URL
        if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") {
            if let url = URL(string: trimmed) {
                webView.load(URLRequest(url: url))
            }
            return
        }
        
        // Navigate to a local file
        if trimmed.hasPrefix("file://") {
            if let url = URL(string: trimmed) {
                webView.loadFileURL(url, allowingReadAccessTo: url)
            }
            return
        }

        // Command to move the window: "setpos x y"
        if trimmed.lowercased().hasPrefix("setpos") {
            let parts = trimmed.split(separator: " ")
            // Expect "setpos x y"
            if parts.count == 3,
               let x = Double(parts[1]),
               let y = Double(parts[2]) {
                let currentFrame = window.frame
                let newOrigin = NSPoint(x: CGFloat(x), y: CGFloat(y))
                let newFrame = NSRect(origin: newOrigin, size: currentFrame.size)
                window.setFrame(newFrame, display: true)
                
                if debugMode {
                    print("Window moved to (\(x), \(y)).")
                }
            } else {
                if debugMode {
                    print("Invalid setpos command format. Expected: setpos x y")
                }
            }
            return
        }
        
        // Command to resize the window: "setsize w h"
        if trimmed.lowercased().hasPrefix("setsize") {
            let parts = trimmed.split(separator: " ")
            // Expect "setsize width height"
            if parts.count == 3,
               let w = Double(parts[1]),
               let h = Double(parts[2]) {
                let currentFrame = window.frame
                let newSize = NSSize(width: CGFloat(w), height: CGFloat(h))
                let newFrame = NSRect(origin: currentFrame.origin, size: newSize)
                window.setFrame(newFrame, display: true)
                
                if debugMode {
                    print("Window resized to \(w)x\(h).")
                }
            } else {
                if debugMode {
                    print("Invalid setsize command format. Expected: setsize width height")
                }
            }
            return
        }
    }
}

// Function to redirect stderr to /dev/null if not in debug mode
func redirectStderrIfNeeded(debug: Bool) {
    if !debug {
        let devnull = fopen("/dev/null", "w")
        dup2(fileno(devnull), STDERR_FILENO)
    }
}

// Parse command-line arguments
let args = CommandLine.arguments
var i = 1
while i < args.count {
    switch args[i] {
    case "--url":
        i += 1
        if i < args.count {
            startURL = args[i]
        }
    case "--width":
        i += 1
        if i < args.count, let w = Double(args[i]) {
            windowWidth = CGFloat(w)
        }
    case "--height":
        i += 1
        if i < args.count, let h = Double(args[i]) {
            windowHeight = CGFloat(h)
        }
    case "--xpos":
        i += 1
        if i < args.count, let x = Double(args[i]) {
            windowX = CGFloat(x)
        }
    case "--ypos":
        i += 1
        if i < args.count, let y = Double(args[i]) {
            windowY = CGFloat(y)
        }
    case "--maximized":
        maximizeWindow = true
    case "--always-on-top":
        alwaysOnTop = true  // Handle the new parameter
    case "--debug":
        debugMode = true
    default:
        print("Unknown argument: \(args[i])")
    }
    i += 1
}

// Redirect stderr if not in debug mode
redirectStderrIfNeeded(debug: debugMode)

// Initialize and run the application
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()

