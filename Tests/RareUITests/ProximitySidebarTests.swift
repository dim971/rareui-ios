//
//  ProximitySidebarTests.swift
//  How far a dash swells for a given distance, checked against the mapping in
//  `components/ui/proximity-sidebar.tsx`.
//

@testable import RareUI
import Testing

@Suite("Proximity dashes")
struct ProximityDashTests {
    @Test("a dash under the pointer is at its full width")
    func onTop() {
        for kind in ProximitySectionKind.allCases {
            #expect(proximityDashWidth(distance: 0, kind: kind) == kind.base + kind.bump)
        }
    }

    @Test("a dash out of reach is at rest")
    func outOfReach() {
        for kind in ProximitySectionKind.allCases {
            #expect(proximityDashWidth(distance: proximityRadius, kind: kind) == kind.base)
            #expect(proximityDashWidth(distance: 500, kind: kind) == kind.base)
        }
    }

    @Test("the swelling is symmetric, since above and below are the same distance")
    func symmetric() {
        for kind in ProximitySectionKind.allCases {
            for distance in stride(from: 0.0, through: 60, by: 5) {
                #expect(
                    proximityDashWidth(distance: distance, kind: kind)
                        == proximityDashWidth(distance: -distance, kind: kind)
                )
            }
        }
    }

    @Test("it only ever narrows as the pointer moves away")
    func monotonic() {
        var previous = Double.infinity
        for distance in stride(from: 0.0, through: proximityRadius, by: 1) {
            let width = proximityDashWidth(distance: distance, kind: .title)
            #expect(width <= previous)
            previous = width
        }
    }

    @Test("a dash never grows past the width they are all measured against")
    func withinTheColumn() {
        for kind in ProximitySectionKind.allCases {
            #expect(kind.base + kind.bump <= proximityMaxDashWidth)
        }
    }

    @Test("the outline reads as a hierarchy: a title is wider and stronger than a body line")
    func hierarchy() {
        #expect(ProximitySectionKind.title.base > ProximitySectionKind.subtitle.base)
        #expect(ProximitySectionKind.subtitle.base > ProximitySectionKind.section.base)
        #expect(ProximitySectionKind.section.base > ProximitySectionKind.body.base)
        #expect(ProximitySectionKind.title.isProminent)
        #expect(ProximitySectionKind.subtitle.isProminent)
        #expect(!ProximitySectionKind.section.isProminent)
        #expect(!ProximitySectionKind.body.isProminent)
    }
}
