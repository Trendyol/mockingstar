import XCTest
@testable import MockingStarCore

final class ModifierActivationStoreTests: XCTestCase {
    private var store: ModifierActivationStore!

    override func setUp() async throws {
        store = ModifierActivationStore()
    }

    func test_replaceActiveIds_ReturnsDiffAndIsolatesDevices() async {
        let first = await store.replaceActiveIds(domain: "Dev", deviceId: "A", ids: ["one", "two"])
        XCTAssertEqual(first.enabledIds, ["one", "two"])
        XCTAssertTrue(first.disabledIds.isEmpty)

        let second = await store.replaceActiveIds(domain: "Dev", deviceId: "A", ids: ["two", "three"])
        XCTAssertEqual(second.enabledIds, ["three"])
        XCTAssertEqual(second.disabledIds, ["one"])

        await store.replaceActiveIds(domain: "Dev", deviceId: "B", ids: ["beta"])
        let aIds = await store.activeModifierIds(domain: "Dev", deviceId: "A")
        let bIds = await store.activeModifierIds(domain: "Dev", deviceId: "B")
        XCTAssertEqual(aIds, Set(["two", "three"]))
        XCTAssertEqual(bIds, Set(["beta"]))
    }

    func test_removeModifierId_PurgesAcrossDevices() async {
        await store.replaceActiveIds(domain: "Dev", deviceId: "A", ids: ["shared", "a-only"])
        await store.replaceActiveIds(domain: "Dev", deviceId: "B", ids: ["shared", "b-only"])

        let devices = await store.removeModifierId(domain: "Dev", id: "shared")
        XCTAssertEqual(devices, ["A", "B"])

        let aIds = await store.activeModifierIds(domain: "Dev", deviceId: "A")
        let bIds = await store.activeModifierIds(domain: "Dev", deviceId: "B")
        XCTAssertEqual(aIds, Set(["a-only"]))
        XCTAssertEqual(bIds, Set(["b-only"]))
    }

    func test_modifierRename_MigratesEveryAffectedDeviceAndNotOtherDomains() async {
        await store.replaceActiveIds(domain: "Dev", deviceId: "A", ids: ["old", "a"])
        await store.replaceActiveIds(domain: "Dev", deviceId: "B", ids: ["old", "b"])
        await store.replaceActiveIds(domain: "Dev", deviceId: "C", ids: ["c"])
        await store.replaceActiveIds(domain: "Prod", deviceId: "A", ids: ["old"])

        let migration = await store.prepareModifierRename(domain: "Dev", from: "old", to: "new")
        await store.commitModifierRename(migration)

        let aIds = await store.activeModifierIds(domain: "Dev", deviceId: "A")
        let bIds = await store.activeModifierIds(domain: "Dev", deviceId: "B")
        let cIds = await store.activeModifierIds(domain: "Dev", deviceId: "C")
        let prodIds = await store.activeModifierIds(domain: "Prod", deviceId: "A")
        XCTAssertEqual(aIds, Set(["new", "a"]))
        XCTAssertEqual(bIds, Set(["new", "b"]))
        XCTAssertEqual(cIds, Set(["c"]))
        XCTAssertEqual(prodIds, Set(["old"]))
    }

    func test_modifierRename_RollbackRestoresOldId() async {
        await store.replaceActiveIds(domain: "Dev", deviceId: "A", ids: ["old"])
        let migration = await store.prepareModifierRename(domain: "Dev", from: "old", to: "new")

        await store.rollbackModifierRename(migration)

        let aIds = await store.activeModifierIds(domain: "Dev", deviceId: "A")
        XCTAssertEqual(aIds, Set(["old"]))
    }

    func test_activeModifierIds_UnknownDeviceInheritsDefaultEmptyDeviceSet() async {
        await store.replaceActiveIds(domain: "Dev", deviceId: "", ids: ["ui-mod"])
        await store.replaceActiveIds(domain: "Dev", deviceId: "maestro-1", ids: ["maestro-only"])

        let unknownClient = await store.activeModifierIds(
            domain: "Dev",
            deviceId: "f0b2e2ae-aed6-4b67-a189-987ead693cbb"
        )
        XCTAssertEqual(unknownClient, Set(["ui-mod"]))

        let maestro = await store.activeModifierIds(domain: "Dev", deviceId: "maestro-1")
        XCTAssertEqual(maestro, Set(["maestro-only"]))
    }

    func test_activeModifierIds_ExplicitEmptySetDoesNotFallBackToDefault() async {
        await store.replaceActiveIds(domain: "Dev", deviceId: "", ids: ["ui-mod"])
        await store.replaceActiveIds(domain: "Dev", deviceId: "maestro-1", ids: [])

        let maestro = await store.activeModifierIds(domain: "Dev", deviceId: "maestro-1")
        XCTAssertEqual(maestro, Set())
    }
}
