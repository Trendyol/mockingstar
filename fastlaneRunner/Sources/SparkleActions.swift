//
//  SparkleActions.swift
//
//
//  Created by Yusuf Özgül on 02.02.2024.
//

import Fastlane
import Foundation

final class SparkleActions {
    func updateSparkleChangeLogs() {
        let versionTag = environmentVariable(get: "VERSION")
        let versionDescription = environmentVariable(get: "RELEASE_NOTES")
        guard let buildNumber = versionTag.components(separatedBy: "-").last,
              let version = versionTag.components(separatedBy: "-").first else {
            print("Decoding version failed: \(versionTag)")
            return
        }

        let minimumSystemVersion = getInfoPlistValue(key: "LSMinimumSystemVersion",
                                                     path: ".build/appBuildOutput/MockingStar.app/Contents/Info.plist")

        let signature = sh(command: "./.build/derivedData/SourcePackages/artifacts/sparkle/Sparkle/bin/sign_update -f certs/Sparkle.key .build/appBuildOutput/MockingStar-App.zip",
                           log: false).trimmingCharacters(in: .whitespacesAndNewlines)

        let appcastFileURL = URL(fileURLWithPath: "Appcast.xml")
        guard var appcastFile = try? String(contentsOf: appcastFileURL) else {
            print("Unable to locate Appcast.xml")
            return
        }

        guard let insertIndex = appcastFile.range(of: "<title>MockingStar</title>")?.upperBound else {
            print("Unable to parse Appcast.xml")
            return
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "E, d MMM yyyy HH:mm:ss Z"

        let appcastItem = """

                <item>
                    <title>Version \(version)</title>
                    <description>
                        <![CDATA[
        \(versionDescription)
                        ]]>
                    </description>
                    <pubDate>\(dateFormatter.string(from: Date()))</pubDate>
                    <sparkle:minimumSystemVersion>\(minimumSystemVersion)</sparkle:minimumSystemVersion>
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
            return
        }

        gitCommit(path: ["Appcast.xml"], message: "Release version \(versionTag)! 🎉")
        pushToGitRemote()
    }
}
