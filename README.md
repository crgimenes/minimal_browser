# Minimal Browser

A lightweight macOS browser controlled via terminal commands. This minimal browser is ideal for demo videos or any scenario where you need a clean, floating web window without the clutter of a full browser interface.

## Features

- Customizable window size and position via command-line parameters.
- Command-line parameters for quick configuration.
- Interactive control via terminal input or FIFO.
- Option to keep the window always on top.
- Default HTML with usage instructions when no URL is provided.
- FIFO support for external script control.

## Requirements

- macOS
- Swift (Swift 5+)
- Cocoa and WebKit frameworks (included with macOS)

## Compilation

Compile the program using the following command:

```bash
swiftc minimal_browser.swift -o minimal_browser -framework Cocoa -framework WebKit
```

## Usage

Run the program with your desired parameters. For example:

```bash
./minimal_browser \
    --url "https://www.example.com" \
    --width 1024 \
    --height 768 \
    --xpos 10 \
    --ypos 10 \
    --maximized \
    --always-on-top \
    --fifo /tmp/minimal_browser_fifo \
    --debug
```

### Command-Line Options

- `--url`
  URL to load on startup.

- `--width` and `--height`
  Set the window dimensions.

- `--xpos` and `--ypos`
  Set the window position.

- `--maximized`
  Maximize the window to fill the visible screen.

- `--always-on-top`
  Keep the window above all others.

- `--fifo`
  Specify a FIFO file for receiving external commands.

- `--debug`
  Enable debug mode.

### Interactive Commands

Once the program is running, you can control it interactively by typing commands in the terminal:

- **Navigate to a URL:**
  Type a URL starting with `http://` or `https://` (e.g., `https://www.apple.com`).

- **Load a local file:**
  Type a URL starting with `file://`.
  Requer full path to the file (e.g., `file:///Users/username/Documents/index.html`).

- **Move the window:**
  `setpos x y`
  (e.g., `setpos 200 150`)

- **Resize the window:**
  `setsize width height`
  (e.g., `setsize 1280 720`)

- **Exit the application:**
  `exit`

### FIFO Commands

If you specify a FIFO (e.g., `/tmp/minimal_browser_fifo`), you can also send commands from external scripts:

```bash
echo "https://www.google.com" > /tmp/minimal_browser_fifo
echo "setpos 100 100" > /tmp/minimal_browser_fifo
echo "exit" > /tmp/minimal_browser_fifo
```

The program automatically creates the FIFO when started and removes it upon exit.


