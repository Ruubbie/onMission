import SwiftUI

// Lucide icons (ISC licence) with their motion ported from lucide-animated (pqoqubbw/icons, MIT).
// Geometry is Lucide's 24-unit grid; motions follow the prototype's `LA` table (handoff §8).

/// One stroke of an icon. `tag` marks the parts a motion moves.
struct IconPart {
    let d: String
    var tag: String = ""
    /// Transform origin in grid units; the part's own centre when nil.
    var origin: CGPoint? = nil

    var anchor: UnitPoint {
        if let origin { return UnitPoint(x: origin.x / 24, y: origin.y / 24) }
        let box = SVG.path(d).boundingRect
        return UnitPoint(x: box.midX / 24, y: box.midY / 24)
    }
}

struct IconPose {
    var trimFrom: Double = 0
    var trimTo: Double = 1
    var opacity: Double = 1
    var scale: Double = 1
    var rotation: Double = 0
    var dx: Double = 0
    var dy: Double = 0
}

enum Icon: String, CaseIterable {
    // The animated set (handoff §8).
    case sun, list, users, flame, plane, plus, x, phone, check, heart, arrow, gear, lock, bag, euro, tag, mail,
         note, book, back, chev, camera, search, sync, pass, ticket, shield
    // Static Lucide icons for everything else.
    case trash, link, share, pin, calendar, message, gift, house, health, globe, church, user, building, file,
         diploma, receipt, quote, pen, card, bulb, notebook, map, archive, more, eye, download, clip, image,
         sliders, minus, chevDown, logout, bell, device, laptop, templates, cloudOff, undo, folder, star

    /// Stroke width on the 24 grid.
    var weight: CGFloat {
        switch self {
        case .plus: 2.5
        case .x, .back, .chev, .chevDown: 2.4
        case .check: 2.6
        case .arrow: 2.3
        case .gear: 1.8
        case .search: 2.2
        default: 2
        }
    }

