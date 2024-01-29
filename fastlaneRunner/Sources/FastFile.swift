//
//  FastFile.swift
//
//
//  Created by Yusuf Özgül on 15.11.2023.
//

import Fastlane
import Foundation

final class MockingStarFastFile: LaneFile {}

// MARK: - Release
extension MockingStarFastFile {
    func releaseAppLane() {
        defer {
            cleanKeychain()
        }

        print("Building MockingStar App")

        createCertificates()

        let password = environmentVariable(get: "PASS")
        let teamId = environmentVariable(get: "TEAM_ID")
        let bundleId = "com.trendyol.mocking-star"

        createKeychain(name: "MockingStarKeychain",
                       password: password,
                       defaultKeychain: true,
                       unlock: true,
                       timeout: 3600)

        print("Installing Certificates")
        importCertificate(certificatePath: "./certs/MockingStarCert.p12",
                          certificatePassword: .userDefined(password),
                          keychainName: "MockingStarKeychain",
                          keychainPassword: .userDefined(password))

        print("Installing Profiles")
        installProvisioningProfile(path: "./certs/Direct_com.trendyol.MockingStar.provisionprofile")


        print("Configure CodeSigning")
        updateProjectProvisioning(xcodeproj: "./MockingStar/MockingStar.xcodeproj",
                                  profile: "./certs/Direct_com.trendyol.MockingStar.provisionprofile",
                                  targetFilter: "MockingStar",
                                  buildConfiguration: "Release")

        guard let buildNumber = environmentVariable(get: "VERSION").components(separatedBy: "-").last,
              let version = environmentVariable(get: "VERSION").components(separatedBy: "-").first else {
            print("Decoding version failed: \(environmentVariable(get: "VERSION"))")
            return
        }

        incrementBuildNumber(buildNumber: .userDefined(buildNumber), xcodeproj: "./MockingStar/MockingStar.xcodeproj")
        sh(command: "sed -i '' -e 's/MARKETING_VERSION \\= [^\\;]*\\;/MARKETING_VERSION = \(version);/' ./MockingStar/MockingStar.xcodeproj/project.pbxproj"){ error in
            print("update version error: \(error)")
            fatalError(error)
        }

        print("Build App")
        buildMacApp(workspace: "./MockingStar.xcworkspace",
                    scheme: "MockingStar",
                    clean: true,
                    outputDirectory: "./.build/appBuildOutput",
                    outputName: "MockingStar",
                    configuration: "Release",
                    codesigningIdentity: .userDefined(environmentVariable(get: "CODESIGNING_IDENTITY")),
                    exportMethod: "developer-id",
                    exportOptions: .userDefined([
                        "provisioningProfiles": [
                            bundleId: "com.trendyol.mocking-star Direct"
                        ]
                    ]),
                    buildPath: "./.build/appBuild",
                    archivePath: "./.build/archive",
                    derivedDataPath: "./.build/derivedData",
                    exportTeamId: .userDefined(teamId),
                    xcargs: "CODE_SIGN_STYLE=Manual",
                    xcodebuildFormatter: "xcpretty")


        notarize(package: "./.build/appBuildOutput/MockingStar.app",
                 useNotarytool: false,
                 bundleId: .userDefined(bundleId),
                 apiKey: .userDefined([
                    "filepath": "./certs/ASCKEY.p8",
                    "key_id": environmentVariable(get: "ASC_KEY_ID"),
                    "issuer_id": environmentVariable(get: "ASC_ISSUER_ID"),
                 ]))
    }

    func releaseCLILane() {
        print("Building MockingStar CLI app")

        spm(
            command: "build",
            buildPath: "./.build",
            packagePath: "./MockingStarExecutable",
            configuration: "release"
        )
    }
}

// MARK: - Tests
extension MockingStarFastFile {
    func unitTestLane() {
        print("Unit Test Lane")

        runTests(workspace: "./MockingStar.xcworkspace",
                 scheme: "MockingStar",
                 xcodebuildFormatter: "xcpretty")
    }
}

// MARK: - DocC
extension MockingStarFastFile {
    func buildDocCLane() {
        print("Building DocC")

        sh(command: "xcodebuild docbuild -scheme MockingStar -derivedDataPath ./.Docc -workspace ./MockingStar.xcworkspace") { error in
            print("xcodebuild docbuild error: \(error)")
            fatalError(error)
        }

        sh(command: "$(xcrun --find docc) process-archive transform-for-static-hosting ./.Docc/Build/Products/Debug/MockingStar.doccarchive --output-path ./.docsExport") { error in
            print("export DocC error: \(error)")
            fatalError(error)
        }
    }
}

// MARK: - Helpers
extension MockingStarFastFile {
    func createCertificates() {
        print("Creating Certificates")

        var isFolderExist: ObjCBool = false
        if !FileManager.default.fileExists(atPath: "./certs", isDirectory: &isFolderExist) || !isFolderExist.boolValue {
            try! FileManager.default.createDirectory(atPath: "./certs", withIntermediateDirectories: false)
        } else {
            try? FileManager.default.removeItem(atPath: "./certs/MockingStarCert.p12")
            try? FileManager.default.removeItem(atPath: "./certs/AppStore_com.trendyol.MockingStar.provisionprofile")
        }

        let certificate = environmentVariable(get: "CERT")
        let profile = environmentVariable(get: "PROFILE")
        let ascKey = environmentVariable(get: "ASC_KEY")

        FileManager.default.createFile(atPath: "./certs/MockingStarCert.p12",
                                       contents: Data(base64Encoded: certificate))

        FileManager.default.createFile(atPath: "./certs/Direct_com.trendyol.MockingStar.provisionprofile",
                                       contents: Data(base64Encoded: profile))

        FileManager.default.createFile(atPath: "./certs/ASCKEY.p8",
                                       contents: Data(base64Encoded: ascKey))
    }

    func cleanKeychain() {
        sh(command: #"security default-keychain -s "login.keychain-db""#) { error in
            print("make default keychain error: \(error)")
            fatalError(error)
        }
        deleteKeychain(name: "MockingStarKeychain")

        try? FileManager.default.removeItem(atPath: "./certs/MockingStarCert.p12")
        try? FileManager.default.removeItem(atPath: "./certs/Direct_com.trendyol.MockingStar.provisionprofile")
        try? FileManager.default.removeItem(atPath: "./certs/ASCKEY.p8")
    }
}
