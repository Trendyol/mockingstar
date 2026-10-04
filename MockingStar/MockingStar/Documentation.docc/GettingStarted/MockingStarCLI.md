# 🛠️ Mocking Star CLI

Run CLI version of Mocking Star

@Metadata {
    @PageImage(
               purpose: icon, 
               source: "terminal_icon.png")
    @PageColor(gray)
}

You can use all operations independently of the UI with the Mocking Star CLI. Features such as listing and editing mocks are not available in the CLI version. CLI version is developed specifically for use in CI/CD pipelines. CLI version has **Linux** and **macOS** support.

**CLI Usage**
```
YusufOzgul@macOS Debug % ./MockingStar help start
OVERVIEW: Start mock server

USAGE: ./MockingStar start [--logs-folder <logs-folder>] [--port <port>] [--trace-export <trace-export>] <folder>

ARGUMENTS:
    <folder>                Mocks folder path

OPTIONS:
    -l, --logs-folder <logs-folder>
                            Logs folder
    -p, --port <port>       HTTP Server Port (default: 8008)
    -t, --trace-export <trace-export>
                            Export Mock Trace JSONL to this file or directory
    -h, --help              Show help information.
```

> Tip:
In CI/CD environment, you can prevent the use of unmocked data. 
This ensures that in the CI/CD environment, requests for unmocked data will not be sent to the real server. 
To achieve this, you need to add the header `disableLiveEnvironment=true` to your requests.

> Tip:
Mocking Star allows multiple applications to use the same mock folder. For example, if you are running your application with multiple instances/simulators/emulators, a single Mocking Star instance is sufficient.

> Tip:
Every request is written as a Mock Trace entry with URL, method, response type, and duration (seconds).
When `--logs-folder` is set, traces are exported to `MockingStarTrace.json` in that folder as JSON Lines.
Use `--trace-export` to write them to a different file or directory.

> Warning:
Linux CLI version does not support Plugins due to JavaScriptCore not available on Linux.

**CLI Mock Usage Analysis**
```
YusufOzgul@macOS Debug % ./MockingStar help analyze-usage
OVERVIEW: Analyze previous mock usage from logs file

USAGE: ./MockingStar analyze-usage [--logs-folder <logs-folder>]

OPTIONS:
    -l, --logs-folder <logs-folder>
                            Logs folder
    -h, --help              Show help information.
```
