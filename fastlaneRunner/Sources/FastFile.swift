//
//  FastFile.swift
//
//
//  Created by Yusuf Özgül on 15.11.2023.
//

import Fastlane
import Foundation

final class MockingStarFastFile: LaneFile {
    func afterAll(with lane: String) {
        guard lane == "releaseAppLane" else { return }

        cleanKeychain()
    }
}

// MARK: - Release
extension MockingStarFastFile {
    func releaseAppLane() {
        print("Building MockingStar App")

        createCertificates()

        let keychainPassword = environmentVariable(get: "KEYCHAIN_PASS")
        let certificatePassword = environmentVariable(get: "CERT_PASS")
        let teamId = environmentVariable(get: "TEAM_ID")
        let installerCertName = environmentVariable(get: "INSTALLER_CERT_NAME")

        createKeychain(name: "MockingStarKeychain",
                       password: keychainPassword,
                       defaultKeychain: true,
                       unlock: true,
                       timeout: 3600)

        print("Installing Certificates")
        importCertificate(certificatePath: "./certs/MockingStarCert.p12",
                          certificatePassword: .userDefined(certificatePassword),
                          keychainName: "MockingStarKeychain",
                          keychainPassword: .userDefined(keychainPassword))
        importCertificate(certificatePath: "./certs/AppleWWDRCAG3.cer",
                          keychainName: "MockingStarKeychain",
                          keychainPassword: .userDefined(keychainPassword))

        print("Installing Profiles")
        installProvisioningProfile(path: "./certs/AppStore_com.trendyol.MockingStar.provisionprofile")

        print("Configure CodeSigning")
        updateCodeSigningSettings(path: "./MockingStar/MockingStar.xcodeproj", useAutomaticSigning: false)
        updateProjectProvisioning(xcodeproj: "./MockingStar/MockingStar.xcodeproj",
                                  profile: "./certs/AppStore_com.trendyol.MockingStar.provisionprofile",
                                  targetFilter: "MockingStar",
                                  buildConfiguration: "Release")
        updateProjectTeam(path: "./MockingStar/MockingStar.xcodeproj", teamid: teamId)

        appStoreConnectApiKey(keyId: environmentVariable(get: "AC_KEY_ID"),
                              issuerId: environmentVariable(get: "AC_ISSUER_ID"),
                              keyContent: .userDefined(environmentVariable(get: "AC_API_KEY")),
                              isKeyContentBase64: true)

        let buildNumber = latestTestflightBuildNumber(appIdentifier: "com.trendyol.MockingStar", platform: "osx")
        incrementBuildNumber(buildNumber: .userDefined("\(buildNumber + 1)"), xcodeproj: "./MockingStar/MockingStar.xcodeproj")
        sh(command: "sed -i '' -e 's/MARKETING_VERSION \\= [^\\;]*\\;/MARKETING_VERSION = \(environmentVariable(get: "VERSION"));/' ./MockingStar/MockingStar.xcodeproj/project.pbxproj"){ error in
            print("update version error: \(error)")
            fatalError(error)
        }

        print("Build App")
        gym(workspace: "./MockingStar.xcworkspace",
            scheme: "MockingStar",
            outputDirectory: "./.appBuildOutput",
            outputName: "MockingStar",
            configuration: "Release",
            exportMethod: "app-store",
            exportOptions: .userDefined([
                "provisioningProfiles": [
                    "com.trendyol.MockingStar": "com.trendyol.MockingStar AppStore"
                ]
            ]),
            installerCertName: .userDefined(installerCertName),
            buildPath: "./.appBuild",
            archivePath: "./.archive",
            derivedDataPath: "./.derivedData",
            exportTeamId: .userDefined(teamId),
            xcodebuildFormatter: "xcpretty")

        print("Upload to Testflight")

        uploadToTestflight(appIdentifier: "com.trendyol.MockingStar",
                           pkg: "./.appBuildOutput/MockingStar.pkg",
                           skipWaitingForBuildProcessing: true)

        cleanKeychain()
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
        let wwdr = environmentVariable(get: "WWDR")

        FileManager.default.createFile(atPath: "./certs/MockingStarCert.p12",
                                       contents: Data(base64Encoded: certificate))

        FileManager.default.createFile(atPath: "./certs/AppStore_com.trendyol.MockingStar.provisionprofile",
                                       contents: Data(base64Encoded: profile))

        FileManager.default.createFile(atPath: "./certs/AppleWWDRCAG3.cer",
                                       contents: Data(base64Encoded: wwdr))
    }

    func cleanKeychain() {
        sh(command: #"security default-keychain -s "login.keychain-db""#) { error in
            print("make default keychain error: \(error)")
            fatalError(error)
        }
        deleteKeychain(name: "MockingStarKeychain")

        try? FileManager.default.removeItem(atPath: "./certs/MockingStarCert.p12")
        try? FileManager.default.removeItem(atPath: "./certs/AppStore_com.trendyol.MockingStar.provisionprofile")
    }
}
