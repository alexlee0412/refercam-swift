import UIKit

struct ReferencePhoto: Identifiable, Hashable {
    let id: String
    let title: String
    let assetName: String

    /// True once a matching image set has been added to Assets.xcassets.
    /// Expected asset names: "ReferencePortrait", "ReferenceStreet", "ReferenceCafe".
    var isAssetAvailable: Bool {
        UIImage(named: assetName) != nil
    }

    static let samples: [ReferencePhoto] = [
        .init(id: "portrait", title: "Portrait", assetName: "ReferencePortrait"),
        .init(id: "street", title: "Street", assetName: "ReferenceStreet"),
        .init(id: "cafe", title: "Café", assetName: "ReferenceCafe")
    ]
}
