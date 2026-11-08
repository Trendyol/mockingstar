// metadata
var path = "/tmcdiscovery-msearch-mcwidgets-santral/tr-TR-1/search/widgets"
var method = "GET"
var scenario = null
var order = 1
var sampleMockRequestId = "0A2343F2-DB20-40AC-AD1A-FAD7F88C01D4"
var previewCurl = "curl 'https://apigw.trendyol.com/tmcdiscovery-msearch-mcwidgets-santral/tr-TR-1/search/widgets?q=elbise&page=1&customSortType=true&source=SEARCH&platform=Android&build=1471&gender=F&pid=0&channelId=1' -H 'Platform: Android' -H 'Accept-Language: tr-TR' -H 'x-application-id: 5' -H 'x-storefront-id: 1' -H 'x-channelid: 1' -H 'Build: 8.24.0.1471' -H 'Gender: F'"
var previewSource = "live"
var previewScenario = ""

function transformer(req, chain) {
  function replaceElbiseParameter(url, name) {
    return url.replace(new RegExp("([?&]" + name + "=)([^&#]*)", "g"), function (match, prefix, value) {
      return decodeURIComponent(value.replace(/\+/g, " ")).toLowerCase() === "elbise"
        ? prefix + "Pantolon"
        : match;
    });
  }

  req.url = replaceElbiseParameter(req.url, "q");
  req.url = req.url.replace(/([?&]deeplink=)([^&#]*)/g, function (match, prefix, value) {
    var deeplink = decodeURIComponent(value.replace(/\+/g, " "));
    var updated = replaceElbiseParameter(deeplink, "Query");
    return updated === deeplink ? match : prefix + encodeURIComponent(updated);
  });

  // The backend receives Pantolon; its response is returned unchanged.
  return chain.proceed(req);
}
