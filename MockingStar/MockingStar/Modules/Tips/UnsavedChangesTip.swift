//
//  UnsavedChangesTip.swift
//  MockingStar
//
//  Created by Yusuf Özgül on 22.09.2023.
//

import TipKit

struct UnsavedChangesTip: Tip {
    static let shared = UnsavedChangesTip()
    
    var title: Text {
        Text("Unsaved changes")
            .foregroundStyle(.indigo)
    }

    var message: Text? {
        Text("You can save or discard them")
    }

    var image: Image? {
        Image(systemName: "smallcircle.filled.circle.fill")
    }
}