    var parts: [IconPart] {
        switch self {
        case .sun:
            return [IconPart(d: SVG.circle(12, 12, 4))] + [
                "M12 2v2", "m19.07 4.93-1.41 1.41", "M20 12h2", "m17.66 17.66 1.41 1.41",
                "M12 20v2", "m6.34 17.66-1.41 1.41", "M2 12h2", "m4.93 4.93 1.41 1.41",
            ].map { IconPart(d: $0, tag: "r") }
        case .list:
            return [IconPart(d: SVG.rect(8, 2, 8, 4, rx: 1)),
                    IconPart(d: "M16 4h2a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2h2"),
                    IconPart(d: "m9 14 2 2 4-4", tag: "c")]
        case .users:
            return [IconPart(d: "M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"), IconPart(d: SVG.circle(9, 7, 4)),
                    IconPart(d: "M22 21v-2a4 4 0 0 0-3-3.87", tag: "a"), IconPart(d: "M16 3.13a4 4 0 0 1 0 7.75", tag: "a")]
        case .flame:
            return [IconPart(d: "M8.5 14.5A2.5 2.5 0 0 0 11 12c0-1.38-.5-2-1-3-1.072-2.143-.224-4.054 2-6 .5 2.5 2 4.9 4 6.5 2 1.6 3 3.5 3 5.5a7 7 0 1 1-14 0c0-1.153.433-2.294 1-3a2.5 2.5 0 0 0 2.5 2.5z", tag: "f")]
        case .plane:
            return [IconPart(d: "M2 22h20"),
                    IconPart(d: "M6.36 17.4 4 17l-2-4 1.1-.55a2 2 0 0 1 1.8 0l.17.1a2 2 0 0 0 1.8 0L8 12 5 6l.9-.45a2 2 0 0 1 2.09.2l4.02 3a2 2 0 0 0 2.1.2l4.19-2.06a2.41 2.41 0 0 1 1.73-.17L21 7a1.4 1.4 0 0 1 .87 1.99l-.38.76c-.23.46-.6.84-1.07 1.08L7.58 17.2a2 2 0 0 1-1.22.18Z", tag: "p")]
        case .plus:
            return [IconPart(d: "M5 12h14"), IconPart(d: "M12 5v14")]
        case .x:
            return [IconPart(d: "M18 6 6 18", tag: "s"), IconPart(d: "m6 6 12 12", tag: "s")]
        case .phone:
            return [IconPart(d: "M13 2a9 9 0 0 1 9 9", tag: "w2"), IconPart(d: "M13 6a5 5 0 0 1 5 5", tag: "w1"),
                    IconPart(d: "M13.832 16.568a1 1 0 0 0 1.213-.303l.355-.465A2 2 0 0 1 17 15h3a2 2 0 0 1 2 2v3a2 2 0 0 1-2 2A18 18 0 0 1 2 4a2 2 0 0 1 2-2h3a2 2 0 0 1 2 2v3a2 2 0 0 1-.8 1.6l-.468.351a1 1 0 0 0-.292 1.233 14 14 0 0 0 6.392 6.384")]
        case .check:
            return [IconPart(d: "M4 12 9 17L20 6", tag: "c")]
        case .heart:
            return [IconPart(d: "M19 14c1.49-1.46 3-3.21 3-5.5A5.5 5.5 0 0 0 16.5 3c-1.76 0-3 .5-4.5 2-1.5-1.5-2.74-2-4.5-2A5.5 5.5 0 0 0 2 8.5c0 2.3 1.5 4.05 3 5.5l7 7Z")]
        case .arrow:
            return [IconPart(d: "M5 12h14", tag: "s"), IconPart(d: "m12 5 7 7-7 7", tag: "h")]
        case .gear:
            return [IconPart(d: "M12.22 2h-.44a2 2 0 0 0-2 2v.18a2 2 0 0 1-1 1.73l-.43.25a2 2 0 0 1-2 0l-.15-.08a2 2 0 0 0-2.73.73l-.22.38a2 2 0 0 0 .73 2.73l.15.1a2 2 0 0 1 1 1.72v.51a2 2 0 0 1-1 1.74l-.15.09a2 2 0 0 0-.73 2.73l.22.38a2 2 0 0 0 2.73.73l.15-.08a2 2 0 0 1 2 0l.43.25a2 2 0 0 1 1 1.73V20a2 2 0 0 0 2 2h.44a2 2 0 0 0 2-2v-.18a2 2 0 0 1 1-1.73l.43-.25a2 2 0 0 1 2 0l.15.08a2 2 0 0 0 2.73-.73l.22-.39a2 2 0 0 0-.73-2.73l-.15-.08a2 2 0 0 1-1-1.74v-.5a2 2 0 0 1 1-1.74l.15-.09a2 2 0 0 0 .73-2.73l-.22-.38a2 2 0 0 0-2.73-.73l-.15.08a2 2 0 0 1-2 0l-.43-.25a2 2 0 0 1-1-1.73V4a2 2 0 0 0-2-2z"),
                    IconPart(d: SVG.circle(12, 12, 3))]
        case .lock:
            return [IconPart(d: SVG.rect(3, 11, 18, 11, rx: 2)), IconPart(d: "M7 11V7a5 5 0 0 1 10 0v4", tag: "k")]
        case .bag:
            return [IconPart(d: "M12 12h.01"), IconPart(d: "M16 6V4a2 2 0 0 0-2-2h-4a2 2 0 0 0-2 2v2"),
                    IconPart(d: "M22 13a18.15 18.15 0 0 1-20 0"), IconPart(d: SVG.rect(2, 6, 20, 14, rx: 2))]
        case .euro:
            return [IconPart(d: "M19 6a7.7 7.7 0 0 0-5.2-2A7.9 7.9 0 0 0 6 12c0 4.4 3.5 8 7.8 8 2 0 3.8-.8 5.2-2", tag: "m"),
                    IconPart(d: "M16 10h-12", tag: "s"), IconPart(d: "M13 14h-9", tag: "s")]
        case .tag:
            return [IconPart(d: "M11 15h2a2 2 0 1 0 0-4h-3c-.6 0-1.1.2-1.4.6L3 17"),
                    IconPart(d: "m7 21 1.6-1.4c.3-.4.8-.6 1.4-.6h4c1.1 0 2.1-.4 2.8-1.2l4.6-4.4a2 2 0 0 0-2.75-2.91l-4.2 3.9"),
                    IconPart(d: "m2 16 6 6"), IconPart(d: SVG.circle(16, 9, 2.9), tag: "c"), IconPart(d: SVG.circle(6, 5, 3), tag: "c")]
        case .mail:
            return [IconPart(d: "M22 13V6a2 2 0 0 0-2-2H4a2 2 0 0 0-2 2v12c0 1.1.9 2 2 2h8"),
                    IconPart(d: "m22 7-8.97 5.7a1.94 1.94 0 0 1-2.06 0L2 7"), IconPart(d: "m16 19 2 2 4-4", tag: "c")]
        case .note:
            return [IconPart(d: "M15 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V7Z"),
                    IconPart(d: "M14 2v4a2 2 0 0 0 2 2h4"), IconPart(d: "M10 9H8", tag: "l"),
                    IconPart(d: "M16 13H8", tag: "l"), IconPart(d: "M16 17H8", tag: "l")]
        case .book:
            return [IconPart(d: "M4 19.5v-15A2.5 2.5 0 0 1 6.5 2H19a1 1 0 0 1 1 1v18a1 1 0 0 1-1 1H6.5a1 1 0 0 1 0-5H20"),
                    IconPart(d: "M8 11h8"), IconPart(d: "M8 7h6")]
        case .back:
            return [IconPart(d: "m15 18-6-6 6-6", tag: "n")]
        case .chev:
            return [IconPart(d: "m9 18 6-6-6-6", tag: "n")]
        case .camera:
            return [IconPart(d: "M14.5 4h-5L7 7H4a2 2 0 0 0-2 2v9a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2V9a2 2 0 0 0-2-2h-3l-2.5-3z"),
                    IconPart(d: SVG.circle(12, 13, 3), tag: "c")]
        case .search:
            return [IconPart(d: SVG.circle(11, 11, 8)), IconPart(d: "m21 21-4.3-4.3")]
        case .sync:
            return [IconPart(d: "M3 12a9 9 0 0 1 9-9 9.75 9.75 0 0 1 6.74 2.74L21 8"), IconPart(d: "M21 3v5h-5"),
                    IconPart(d: "M21 12a9 9 0 0 1-9 9 9.75 9.75 0 0 1-6.74-2.74L3 16"), IconPart(d: "M8 16H3v5")]
        case .pass:
            return [IconPart(d: "M16 10h2", tag: "d2"), IconPart(d: "M16 14h2", tag: "d2"),
                    IconPart(d: "M6.17 15a3 3 0 0 1 5.66 0", tag: "d0"), IconPart(d: SVG.circle(9, 11, 2), tag: "d1"),
                    IconPart(d: SVG.rect(2, 5, 20, 14, rx: 2))]
        case .ticket:
            return [IconPart(d: "M13 5H4a2 2 0 0 0-2 2v2a3 3 0 0 1 0 6v2a2 2 0 0 0 2 2h9", tag: "lt"),
                    IconPart(d: "M13 5v2", tag: "lt"), IconPart(d: "M13 11v2", tag: "lt"), IconPart(d: "M13 17v2", tag: "lt"),
                    IconPart(d: "M13 5h7a2 2 0 0 1 2 2v2a3 3 0 0 0 0 6v2a2 2 0 0 1-2 2h-7", tag: "rt", origin: CGPoint(x: 13, y: 12))]
        case .shield:
            return [IconPart(d: "M20 13c0 5-3.5 7.5-7.66 8.95a1 1 0 0 1-.67-.01C7.5 20.5 4 18 4 13V6a1 1 0 0 1 1-1c2 0 4.5-1.2 6.24-2.72a1.17 1.17 0 0 1 1.52 0C14.51 3.81 17 5 19 5a1 1 0 0 1 1 1z"),
                    IconPart(d: "m9 12 2 2 4-4", tag: "c")]

        case .trash:
            return ["M3 6h18", "M19 6v14c0 1-1 2-2 2H7c-1 0-2-1-2-2V6", "M8 6V4c0-1 1-2 2-2h4c1 0 2 1 2 2v2",
                    SVG.line(10, 11, 10, 17), SVG.line(14, 11, 14, 17)].map { IconPart(d: $0) }
        case .link:
            return ["M10 13a5 5 0 0 0 7.54.54l3-3a5 5 0 0 0-7.07-7.07l-1.72 1.71",
                    "M14 11a5 5 0 0 0-7.54-.54l-3 3a5 5 0 0 0 7.07 7.07l1.71-1.71"].map { IconPart(d: $0) }
        case .share:
            return ["M4 12v8a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-8", SVG.polyline([16, 6, 12, 2, 8, 6]),
                    SVG.line(12, 2, 12, 15)].map { IconPart(d: $0) }
        case .pin:
            return ["M12 17v5",
                    "M9 10.76a2 2 0 0 1-1.11 1.79l-1.78.9A2 2 0 0 0 5 15.24V16a1 1 0 0 0 1 1h12a1 1 0 0 0 1-1v-.76a2 2 0 0 0-1.11-1.79l-1.78-.9A2 2 0 0 1 15 10.76V7a1 1 0 0 1 1-1 2 2 0 0 0 0-4H8a2 2 0 0 0 0 4 1 1 0 0 1 1 1z"].map { IconPart(d: $0) }
        case .calendar:
            return ["M8 2v4", "M16 2v4", SVG.rect(3, 4, 18, 18, rx: 2), "M3 10h18"].map { IconPart(d: $0) }
        case .message:
            return [IconPart(d: "M7.9 20A9 9 0 1 0 4 16.1L2 22Z")]
        case .gift:
            return [SVG.rect(3, 8, 18, 4, rx: 1), "M12 8v13", "M19 12v7a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2v-7",
                    "M7.5 8a2.5 2.5 0 0 1 0-5A4.8 8 0 0 1 12 8a4.8 8 0 0 1 4.5-5 2.5 2.5 0 0 1 0 5"].map { IconPart(d: $0) }
        case .house:
            return ["M15 21v-8a1 1 0 0 0-1-1h-4a1 1 0 0 0-1 1v8",
                    "M3 10a2 2 0 0 1 .709-1.528l7-5.999a2 2 0 0 1 2.582 0l7 5.999A2 2 0 0 1 21 10v9a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"].map { IconPart(d: $0) }
        case .health:
            return ["M19 14c1.49-1.46 3-3.21 3-5.5A5.5 5.5 0 0 0 16.5 3c-1.76 0-3 .5-4.5 2-1.5-1.5-2.74-2-4.5-2A5.5 5.5 0 0 0 2 8.5c0 2.3 1.5 4.05 3 5.5l7 7Z",
                    "M3.22 12H9.5l.5-1 2 4.5 2-7 1.5 3.5h5.27"].map { IconPart(d: $0) }
        case .globe:
            return [SVG.circle(12, 12, 10), "M12 2a14.5 14.5 0 0 0 0 20 14.5 14.5 0 0 0 0-20", "M2 12h20"].map { IconPart(d: $0) }
        case .church:
            return ["M10 9h4", "M12 7v5", "M14 22v-4a2 2 0 0 0-4 0v4",
                    "M18 22V5.618a1 1 0 0 0-.553-.894l-4.553-2.277a2 2 0 0 0-1.788 0L6.553 4.724A1 1 0 0 0 6 5.618V22",
                    "m18 7 3.447 1.724a1 1 0 0 1 .553.894V20a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V9.618a1 1 0 0 1 .553-.894L6 7"].map { IconPart(d: $0) }
        case .user:
            return [IconPart(d: "M19 21v-2a4 4 0 0 0-4-4H9a4 4 0 0 0-4 4v2"), IconPart(d: SVG.circle(12, 7, 4))]
        case .building:
            return ["M6 22V4a2 2 0 0 1 2-2h8a2 2 0 0 1 2 2v18Z", "M6 12H4a2 2 0 0 0-2 2v6a2 2 0 0 0 2 2h2",
                    "M18 9h2a2 2 0 0 1 2 2v9a2 2 0 0 1-2 2h-2", "M10 6h4", "M10 10h4", "M10 14h4", "M10 18h4"].map { IconPart(d: $0) }
        case .file:
            return ["M15 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V7Z", "M14 2v4a2 2 0 0 0 2 2h4"].map { IconPart(d: $0) }
        case .diploma:
            return ["M21.42 10.922a1 1 0 0 0-.019-1.838L12.83 5.18a2 2 0 0 0-1.66 0L2.6 9.08a1 1 0 0 0 0 1.832l8.57 3.908a2 2 0 0 0 1.66 0z",
                    "M22 10v6", "M6 12.5V16a6 3 0 0 0 12 0v-3.5"].map { IconPart(d: $0) }
        case .receipt:
            return ["M4 2v20l2-1 2 1 2-1 2 1 2-1 2 1 2-1 2 1V2l-2 1-2-1-2 1-2-1-2 1-2-1-2 1Z",
                    "M16 8h-6a2 2 0 1 0 0 4h4a2 2 0 1 1 0 4H8", "M12 17.5v-11"].map { IconPart(d: $0) }
        case .quote:
            return ["M16 3a2 2 0 0 0-2 2v6a2 2 0 0 0 2 2 1 1 0 0 1 1 1v1a2 2 0 0 1-2 2 1 1 0 0 0-1 1v2a1 1 0 0 0 1 1 6 6 0 0 0 6-6V5a2 2 0 0 0-2-2z",
                    "M5 3a2 2 0 0 0-2 2v6a2 2 0 0 0 2 2 1 1 0 0 1 1 1v1a2 2 0 0 1-2 2 1 1 0 0 0-1 1v2a1 1 0 0 0 1 1 6 6 0 0 0 6-6V5a2 2 0 0 0-2-2z"].map { IconPart(d: $0) }
        case .pen:
            return ["M12 20h9",
                    "M16.376 3.622a1 1 0 0 1 3.002 3.002L7.368 18.635a2 2 0 0 1-.855.506l-2.872.838a.5.5 0 0 1-.62-.62l.838-2.872a2 2 0 0 1 .506-.854z"].map { IconPart(d: $0) }
        case .card:
            return [IconPart(d: SVG.rect(2, 5, 20, 14, rx: 2)), IconPart(d: SVG.line(2, 10, 22, 10))]
        case .bulb:
            return ["M15 14c.2-1 .7-1.7 1.5-2.5 1-.9 1.5-2.2 1.5-3.5A6 6 0 0 0 6 8c0 1 .2 2.2 1.5 3.5.7.7 1.3 1.5 1.5 2.5",
                    "M9 18h6", "M10 22h4"].map { IconPart(d: $0) }
        case .notebook:
            return ["M13.4 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-7.4", "M2 6h4", "M2 10h4", "M2 14h4", "M2 18h4",
                    "M21.378 5.626a1 1 0 1 0-3.004-3.004l-5.01 5.012a2 2 0 0 0-.506.854l-.837 2.87a.5.5 0 0 0 .62.62l2.87-.837a2 2 0 0 0 .854-.506z"].map { IconPart(d: $0) }
        case .map:
            return ["M14.106 5.553a2 2 0 0 0 1.788 0l3.659-1.83A1 1 0 0 1 21 4.619v12.764a1 1 0 0 1-.553.894l-4.553 2.277a2 2 0 0 1-1.788 0l-4.212-2.106a2 2 0 0 0-1.788 0l-3.659 1.83A1 1 0 0 1 3 19.381V6.618a1 1 0 0 1 .553-.894l4.553-2.277a2 2 0 0 1 1.788 0z",
                    "M15 5.764v15", "M9 3.236v15"].map { IconPart(d: $0) }
        case .archive:
            return [SVG.rect(2, 3, 20, 5, rx: 1), "M4 8v11a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8", "M10 12h4"].map { IconPart(d: $0) }
        case .more:
            return [SVG.circle(12, 12, 1), SVG.circle(19, 12, 1), SVG.circle(5, 12, 1)].map { IconPart(d: $0) }
        case .eye:
            return [IconPart(d: "M2.062 12.348a1 1 0 0 1 0-.696 10.75 10.75 0 0 1 19.876 0 1 1 0 0 1 0 .696 10.75 10.75 0 0 1-19.876 0"),
                    IconPart(d: SVG.circle(12, 12, 3))]
        case .download:
            return ["M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4", SVG.polyline([7, 10, 12, 15, 17, 10]),
                    SVG.line(12, 15, 12, 3)].map { IconPart(d: $0) }
        case .clip:
            return [IconPart(d: "m21.44 11.05-9.19 9.19a6 6 0 0 1-8.49-8.49l8.57-8.57A4 4 0 1 1 18 8.84l-8.59 8.57a2 2 0 0 1-2.83-2.83l8.49-8.48")]
        case .image:
            return [SVG.rect(3, 3, 18, 18, rx: 2), SVG.circle(9, 9, 2), "m21 15-3.086-3.086a2 2 0 0 0-2.828 0L6 21"].map { IconPart(d: $0) }
        case .sliders:
            return [SVG.line(21, 4, 14, 4), SVG.line(10, 4, 3, 4), SVG.line(21, 12, 12, 12), SVG.line(8, 12, 3, 12),
                    SVG.line(21, 20, 16, 20), SVG.line(12, 20, 3, 20), SVG.line(14, 2, 14, 6), SVG.line(8, 10, 8, 14),
                    SVG.line(16, 18, 16, 22)].map { IconPart(d: $0) }
        case .minus:
            return [IconPart(d: "M5 12h14")]
        case .chevDown:
            return [IconPart(d: "m6 9 6 6 6-6")]
        case .logout:
            return ["M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4", SVG.polyline([16, 17, 21, 12, 16, 7]),
                    SVG.line(21, 12, 9, 12)].map { IconPart(d: $0) }
        case .bell:
            return ["M6 8a6 6 0 0 1 12 0c0 7 3 9 3 9H3s3-2 3-9", "M10.3 21a1.94 1.94 0 0 0 3.4 0"].map { IconPart(d: $0) }
        case .device:
            return [IconPart(d: SVG.rect(5, 2, 14, 20, rx: 2)), IconPart(d: "M12 18h.01")]
        case .laptop:
            return [IconPart(d: "M20 16V7a2 2 0 0 0-2-2H6a2 2 0 0 0-2 2v9m16 0H4m16 0 1.28 2.55a1 1 0 0 1-.9 1.45H3.62a1 1 0 0 1-.9-1.45L4 16")]
        case .templates:
            return ["M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z", "M13 8H7", "M17 12H7"].map { IconPart(d: $0) }
        case .cloudOff:
            return ["m2 2 20 20", "M5.782 5.782A7 7 0 0 0 9 19h8.5a4.5 4.5 0 0 0 1.307-.193",
                    "M21.532 16.5A4.5 4.5 0 0 0 17.5 10h-1.79A7.008 7.008 0 0 0 10 5.07"].map { IconPart(d: $0) }
        case .undo:
            return ["M9 14 4 9l5-5", "M4 9h10.5a5.5 5.5 0 0 1 5.5 5.5a5.5 5.5 0 0 1-5.5 5.5H11"].map { IconPart(d: $0) }
        case .folder:
            return [IconPart(d: "m6 14 1.5-2.9A2 2 0 0 1 9.24 10H20a2 2 0 0 1 1.94 2.5l-1.54 6a2 2 0 0 1-1.95 1.5H4a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h3.9a2 2 0 0 1 1.69.9l.81 1.2a2 2 0 0 0 1.67.9H18a2 2 0 0 1 2 2v2")]
        case .star:
            return [IconPart(d: "M11.525 2.295a.53.53 0 0 1 .95 0l2.31 4.679a2.123 2.123 0 0 0 1.595 1.16l5.166.756a.53.53 0 0 1 .294.904l-3.736 3.638a2.123 2.123 0 0 0-.611 1.878l.882 5.14a.53.53 0 0 1-.771.56l-4.618-2.428a2.122 2.122 0 0 0-1.973 0L6.396 21.01a.53.53 0 0 1-.77-.56l.881-5.139a2.122 2.122 0 0 0-.611-1.879L2.16 9.795a.53.53 0 0 1 .294-.906l5.165-.755a2.122 2.122 0 0 0 1.597-1.16z")]
        }
    }

