// Compile with:
//   swiftc minimal_browser.swift -o minimal_browser -framework Cocoa -framework WebKit
//
// Example usage:
//   ./minimal_browser --url "https://www.example.com" \
//                    --width 1024 --height 768 \
//                    --xpos 10 --ypos 10 \
//                    --maximized \
//                    --always-on-top \
//                    --fifo /tmp/minimal_browser_fifo \
//                    --debug
//
// After startup, you can use the terminal or write commands to the FIFO.
// For example:
//   echo "https://www.google.com" > /tmp/minimal_browser_fifo
//   echo "setpos 100 100" > /tmp/minimal_browser_fifo
//   echo "exit" > /tmp/minimal_browser_fifo

import Cocoa
import WebKit
import Darwin  // For mkfifo, open, unlink, etc.

// Debug mode flag
var debugMode = false

// Default parameters (overridden by command-line flags)
var startURL: String? = nil
var windowX: CGFloat = 100
var windowY: CGFloat = 100
var windowWidth: CGFloat = 800
var windowHeight: CGFloat = 600
var maximizeWindow = false
var alwaysOnTop = false      // Always-on-top flag
var fifoPath: String? = nil  // Path to FIFO, if specified

// Embedded HTML with usage instructions (including FIFO examples)
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
        h1 { color: #FFCC00; }
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
        ul { list-style-type: square; }
    </style>
</head>
<body>
    <h1>Welcome to Minimal Browser</h1>
    <p>This is a minimalist command-line browser with a simplified interface.</p>
    
    <h2>How to Use</h2>
    <p>You can start the browser with different parameters:</p>
    <pre><code>./minimal_browser 
    --url "https://www.example.com" --width 1024 
    --height 768 
    --xpos 10 
    --ypos 10 
    --maximized 
    --always-on-top 
    --fifo /tmp/minimal_browser_fifo 
    --debug</code></pre>
    
    <h2>Available Commands After Startup</h2>
    <ul>
        <li><code>exit</code> &mdash; Closes the application.</li>
        <li><code>http://</code> or <code>https://</code> &mdash; Navigates to the specified URL.</li>
        <li><code>file://</code> &mdash; Loads a local HTML file.</li>
        <li><code>setpos &lt;x&gt; &lt;y&gt;</code> &mdash; Moves the window to position (x, y).</li>
        <li><code>setsize &lt;width&gt; &lt;height&gt;</code> &mdash; Resizes the window.</li>
    </ul>
    
    <h2>Examples</h2>
    <pre><code>https://www.apple.com</code></pre>
    <pre><code>file:///Users/yourusername/Documents/example.html</code></pre>
    <pre><code>setpos 200 150</code></pre>
    <pre><code>setsize 1280 720</code></pre>
    
    <h2>Using FIFO</h2>
    <p>You can also control the browser by writing commands to a FIFO:</p>
    <pre><code>echo "https://www.google.com" > /tmp/minimal_browser_fifo</code></pre>
    <pre><code>echo "setpos 100 100" > /tmp/minimal_browser_fifo</code></pre>
    <pre><code>echo "exit" > /tmp/minimal_browser_fifo</code></pre>
    
    <p>For more information, refer to the documentation or contact the developer.</p>
</body>
</html>
"""

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    var webView: WKWebView!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Bring application to front
        NSApp.activate(ignoringOtherApps: true)
        
        // Create a borderless window
        window = NSWindow(
            contentRect: NSMakeRect(windowX, windowY, windowWidth, windowHeight),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window.title = "Minimal Browser"
        
        // Maximize window if requested
        if maximizeWindow, let screenFrame = NSScreen.main?.visibleFrame {
            window.setFrame(screenFrame, display: true)
        }
        
        // Set always-on-top if requested
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
        
        // Load URL if provided or display default HTML
        if let urlString = startURL, let url = URL(string: urlString) {
            if url.scheme == "file" {
                webView.loadFileURL(url, allowingReadAccessTo: url)
            } else {
                webView.load(URLRequest(url: url))
            }
        } else {
            webView.loadHTMLString(defaultHTML, baseURL: nil)
        }
        
        window.makeKeyAndOrderFront(nil)
        
        // Read commands from standard input
        DispatchQueue.global(qos: .background).async {
            while let command = readLine(strippingNewline: true) {
                DispatchQueue.main.async { [weak self] in
                    self?.handleCommand(command)
                }
            }
        }
        
        // Read commands from FIFO if specified
        if let fifo = fifoPath {
            DispatchQueue.global(qos: .background).async { [weak self] in
                // Open FIFO for reading and writing to avoid blocking on open
                let fd = open(fifo, O_RDWR)
                if fd == -1 {
                    if debugMode {
                        print("Error opening FIFO: \(String(cString: strerror(errno)))")
                    }
                    return
                }
                guard let file = fdopen(fd, "r") else {
                    if debugMode {
                        print("Error converting FIFO file descriptor to file pointer.")
                    }
                    close(fd)
                    return
                }
                var lineBuffer = [CChar](repeating: 0, count: 1024)
                while true {
                    if fgets(&lineBuffer, Int32(lineBuffer.count), file) != nil {
                        let command = String(cString: lineBuffer).trimmingCharacters(in: .whitespacesAndNewlines)
                        DispatchQueue.main.async {
                            self?.handleCommand(command)
                        }
                    } else {
                        // No data available, wait briefly and continue
                        clearerr(file)
                        usleep(100000) // sleep 0.1 seconds
                    }
                }
                fclose(file)
            }
        }
    }
    
    // Handle commands from stdin or FIFO
    func handleCommand(_ command: String) {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Exit command
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
        
        // Move window command: "setpos x y"
        if trimmed.lowercased().hasPrefix("setpos") {
            let parts = trimmed.split(separator: " ")
            if parts.count == 3,
               let x = Double(parts[1]),
               let y = Double(parts[2]) {
                let currentFrame = window.frame
                let newOrigin = NSPoint(x: CGFloat(x), y: CGFloat(y))
                window.setFrame(NSRect(origin: newOrigin, size: currentFrame.size), display: true)
                if debugMode {
                    print("Window moved to (\(x), \(y)).")
                }
            } else {
                if debugMode {
                    print("Invalid setpos format. Expected: setpos x y")
                }
            }
            return
        }
        
        // Resize window command: "setsize width height"
        if trimmed.lowercased().hasPrefix("setsize") {
            let parts = trimmed.split(separator: " ")
            if parts.count == 3,
               let w = Double(parts[1]),
               let h = Double(parts[2]) {
                let currentFrame = window.frame
                let newSize = NSSize(width: CGFloat(w), height: CGFloat(h))
                window.setFrame(NSRect(origin: currentFrame.origin, size: newSize), display: true)
                if debugMode {
                    print("Window resized to \(w)x\(h).")
                }
            } else {
                if debugMode {
                    print("Invalid setsize format. Expected: setsize width height")
                }
            }
            return
        }
    }
    
    // Remove FIFO file on termination
    func applicationWillTerminate(_ notification: Notification) {
        if let fifo = fifoPath {
            unlink(fifo)
            if debugMode {
                print("FIFO \(fifo) removed.")
            }
        }
    }
}

// Redirect stderr to /dev/null if debug is not enabled
func redirectStderrIfNeeded(debug: Bool) {
    if !debug {
        let devnull = fopen("/dev/null", "w")
        dup2(fileno(devnull), STDERR_FILENO)
    }
}

func helpStdout() {
    print("Usage: ./minimal_browser [options]")
    print("Options:")
    print("  --url <url>          Start URL (default: nil)")
    print("  --width <width>      Window width (default: 800)")
    print("  --height <height>    Window height (default: 600)")
    print("  --xpos <x>           Initial X position (default: 100)")
    print("  --ypos <y>           Initial Y position (default: 100)")
    print("  --maximized          Start maximized (default: false)")
    print("  --always-on-top      Keep window always on top (default: false)")
    print("  --fifo <path>        Path to FIFO for commands (default: nil)")
    print("  --debug              Enable debug mode (default: false)")
    print("  --help               Show this help message")
    print("Fifo examples:")
    print("  echo \"https://www.google.com\" > /tmp/minimal_browser_fifo")
    print("  echo \"file:///Users/yourusername/Documents/example.html\" > /tmp/minimal_browser_fifo")
    print("  echo \"setpos 100 100\" > /tmp/minimal_browser_fifo")
    print("  echo \"setsize 1280 720\" > /tmp/minimal_browser_fifo")
    print("  echo \"exit\" > /tmp/minimal_browser_fifo")

    exit(0)
}

// Parse command-line arguments
let args = CommandLine.arguments
var i = 1
while i < args.count {
    switch args[i] {
    case "--url":
        i += 1
        if i < args.count { startURL = args[i] }
    case "--width":
        i += 1
        if i < args.count, let w = Double(args[i]) { windowWidth = CGFloat(w) }
    case "--height":
        i += 1
        if i < args.count, let h = Double(args[i]) { windowHeight = CGFloat(h) }
    case "--xpos":
        i += 1
        if i < args.count, let x = Double(args[i]) { windowX = CGFloat(x) }
    case "--ypos":
        i += 1
        if i < args.count, let y = Double(args[i]) { windowY = CGFloat(y) }
    case "--maximized":
        maximizeWindow = true
    case "--always-on-top":
        alwaysOnTop = true
    case "--fifo":
        i += 1
        if i < args.count { fifoPath = args[i] }
    case "--help":
        helpStdout()
    case "--debug":
        debugMode = true
    default:
        print("Unknown argument: \(args[i])")
    }
    i += 1
}

// Create FIFO if specified
if let fifo = fifoPath {
    // Create FIFO with permissions 644; ignore error if it already exists
    if mkfifo(fifo, 0o644) != 0 && errno != EEXIST {
        print("Failed to create FIFO \(fifo): \(String(cString: strerror(errno)))")
    }
}

// Redirect stderr if needed
redirectStderrIfNeeded(debug: debugMode)

// Initialize and run the application
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()

