# Meet Mocking Star Plugins

Mocking Star can be easily adapted to your requirements by defining your plugins. 

@Metadata {
    @PageImage(
               purpose: icon, 
               source: "plugin.png")
    @PageColor(blue)
}

Mocking Star offers plugins for key points such as requests to the original server, custom error responses, or providing useful information on the Mock Detail page. Plugins run in the embedded QuickJS runtime and exchange JSON-compatible values with the app.

## Plugin Types
@Links(visualStyle: list) {
    - <doc:PluginCommons>
    - <doc:LiveRequestUpdater>
    - <doc:MockDetail>
    - <doc:MockError>
    - <doc:RequestReloader>
}