    // MARK: Motion

    private enum Springs {
        static let users = Spring1(k: 200, c: 13)
        static let usersT = users.duration
        static let plus = Spring1(k: 100, c: 15)
        static let plusT = plus.duration
        static let gear = Spring1(k: 50, c: 10)
        static let gearT = gear.duration
        static let tag = Spring1(k: 150, c: 15)
        static let tagT = tag.duration
        static let sync = Spring1(k: 250, c: 25)
        static let syncT = sync.duration
        static let ticket = Spring1(k: 300, c: 20)
        static let ticketT = ticket.duration
    }

    /// Spring there, hold, spring back (the prototype's `thereBack`).
    private static func thereBack(_ t: Double, _ s: Spring1, _ d: Double, hold: Double = 0.36) -> Double {
        if t < d { return s(t) }
        if t < d + hold { return 1 }
        if t < 2 * d + hold { return 1 - s(t - d - hold) }
        return 0
    }

    var animates: Bool { duration > 0 }

    /// How long the motion runs.
    var duration: Double {
        switch self {
        case .sun: 1.02
        case .list: 0.32
        case .users: 0.1 + Springs.usersT
        case .flame: 0.55
        case .plane: 1.1
        case .plus: Springs.plusT
        case .x: 0.52
        case .phone: 0.9
        case .check: 0.4
        case .heart: 1.35
        case .arrow: 0.4
        case .gear: Springs.gearT
        case .lock: 1.0
        case .bag: 0.9
        case .euro: 0.9
        case .tag: 0.15 + Springs.tagT
        case .mail: 0.4
        case .note: 1.5
        case .book: 0.6
        case .back, .chev: 0.5
        case .camera: 0.52
        case .search: 1.0
        case .sync: 2 * Springs.syncT + 0.36
        case .pass: 0.5
        case .ticket: 2 * Springs.ticketT + 0.36
        case .shield: 0.4
        default: 0
        }
    }

