//
//  GridRevealTests.swift
//  The subdivision and the pacing, checked against `components/ui/grid-reveal.tsx`.
//

@testable import RareUI
import Testing

@Suite("Grid reveal subdivision")
struct GridRevealTreeTests {
    @Test("the tree ends up with the number of cells it was asked for")
    func cellCount() {
        let tree = gridRevealBuildTree(aspect: 1)
        // Every split turns one cell into two, so a tree of n leaves has n minus one
        // branches, and the count rises one at a time rather than doubling.
        #expect(tree.branches.count == gridRevealCells - 1)
    }

    @Test("the cells stay roughly square, whatever shape the frame is")
    func squareness() {
        for aspect in [0.5, 1.0, 1.78, 3.0] {
            let tree = gridRevealBuildTree(aspect: aspect)
            var leaves: [GridRevealCell] = []
            func collect(_ cell: GridRevealCell) {
                guard let children = cell.children else {
                    leaves.append(cell)
                    return
                }
                collect(children.0)
                collect(children.1)
            }
            collect(tree.root)

            for leaf in leaves {
                let ratio = (leaf.width * aspect) / leaf.height
                #expect(ratio > 0.4 && ratio < 2.6, "a cell came out at \\(ratio) to one")
            }
        }
    }

    @Test("the first few cells are already apart before the reveal starts")
    func openingCells() {
        let tree = gridRevealBuildTree(aspect: 1)
        let early = tree.branches.prefix(gridRevealOpeningCells - 1)
        #expect(early.allSatisfy { $0.splitAt < 0 })
        // So the reveal never begins as a single rectangle sitting still.
        #expect(tree.branches[gridRevealOpeningCells - 1].splitAt > 0)
    }

    @Test("the splits are spread out and finish short of the end")
    func pacing() throws {
        let tree = gridRevealBuildTree(aspect: 1)
        let scheduled = tree.branches.map(\.splitAt).filter { $0 > 0 }.sorted()
        #expect(try #require(scheduled.first) > 0)
        #expect(try #require(scheduled.last) <= gridRevealLastSplit + 1e-9)
        // Short of the end on purpose: the picture needs somewhere to arrive.
        #expect(gridRevealLastSplit < 1)
    }

    @Test("every cell covers exactly the space its parent gave it")
    func coversTheParent() {
        let tree = gridRevealBuildTree(aspect: 1)
        func check(_ cell: GridRevealCell) {
            guard let children = cell.children else { return }
            let area = children.0.width * children.0.height + children.1.width * children.1.height
            #expect(abs(area - cell.width * cell.height) < 1e-9)
            check(children.0)
            check(children.1)
        }
        check(tree.root)
    }

    @Test("reordering by detail keeps the pacing and only changes the order")
    func reordering() {
        let tree = gridRevealBuildTree(aspect: 1)
        let before = tree.branches.map(\.splitAt).sorted()

        // Giving alternate cells something to be interested in.
        for (index, cell) in tree.branches.enumerated() {
            cell.detail = Double(index % 7)
        }
        gridRevealOrderByDetail(tree.branches, openedBefore: 0)

        let after = tree.branches.map(\.splitAt).sorted()
        #expect(before == after, "the same moments, handed to different cells")
    }

    @Test("a cell never splits before its parent has")
    func parentsFirst() {
        let tree = gridRevealBuildTree(aspect: 1)
        for (index, cell) in tree.branches.enumerated() {
            cell.detail = Double((index * 37) % 11)
        }
        gridRevealOrderByDetail(tree.branches, openedBefore: 0)

        for cell in tree.branches {
            guard let parent = cell.parent, parent.children != nil else { continue }
            #expect(parent.splitAt <= cell.splitAt, "a cell was told to split before it existed")
        }
    }
}

@Suite("Grid reveal pacing")
struct GridRevealPacingTests {
    @Test("a self-paced reveal creeps toward its ceiling and never reaches it")
    func creeps() {
        var previous = -1.0
        for seconds in stride(from: 0.0, through: 60, by: 0.5) {
            let progress = gridRevealSelfPaced(elapsed: seconds, duration: 6)
            #expect(progress > previous, "it should always be moving")
            #expect(progress < gridRevealHold, "and never arrive on its own")
            previous = progress
        }
    }

    @Test("it holds short of the end, so the picture has somewhere to arrive")
    func holdsShort() {
        #expect(gridRevealHold < 1)
        #expect(gridRevealWaitCap < gridRevealHold)
    }

    @Test("a duration of nothing does not divide by nothing")
    func guardedDuration() {
        #expect(gridRevealSelfPaced(elapsed: 1, duration: 0).isFinite)
        #expect(gridRevealSelfPaced(elapsed: 1, duration: -5).isFinite)
    }

    @Test("the smooth step eases at both ends and is flat outside them")
    func smoothstep() {
        #expect(gridRevealSmoothstep(0.35, 0.75, 0.2) == 0)
        #expect(gridRevealSmoothstep(0.35, 0.75, 0.9) == 1)
        #expect(abs(gridRevealSmoothstep(0.35, 0.75, 0.55) - 0.5) < 1e-9)
    }

    @Test("the placeholder grey breathes rather than sitting still")
    func greyBreathes() {
        let still = gridRevealGrey(tone: 0.5, dark: false, clock: 0)
        let later = gridRevealGrey(tone: 0.5, dark: false, clock: 1)
        #expect(still != later, "a grid of flat rectangles reads as a broken image")
        // But only just: three levels either way out of two hundred and fifty-five.
        #expect(abs(still - later) < 7)
    }

    @Test("the dark appearance is dark and the light one is light")
    func appearances() {
        #expect(gridRevealGrey(tone: 0.5, dark: true, clock: 0) < 60)
        #expect(gridRevealGrey(tone: 0.5, dark: false, clock: 0) > 200)
    }
}
