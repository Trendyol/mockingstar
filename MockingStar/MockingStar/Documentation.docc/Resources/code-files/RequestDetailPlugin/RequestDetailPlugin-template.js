function mockDetailMessages(path, scenario, mock) {
    if (scenario == "") {
        return ""
    }
    return `**UI Test Helper Code**

setMockScenario(path: "${path}", scenario: "${scenario}")`
}
