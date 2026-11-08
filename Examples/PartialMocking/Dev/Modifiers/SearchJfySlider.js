// metadata
var path = "/tmcdiscovery-msearch-mcwidgets-santral/tr-TR-1/search/widgets"
var method = "GET"
var scenario = null
var order = 2
var sampleMockRequestId = "0A2343F2-DB20-40AC-AD1A-FAD7F88C01D4"
var previewCurl = "curl 'https://apigw.trendyol.com/tmcdiscovery-msearch-mcwidgets-santral/tr-TR-1/search/widgets?q=elbise&page=1&customSortType=true&source=SEARCH&platform=Android&build=1471&gender=F&pid=0&channelId=1' -H 'Platform: Android' -H 'Accept-Language: tr-TR' -H 'x-application-id: 5' -H 'x-storefront-id: 1' -H 'x-channelid: 1' -H 'Build: 8.24.0.1471' -H 'Gender: F'"
var previewSource = "live"
var previewScenario = ""

function transformer(req, chain) {
  var res = chain.proceed(req);

  const jfyWidget = {
    id: 15252,
    widgetIdWithOrder: "15252_0",
    fullServiceUrl:
      "https://apigw.trendyol.com/tmcdiscovery-msocial-mcproducts-santral/tr-TR-1/just-for-you/products?AB=SuggestionFA_A%2CMRLO_B%2CCFL_A%2CRRIn_B%2CSCB_B%2CBP_B%2CCatTR_B%2CBRW_B%2CAZSmartlisting_62%2CLB_B%2CMB_B%2CMRF_1%2Cspn_B%2CARR_B%2CMA_B%2CRR_2%2CBS_2&EXPRAB=QR_B%2CStampProjectHideFlashStamp_B%2CPaymentBadge_A%2CColorFilter_B%2CNewStamp_B%2CFLPAddtocart_C%2CRelatedresults_B%2CCodePS_B%2CSuggestionNS_B%2COPHeight_B%2CSponsoredStamp_A%2CSingleSP_B%2CTYPStrip_B%2CLastXDays_B%2CStickyCoupon_B%2CRRBadge_B%2CSCL10D_B%2CCouponBundleAB_B%2CRTRR_B%2CPBSBP_B%2Cscm_b%2CNVS_B%2Csr_b%2CSingleLineDesc_B%2Crrpl_d%2CDsNlp_2%2CTDD_B%2CStoreJFY_C%2CNDDCountdown2_A%2CSCRImageEncoder_B%2CRRStarFilter_B%2CHVSM_B&IsSearchListingJfySlider=true&activePriceTests=PBSBP_B%2CLuxuryPriceEnabled_A&build=1461&dataVersionKey=singleProducts_JFY_Original&feedingSource=JUST_FOR_YOU&gender=F&isSearchProduct=true&isTYPlusPriceEnable=true&merchantId=968&pid=ed133b3a-80f9-4b53-9a60-c0eabb5c8540&platform=Android&sectionId=1&shouldSkipLPDTypes=true&sliderTitle=Sana+%C3%B6zel+%C3%BCr%C3%BCnler&source=SELLER_STORE&supportedPriceTypes=CP%2CBNP%2CBDP%2CAEP%2CAZP&widgetDisplayType=SLIDER&widgetEventKey=search_reco_engine_jfy_widget&widgetId=15252&widgetIndex=0&widgetPageType=search_listing&widgetType=JFY",
    fullServiceUrlWithPage:
      "https://apigw.trendyol.com/tmcdiscovery-msocial-mcproducts-santral/tr-TR-1/just-for-you/products?AB=SuggestionFA_A%2CMRLO_B%2CCFL_A%2CRRIn_B%2CSCB_B%2CBP_B%2CCatTR_B%2CBRW_B%2CAZSmartlisting_62%2CLB_B%2CMB_B%2CMRF_1%2Cspn_B%2CARR_B%2CMA_B%2CRR_2%2CBS_2&EXPRAB=QR_B%2CStampProjectHideFlashStamp_B%2CPaymentBadge_A%2CColorFilter_B%2CNewStamp_B%2CFLPAddtocart_C%2CRelatedresults_B%2CCodePS_B%2CSuggestionNS_B%2COPHeight_B%2CSponsoredStamp_A%2CSingleSP_B%2CTYPStrip_B%2CLastXDays_B%2CStickyCoupon_B%2CRRBadge_B%2CSCL10D_B%2CCouponBundleAB_B%2CRTRR_B%2CPBSBP_B%2Cscm_b%2CNVS_B%2Csr_b%2CSingleLineDesc_B%2Crrpl_d%2CDsNlp_2%2CTDD_B%2CStoreJFY_C%2CNDDCountdown2_A%2CSCRImageEncoder_B%2CRRStarFilter_B%2CHVSM_B&IsSearchListingJfySlider=true&activePriceTests=PBSBP_B%2CLuxuryPriceEnabled_A&build=1461&dataVersionKey=singleProducts_JFY_Original&feedingSource=JUST_FOR_YOU&gender=F&isSearchProduct=true&isTYPlusPriceEnable=true&merchantId=968&pid=ed133b3a-80f9-4b53-9a60-c0eabb5c8540&platform=Android&sectionId=1&shouldSkipLPDTypes=true&sliderTitle=Sana+%C3%B6zel+%C3%BCr%C3%BCnler&source=SELLER_STORE&supportedPriceTypes=CP%2CBNP%2CBDP%2CAEP%2CAZP&widgetDisplayType=SLIDER&widgetEventKey=search_reco_engine_jfy_widget&widgetId=15252&widgetIndex=0&widgetPageType=search_listing&widgetType=JFY",
    displayType: "SLIDER",
    eventKey: "search_reco_engine_jfy_widget",
    title: "Sana özel ürünler",
    type: "SEARCH_JFY",
    displayOptions: {
      showProductPrice: true,
      showProductFavoredButton: true,
      showClearButton: false,
      showCountOnTitle: false,
      showSoldOutBadge: false,
      showAddToMyPicksButton: false,
    },
    marketing: {
      delphoi: {
        tv069: "0",
        tv070: "search_reco_engine_jfy_widget",
        tv072: "15252",
        tv073: "SEARCH_JFY",
        tv076: "968",
        tv097: "homepage_",
      },
      demeter: {
        display_type: "SLIDER",
        display_type_variation: "DEFAULT",
        merchant_id: "968",
        order_y: "0",
        search_event_key: "search_reco_engine_jfy_widget",
        search_widget_id: "15252",
        search_widget_page_id: "homepage_",
        search_widget_type: "JFY",
        slider_title: "Sana özel ürünler",
        source_content: "JUST_FOR_YOU",
      },
    },
    refreshRequired: false,
    displayTypeVariation: "DEFAULT",
    forNewUser: false,
  };

  res.body.widgets[0] = jfyWidget;
  return res;
}
