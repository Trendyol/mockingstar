# Mock Import

Easily import network requests using cURL commands or raw JSON files.

@Metadata {
    @PageImage(
               purpose: icon, 
               source: "mockImport.png")
    @PageColor(green)
}

## Overview

Mock Import provides a convenient way to add new mocks to your Mocking Star project without having to manually create them. You can import network requests using cURL commands copied from your browser's dev tools or by directly pasting exported mock JSON files.

![Mock Import interface](mockImport.png)

## Key Features

- **cURL Command Import**: Convert cURL commands directly into Mocking Star mocks
- **JSON File Import**: Import previously exported Mocking Star mock files
- **Multi-format Support**: Flexible import options for different workflows
- **Instant Validation**: Immediate feedback on import success or failure
- **Current Domain Integration**: All imports are automatically added to the currently selected mock domain

## Using Mock Import

### Opening the Import Interface

You can access the Mock Import interface from the mock list view by clicking the "Import" button in the toolbar.

### Importing with cURL

1. **Copy a cURL Command**: From your browser's network tab, right-click on a request and select "Copy as cURL"
2. **Select cURL Mode**: Choose the "cURL" tab in the import interface
3. **Paste the Command**: Paste the copied cURL command into the text area
4. **Click Import**: Mocking Star will process the command and create a new mock

The cURL importer supports various command options including:
- Custom HTTP methods (`-X`, `--request`)
- Header fields (`-H`, `--header`)
- Request data (`-d`, `--data`, `--data-raw`)
- URLs (as arguments or with `--url`)

### Importing from JSON File

1. **Select File Mode**: Choose the "File" tab in the import interface
2. **Paste JSON Content**: Paste the content of a previously exported Mocking Star mock file
3. **Click Import**: Mocking Star will validate and import the mock file

### Understanding Import Errors

If an import fails, Mocking Star will display an error message explaining the issue:

- **URL Error**: The cURL command doesn't contain a valid URL
- **Already Mocked**: The request is already mocked in the current domain
- **Domain Ignored**: The domain in the request is configured to be ignored
- **JSON Parse Error**: The file content doesn't contain valid mock data

## Tips and Best Practices

1. **Use for Complex Requests**: Import is particularly useful for requests with complex headers or payloads

2. **Keep Original cURL**: Save your original cURL commands for future reference or modifications

3. **Check Domain Selection**: Ensure you've selected the correct mock domain before importing

4. **Import Related Requests Together**: When working with related endpoints, import them together to maintain consistency

5. **Edit After Import**: After importing, you can still edit the mock details as needed

## Example cURL Commands

```
curl -X GET "https://api.example.com/users/123" -H "Authorization: Bearer token123"
```

```
curl -X POST "https://api.example.com/products" -H "Content-Type: application/json" --data-raw '{"name":"New Product","price":29.99}'
```

## Requirements

Mock Import is available as part of the Mocking Star application. No additional setup is required. 