    /// Where the whole icon turns and scales from.
    var wholeAnchor: UnitPoint { self == .bag ? UnitPoint(x: 0.5, y: 0.17) : .center }

    /// The whole icon at time `t` (seconds since the motion started).
    func whole(_ t: Double) -> IconPose {
        guard t < duration else { return IconPose() }
        var p = IconPose()
        switch self {
        case .plus:
            p.rotation = 180 * Springs.plus(t)
        case .phone:
            let k = seg(t, 0, 0.9, .easeInOut)
            p.rotation = kf(k, [10, 20, -10, 10, 0])
            p.scale = kf(k, [1, 1.1, 1.2, 1.1, 1])
        case .heart:
            let k = seg(t.truncatingRemainder(dividingBy: 0.45), 0, 0.45, .easeInOut)
            p.scale = kf(k, [1, 1.12, 1])
        case .gear:
            p.rotation = 180 * Springs.gear(t)
        case .lock:
            let k = seg(t, 0, 1, Ease(0.4, 0, 0.2, 1))
            p.rotation = kf(k, [-3, 1, -2, 0])
            p.scale = kf(k, [0.95, 1.05, 0.98, 1])
        case .bag:
            p.rotation = kf(seg(t, 0, 0.9, .easeInOut), [0, 4, -3, 2, 0])
        case .note:
            let up = 0.3, hold = 0.9
            if t < up { p.scale = 1 + 0.06 * seg(t, 0, up, .easeOut) }
            else if t < up + hold { p.scale = 1.06 }
            else { p.scale = 1.06 - 0.06 * seg(t, up + hold, up, .easeOut) }
        case .book:
            let k = seg(t, 0, 0.6, .easeInOut)
            let stops = [0, 0.2, 0.5, 0.8, 1.0]
            p.dy = kf(k, [0, -0.8, -2, -0.8, 0], stops)
            p.rotation = kf(k, [0, -8, 8, -8, 0], stops)
            p.scale = kf(k, [1, 1.016, 1.04, 1.016, 1], stops)
        case .search:
            let k = seg(t, 0, 1, .easeInOut)
            p.dy = kf(k, [0, -4, 0, 0])
            p.dx = kf(k, [0, 0, -3, 0])
        case .sync:
            p.rotation = 50 * Self.thereBack(t, Springs.sync, Springs.syncT)
        default:
            break
        }
        return p
    }

