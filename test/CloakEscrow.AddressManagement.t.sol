// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {CloakEscrow} from "../src/CloakEscrow.sol";
import {CloakEscrowFixtures} from "./fixtures/CloakEscrowFixtures.sol";

contract CloakEscrowAddressManagementTest is Test, CloakEscrowFixtures {
    EscrowFixture public fixture;

    event MerchantAddressUpdated(address oldAddress, address newAddress);
    event PlatformAddressUpdated(address oldAddress, address newAddress);

    function setUp() public {
        setupMockUsers();
        fixture = createSimpleFixture();
    }

    // ============ Merchant Address Tests ============

    function test_GetMerchantAddress_InitialValue() public view {
        assertEq(fixture.escrow.getMerchantAddress(), MERCHANT);
    }

    function test_GetMerchantAddress_MultipleTokens() public {
        (EscrowFixture memory usdcFixture, EscrowFixture memory daiFixture, EscrowFixture memory wbtcFixture) =
            createMultiTokenFixtures();

        assertEq(usdcFixture.escrow.getMerchantAddress(), MERCHANT);
        assertEq(daiFixture.escrow.getMerchantAddress(), MERCHANT);
        assertEq(wbtcFixture.escrow.getMerchantAddress(), MERCHANT);
    }

    function test_SetMerchantAddress_Valid() public {
        vm.prank(OWNER);
        vm.expectEmit(true, true, true, true);
        emit MerchantAddressUpdated(MERCHANT, NEW_MERCHANT);
        fixture.escrow.setMerchantAddress(NEW_MERCHANT);

        assertEq(fixture.escrow.getMerchantAddress(), NEW_MERCHANT);
    }

    function test_SetMerchantAddress_RevertZeroAddress() public {
        vm.prank(OWNER);
        vm.expectRevert(CloakEscrow.InvalidAddress.selector);
        fixture.escrow.setMerchantAddress(address(0));
    }

    function test_SetMerchantAddress_RevertNotOwner() public {
        vm.prank(USER);
        vm.expectRevert();
        fixture.escrow.setMerchantAddress(NEW_MERCHANT);
    }

    function test_SetMerchantAddress_WorksWhenPaused() public {
        vm.prank(OWNER);
        fixture.escrow.pause();

        vm.prank(OWNER);
        fixture.escrow.setMerchantAddress(NEW_MERCHANT);
        assertEq(fixture.escrow.getMerchantAddress(), NEW_MERCHANT);
    }

    function test_SetMerchantAddress_MultipleChanges() public {
        address[] memory merchants = new address[](3);
        merchants[0] = NEW_MERCHANT;
        merchants[1] = address(0x100);
        merchants[2] = address(0x200);

        for (uint256 i = 0; i < merchants.length; i++) {
            vm.prank(OWNER);
            fixture.escrow.setMerchantAddress(merchants[i]);
            assertEq(fixture.escrow.getMerchantAddress(), merchants[i]);
        }
    }

    // ============ Platform Address Tests ============

    function test_GetPlatformAddress_InitialValue() public view {
        assertEq(fixture.escrow.getPlatformAddress(), PLATFORM);
    }

    function test_GetPlatformAddress_MultipleTokens() public {
        (EscrowFixture memory usdcFixture, EscrowFixture memory daiFixture, EscrowFixture memory wbtcFixture) =
            createMultiTokenFixtures();

        assertEq(usdcFixture.escrow.getPlatformAddress(), PLATFORM);
        assertEq(daiFixture.escrow.getPlatformAddress(), PLATFORM);
        assertEq(wbtcFixture.escrow.getPlatformAddress(), PLATFORM);
    }

    function test_SetPlatformAddress_Valid() public {
        vm.prank(OWNER);
        vm.expectEmit(true, true, true, true);
        emit PlatformAddressUpdated(PLATFORM, NEW_PLATFORM);
        fixture.escrow.setPlatformAddress(NEW_PLATFORM);

        assertEq(fixture.escrow.getPlatformAddress(), NEW_PLATFORM);
    }

    function test_SetPlatformAddress_RevertZeroAddress() public {
        vm.prank(OWNER);
        vm.expectRevert(CloakEscrow.InvalidAddress.selector);
        fixture.escrow.setPlatformAddress(address(0));
    }

    function test_SetPlatformAddress_RevertNotOwner() public {
        vm.prank(USER);
        vm.expectRevert();
        fixture.escrow.setPlatformAddress(NEW_PLATFORM);
    }

    function test_SetPlatformAddress_WorksWhenPaused() public {
        vm.prank(OWNER);
        fixture.escrow.pause();

        vm.prank(OWNER);
        fixture.escrow.setPlatformAddress(NEW_PLATFORM);
        assertEq(fixture.escrow.getPlatformAddress(), NEW_PLATFORM);
    }

    function test_SetPlatformAddress_MultipleChanges() public {
        address[] memory platforms = new address[](3);
        platforms[0] = NEW_PLATFORM;
        platforms[1] = address(0x300);
        platforms[2] = address(0x400);

        for (uint256 i = 0; i < platforms.length; i++) {
            vm.prank(OWNER);
            fixture.escrow.setPlatformAddress(platforms[i]);
            assertEq(fixture.escrow.getPlatformAddress(), platforms[i]);
        }
    }

    // ============ Combined Address Management Tests ============

    function test_SetBothAddresses_Simultaneously() public {
        vm.prank(OWNER);
        fixture.escrow.setMerchantAddress(NEW_MERCHANT);

        vm.prank(OWNER);
        fixture.escrow.setPlatformAddress(NEW_PLATFORM);

        assertEq(fixture.escrow.getMerchantAddress(), NEW_MERCHANT);
        assertEq(fixture.escrow.getPlatformAddress(), NEW_PLATFORM);
    }

    function test_AddressManagement_EmergencyScenario() public {
        // Simulate emergency: pause contract and update addresses
        vm.prank(OWNER);
        fixture.escrow.pause();

        // Update both addresses while paused
        vm.prank(OWNER);
        fixture.escrow.setMerchantAddress(NEW_MERCHANT);

        vm.prank(OWNER);
        fixture.escrow.setPlatformAddress(NEW_PLATFORM);

        // Verify addresses are updated
        assertEq(fixture.escrow.getMerchantAddress(), NEW_MERCHANT);
        assertEq(fixture.escrow.getPlatformAddress(), NEW_PLATFORM);
        assertTrue(fixture.escrow.paused());
    }

    function testFuzz_SetMerchantAddress_ValidAddresses(address newMerchant) public {
        vm.assume(newMerchant != address(0));

        vm.prank(OWNER);
        fixture.escrow.setMerchantAddress(newMerchant);
        assertEq(fixture.escrow.getMerchantAddress(), newMerchant);
    }

    function testFuzz_SetPlatformAddress_ValidAddresses(address newPlatform) public {
        vm.assume(newPlatform != address(0));

        vm.prank(OWNER);
        fixture.escrow.setPlatformAddress(newPlatform);
        assertEq(fixture.escrow.getPlatformAddress(), newPlatform);
    }

    function test_AddressEvents_EmittedCorrectly() public {
        // Test merchant address event
        vm.prank(OWNER);
        vm.expectEmit(true, true, true, true);
        emit MerchantAddressUpdated(MERCHANT, NEW_MERCHANT);
        fixture.escrow.setMerchantAddress(NEW_MERCHANT);

        // Test platform address event
        vm.prank(OWNER);
        vm.expectEmit(true, true, true, true);
        emit PlatformAddressUpdated(PLATFORM, NEW_PLATFORM);
        fixture.escrow.setPlatformAddress(NEW_PLATFORM);
    }
}
