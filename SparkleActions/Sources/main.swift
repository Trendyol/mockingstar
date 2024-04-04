import Foundation
import Ink

print("Sparkle Actions...")
print("Checking Variables")

guard let version = ProcessInfo.processInfo.environment["RELEASE_VERSION"] else { exit(1) }
guard let buildNumber = ProcessInfo.processInfo.environment["BUILD_NUMBER"] else { exit(1) }
guard let versionTag = ProcessInfo.processInfo.environment["RELEASE_VERSION_TAG"] else { exit(1) }
guard let releaseNotes = ProcessInfo.processInfo.environment["RELEASE_NOTES"] else { exit(1) }
guard let minimumVersion = ProcessInfo.processInfo.environment["MinimumVersion"] else { exit(1) }
guard let signature = ProcessInfo.processInfo.environment["Signature"] else { exit(1) }

let appcastFileURL = URL(fileURLWithPath: "Appcast.xml")

guard var appcastFile = try? String(contentsOf: appcastFileURL) else {
    print("Unable to locate Appcast.xml")
    exit(1)
}

guard let insertIndex = appcastFile.range(of: "<title>MockingStar</title>")?.upperBound else {
    print("Unable to parse Appcast.xml")
    exit(1)
}

let dateFormatter = DateFormatter()
dateFormatter.dateFormat = "E, d MMM yyyy HH:mm:ss Z"

let parser = MarkdownParser()
let versionDescriptionHTML = parser.html(from: releaseNotes)

let appcastItem = """

                <item>
                    <title>Version \(version)</title>
                    <description>
                        <![CDATA[
        \(versionDescriptionHTML)
                        ]]>
                    </description>
                    <pubDate>\(dateFormatter.string(from: Date()))</pubDate>
                    <sparkle:minimumSystemVersion>\(minimumVersion)</sparkle:minimumSystemVersion>
                    <enclosure url="https://github.com/Trendyol/mockingstar/releases/download/\(versionTag)/MockingStar-App.zip"
                    sparkle:version="\(buildNumber)" sparkle:shortVersionString="\(version)"
                    \(signature)
                    type="application/octet-stream"/>
                </item>\n
        """

appcastFile.insert(contentsOf: appcastItem, at: insertIndex)

do {
    try appcastFile.write(to: appcastFileURL, atomically: true, encoding: .utf8)
} catch {
    print("Write Appcast file failed: \(error)")
    exit(1)
}
