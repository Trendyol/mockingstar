import Foundation

public enum MockFileLocation {
    public static func cleanPath(url: URL) -> String {
        if url.path().isEmpty || url.path() == "/" {
            return url.host() ?? url.absoluteString
        }
        return url.path().encodedUrlPathValue
    }

    public static func fileName(url: URL, scenario: String, id: String) -> String {
        let path = cleanPath(url: url)
        var name = path.replacingOccurrences(of: "/", with: "+") + "_"
        if !scenario.isEmpty {
            name += scenario + "_"
        }
        name += id + ".json"
        if name.count > 256 {
            return (scenario.isEmpty ? "" : scenario + "_") + id + ".json"
        }
        return name
    }

    public static func folderPath(url: URL, method: String) -> String {
        cleanPath(url: url) + "/" + method.uppercased()
    }

    public static func filePath(
        url: URL,
        method: String,
        scenario: String,
        id: String
    ) -> String {
        folderPath(url: url, method: method)
            + "/"
            + fileName(url: url, scenario: scenario, id: id)
    }
}
