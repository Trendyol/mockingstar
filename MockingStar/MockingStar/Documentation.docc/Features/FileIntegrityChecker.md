# File Integrity Checker

Validate and repair the integrity of your mock files with a single click.

@Metadata {
    @PageImage(
               purpose: icon, 
               source: "fileIntegrityChecker.png")
    @PageColor(purple)
}

## Overview

File Integrity Checker is a powerful utility that scans your Mocking Star mock files to identify potential integrity issues. It can detect problems such as improper file paths and duplicate IDs that could impact your mocking environment's stability and performance.

![File Integrity Checker interface](fileIntegrityChecker.png)

## Key Features

- **Automatic Detection**: Quickly scans and identifies mock files with integrity issues
- **Wrong Path Detection**: Finds mocks where the actual file path doesn't match the path stored in the mock
- **Duplicate ID Detection**: Identifies mock files that share the same ID, which can cause conflicts
- **One-Click Repair**: Automatically fixes all detected issues with a single button click
- **Real-time Status**: Provides immediate feedback about the scan results

## Understanding Integrity Issues

### Wrong File Paths

A "Wrong Path" violation occurs when a mock file's actual location doesn't match the path stored in the mock's metadata. This can happen when:

- Files are manually moved or copied
- Files are imported with incorrect paths
- The mock's internal paths are incorrectly modified

Unresolved path issues can cause Mocking Star to have difficulty finding and using the correct mock files during request matching.

### Duplicate IDs

A "Duplicate ID" violation occurs when two or more mock files share the same unique identifier. This can happen when:

- Mock files are copied without regenerating IDs
- Multiple files are imported with the same ID
- Mock files are manually edited with conflicting IDs

Duplicate IDs can lead to unpredictable behavior where Mocking Star may use the wrong mock file when responding to requests.

## Using File Integrity Checker

### Accessing the Tool

You can access the File Integrity Checker from the main menu:
1. Open the Mock List view
2. From the menu bar, select **Mocks → File Integrity Check**

### Running a Scan

When you open the File Integrity Checker, it automatically scans all mock files in the currently selected domain. During scanning, a progress indicator will be displayed.

### Interpreting Results

After scanning, the File Integrity Checker will display:

- A summary of detected issues grouped by type
- The number of issues found for each violation type
- A list of affected file paths for each violation type
- A "No Violation Found" message if all files pass the integrity check

### Fixing Violations

To automatically fix all detected issues:

1. Review the list of affected files
2. Click the **Fix Violations** button in the toolbar

The File Integrity Checker will:
- For wrong paths: Move files to their correct locations
- For duplicate IDs: Generate new unique IDs and update the mock files

## Tips and Best Practices

1. **Regular Checks**: Run the File Integrity Checker periodically, especially after importing or manually editing mock files

2. **Before Testing**: Perform an integrity check before important testing sessions to ensure your mocking environment is stable

3. **After Bulk Operations**: Run a check after performing bulk operations like importing multiple mocks or copying mock folders

4. **Review Before Fixing**: Review the list of affected files before clicking "Fix Violations" to understand the scope of changes

5. **Update References**: If you've referenced mock files in test scripts by ID, update these references after fixing duplicate ID violations

## Requirements

File Integrity Checker is available as part of the Mocking Star application. No additional setup is required. 