    /// One part at time `t`. `index` counts parts with the same tag (rays, strokes, coins…).
    func pose(_ part: IconPart, index: Int, t: Double) -> IconPose {
        guard t < duration else { return IconPose() }
        var p = IconPose()
        switch (self, part.tag) {
        case (.sun, "r"):
            p.opacity = seg(t, Double(index + 1) * 0.09, 0.3)
        case (.list, "c"), (.mail, "c"):
            let d = self == .list ? 0.32 : 0.4
            p.trimTo = seg(t, 0, d, .easeInOut)
            p.opacity = seg(t, 0, self == .list ? 0.3 : 0.4)
        case (.users, "a"):
            p.dx = -6 * (1 - Springs.users(t - 0.1))
            if t < 0.1 { p.dx = -6 }
        case (.flame, "f"):
            p.trimTo = seg(t, 0.1, 0.45, .easeInOut)
            p.opacity = seg(t, 0.1, 0.1)
        case (.plane, "p"):
            let k = seg(t, 0, 1.1, Ease(0.25, 1, 0.5, 1))
            p.dx = -25 * (1 - k)
            p.dy = 10 * (1 - k)
            p.scale = 0.8 + 0.2 * k
            p.rotation = -15 * (1 - k)
            p.opacity = k
        case (.x, "s"):
            let delay = Double(index) * 0.2
            p.trimTo = seg(t, delay, 0.32, .easeOut)
            p.opacity = seg(t, delay, 0.1)
        case (.phone, "w1"), (.phone, "w2"):
            let w = part.tag == "w1" ? 1.0 : 2.0
            let total = 0.6 + w * 0.1
            p.opacity = t < total ? kf(t / total, [1, 0, 0, 1], [0, 0.3 / total, (total - 0.3) / total, 1]) : 1
        case (.check, "c"), (.shield, "c"):
            p.trimTo = seg(t, 0, 0.4, self == .check ? .easeOut : .linear)
            let k = t / 0.4
            p.scale = k < 0.25 ? 0.5 + 0.5 * (k / 0.25) : 1
            p.opacity = k < 0.25 ? k / 0.25 : 1
        case (.arrow, "s"):
            let k = seg(t, 0, 0.4)
            p.trimTo = 1 - (5.0 / 14.0) * kf(k, [0, 1, 0])
        case (.arrow, "h"):
            p.dx = -3 * kf(seg(t, 0, 0.4), [0, 1, 0])
        case (.lock, "k"):
            p.trimTo = kf(seg(t, 0, 1, Ease(0.4, 0, 0.2, 1)), [1, 0.7, 0.7, 1])
        case (.euro, "m"):
            p.trimTo = seg(t, 0, 0.6, .easeInOut)
            p.opacity = seg(t, 0, 0.1)
        case (.euro, "s"):
            let k = seg(t, 0.5, 0.4, .easeOut)
            p.trimFrom = 1 - k
            p.trimTo = 1
            p.opacity = seg(t, 0.5, 0.1)
        case (.tag, "c"):
            let delay = Double(index) * 0.15
            let k = t < delay ? 0 : Springs.tag(t - delay)
            p.dy = -20 * (1 - k)
            p.opacity = min(max(k, 0), 1)
        case (.note, "l"):
            p.trimTo = kf(seg(t, 0.3 + Double(index) * 0.2, 0.7, .easeInOut), [1, 0, 1])
        case (.back, "n"):
            p.dx = -2 * kf(seg(t, 0, 0.5), [0, 1, 0], [0, 0.4, 1])
        case (.chev, "n"):
            p.dx = 2 * kf(seg(t, 0, 0.5), [0, 1, 0], [0, 0.4, 1])
        case (.camera, "c"):
            p.scale = kf(seg(t, 0, 0.52, .easeInOut), [1, 0.55, 1.15, 1])
        case (.pass, "d0"), (.pass, "d1"), (.pass, "d2"):
            let step = Double(part.tag.last.flatMap { Int(String($0)) } ?? 0) * 0.1
            p.trimTo = seg(t, step, 0.3)
            p.opacity = seg(t, step, 0.3)
        case (.ticket, "lt"):
            p.dx = -3 * Self.thereBack(t, Springs.ticket, Springs.ticketT)
        case (.ticket, "rt"):
            let k = Self.thereBack(t, Springs.ticket, Springs.ticketT)
            p.dx = 3 * k
            p.rotation = 4 * k
        default:
            break
        }
        return p
    }
}

