# Mocking Star Trace

Easily monitor and debug network requests in real-time with Mocking Star Trace.

@Metadata {
    @PageImage(
               purpose: icon, 
               source: "mockingStarTrace.png")
    @PageColor(blue)
}

## Overview

Mocking Star Trace provides a real-time view of all network requests processed by Mocking Star, allowing you to monitor, debug, and analyze your application's network activity without interfering with your workflow.

![Mocking Star Trace overlay window](mockingStarTrace.png)

## Key Features

- **Real-time Request Monitoring**: View all network requests as they happen
- **Request Status Indicators**: Quickly identify mocked, live, and error responses with color coding
- **URL Display**: See the full request URL for each network call
- **Floating Mode**: Keep the trace window visible while you work in other windows
- **Timestamp Display**: Each request is timestamped for easier debugging
- **Log Clearing**: Easily clear all logs when needed

## Using Mocking Star Trace

### Opening the Trace Window

Open the Mocking Star Trace overlay window using the keyboard shortcut:

```
Command + T
```

Alternatively, you can open it from the Window menu.

### Understanding the Interface

The trace window displays the following information for each request:

- **Timestamp**: When the request was made
- **Status Badge**: Color-coded response type
  - 🔵 Blue: Live request
  - 🟢 Green: Mock response served
  - 🔴 Red: Error occurred
- **URL**: The full request URL

### Request Status Types

Mocking Star Trace shows different status types with color coding:

- **live request**: Request was sent to the real endpoint
- **scenario not found and live request**: No matching scenario found, fallback to live request
- **ignored domain and live request**: Domain is configured to be ignored, fallback to live request
- **mock**: Response was served from a mock
- **error**: An error occurred during the request
- **no mock and disabled live request**: No mock found and live requests are disabled
- **scenario not found and disabled live request**: No matching scenario found and live requests are disabled

### Floating View Mode

Toggle the "Floating View" button to keep the trace window visible on top of other windows. This is especially useful when debugging and you need to see the network activity while working in other applications.

### Clearing Logs

Use the "Clear Logs" button to clear all current trace logs when you want to start with a clean slate.

## Tips and Best Practices

1. **Keep Trace Window Open During Development**: Always have the trace window open during development to catch any unexpected network behavior.

2. **Use Floating Mode During Debugging**: Enable floating mode when debugging complex issues to keep network activity visible while switching between applications.

3. **Clear Logs Before Testing New Scenarios**: Clear logs before starting new test scenarios to avoid confusion with previous activity.

4. **Monitor Response Types**: Pay attention to the color-coded response types to ensure your mocking configuration is working as expected.

5. **Look for Patterns**: Watch for patterns in your application's network activity to identify optimization opportunities.

## Requirements

Mocking Star Trace is available as part of the Mocking Star application. No additional setup is required. 