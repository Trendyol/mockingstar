async function asyncMockDetailMessages(mock) {
    let updated = util.urlRequest(mock.metaData.url.relative, JSON.stringify(mock.requestHeader), mock.metaData.method, mock.requestBody)

    if (updated.body != mock.responseBody) {
        return "Your mock updated you can reload mock"
    } else {
        return ""
    }
}