/// An icon at time `t` of its motion.
struct IconCanvas: View {
    let icon: Icon
    let t: Double
    var weight: CGFloat? = nil

    var body: some View {
        let whole = icon.whole(t)
        let parts = icon.parts
        // Index each part among the parts with the same tag (ray 0, 1, 2…).
        let indexes: [Int] = parts.indices.map { i in parts[..<i].filter { $0.tag == parts[i].tag }.count }
        GeometryReader { geo in
            ZStack {
                ForEach(Array(parts.enumerated()), id: \.offset) { i, part in
                    let pose = icon.pose(part, index: indexes[i], t: t)
                    SVGShape(d: part.d)
                        .trim(from: pose.trimFrom, to: max(pose.trimTo, pose.trimFrom))
                        .stroke(style: StrokeStyle(lineWidth: weight ?? icon.weight, lineCap: .round, lineJoin: .round))
                        .frame(width: 24, height: 24)
                        .opacity(pose.opacity)
                        .rotationEffect(.degrees(pose.rotation), anchor: part.anchor)
                        .scaleEffect(pose.scale, anchor: part.anchor)
                        .offset(x: pose.dx, y: pose.dy)
                }
            }
            .frame(width: 24, height: 24)
            .rotationEffect(.degrees(whole.rotation), anchor: icon.wholeAnchor)
            .scaleEffect(whole.scale, anchor: icon.wholeAnchor)
            .offset(x: whole.dx, y: whole.dy)
            .scaleEffect(geo.size.width / 24, anchor: .topLeading)
        }
    }
}

/// A Lucide icon that plays its lucide-animated motion each time `trigger` changes.
/// Draws in the current foreground style.
struct AnimatedIcon: View {
    let icon: Icon
    var size: CGFloat = 24
    var trigger: Int = 0
    var weight: CGFloat? = nil

    init(_ icon: Icon, size: CGFloat = 24, trigger: Int = 0, weight: CGFloat? = nil) {
        self.icon = icon
        self.size = size
        self.trigger = trigger
        self.weight = weight
    }

    var body: some View {
        Group {
            if icon.animates {
                Clock(trigger: trigger, duration: icon.duration) { t in
                    IconCanvas(icon: icon, t: t, weight: weight)
                }
            } else {
                IconCanvas(icon: icon, t: clockRest, weight: weight)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

// MARK: - Icons for the app's own lists

extension Area {
    var icon: Icon {
        switch self {
        case .visa: .plane
        case .admin: .building
        case .finance: .euro
        case .support: .users
        case .newsletter: .mail
        case .selling: .tag
        case .packing: .bag
        case .housing: .house
        case .health: .health
        case .insurance: .shield
        case .church: .church
        case .travel: .map
        case .ywam: .globe
        case .personal: .user
        case .other: .note
        }
    }
}

extension DocumentKind {
    var icon: Icon {
        switch self {
        case .passport, .id: .pass
        case .visa: .note
        case .insurance: .shield
        case .ticket: .ticket
        case .bank: .card
        case .medical: .health
        case .diploma: .diploma
        case .reference: .quote
        case .contract: .pen
        case .receipt: .receipt
        case .letter: .mail
        case .other: .file
        }
    }
}

extension NoteKind {
    var icon: Icon {
        switch self {
        case .note: .note
        case .prayer: .flame
        case .journal: .notebook
        case .meeting: .users
        case .idea: .bulb
        }
    }
}

extension AnyRecord {
    var icon: Icon {
        switch self {
        case .task: .list
        case .checklist: .list
        case .partner: .user
        case .gift: .gift
        case .budget: .euro
        case .sell: .tag
        case .packing: .bag
        case .note(let n): n.kindValue.icon
        case .document(let d): d.kindValue.icon
        case .contact: .user
        case .newsletter: .mail
        }
    }
}
