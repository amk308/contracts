// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {CloakEscrow} from "../src/CloakEscrow.sol";
import {CloakEscrowFixtures} from "./fixtures/CloakEscrowFixtures.sol";

contract CloakEscrowPausableTest is Test, CloakEscrowFixtures {
    EscrowFixture public fixture;

    event ContractPaused(address account);
    event ContractUnpaused(address account);

    function setUp() public {
        setupMockUsers();
        fixture = createSimpleFixture();
    }

    // ============ Pause Function Tests ============

    function test_Pause_Success() public {
        assertFalse(fixture.escrow.paused());

        vm.prank(OWNER);
        vm.expectEmit(true, true, true, true);
        emit ContractPaused(OWNER);
        fixture.escrow.pause();

        assertTrue(fixture.escrow.paused());
    }

    function test_Pause_RevertNotOwner() public {
        vm.prank(USER);
        vm.expectRevert();
        fixture.escrow.pause();

        assertFalse(fixture.escrow.paused());
    }

    function test_Pause_RevertAlreadyPaused() public {
        vm.prank(OWNER);
        fixture.escrow.pause();

        vm.prank(OWNER);
        vm.expectRevert();
        fixture.escrow.pause();
    }

    // ============ Unpause Function Tests ============

    function test_Unpause_Success() public {
        vm.prank(OWNER);
        fixture.escrow.pause();
        assertTrue(fixture.escrow.paused());

        vm.prank(OWNER);
        vm.expectEmit(true, true, true, true);
        emit ContractUnpaused(OWNER);
        fixture.escrow.unpause();

        assertFalse(fixture.escrow.paused());
    }

    function test_Unpause_RevertNotOwner() public {
        vm.prank(OWNER);
        fixture.escrow.pause();

        vm.prank(USER);
        vm.expectRevert();
        fixture.escrow.unpause();

        assertTrue(fixture.escrow.paused());
    }

    function test_Unpause_RevertNotPaused() public {
        assertFalse(fixture.escrow.paused());

        vm.prank(OWNER);
        vm.expectRevert();
        fixture.escrow.unpause();
    }

    // ============ Pause State Tests ============

    function test_PauseState_InitiallyNotPaused() public view {
        assertFalse(fixture.escrow.paused());
    }

    function test_PauseState_MultiplePauseUnpauseCycles() public {
        // Cycle 1
        vm.prank(OWNER);
        fixture.escrow.pause();
        assertTrue(fixture.escrow.paused());

        vm.prank(OWNER);
        fixture.escrow.unpause();
        assertFalse(fixture.escrow.paused());

        // Cycle 2
        vm.prank(OWNER);
        fixture.escrow.pause();
        assertTrue(fixture.escrow.paused());

        vm.prank(OWNER);
        fixture.escrow.unpause();
        assertFalse(fixture.escrow.paused());
    }

    // ============ Function Behavior When Paused ============

    function test_SetPlatformFee_BlockedWhenPaused() public {
        vm.prank(OWNER);
        fixture.escrow.pause();

        vm.prank(OWNER);
        vm.expectRevert();
        fixture.escrow.setPlatformFee(500);
    }

    function test_SetPlatformFee_WorksWhenUnpaused() public {
        vm.prank(OWNER);
        fixture.escrow.pause();

        vm.prank(OWNER);
        fixture.escrow.unpause();

        vm.prank(OWNER);
        fixture.escrow.setPlatformFee(500);
        assertEq(fixture.escrow.getPlatformFee(), 500);
    }

    function test_Distribute_BlockedWhenPaused() public {
        uint256 amount = getStandardTestAmount(6);
        fundEscrow(fixture, amount);

        vm.prank(OWNER);
        fixture.escrow.pause();

        vm.expectRevert();
        fixture.escrow.distribute();
    }

    function test_Distribute_WorksWhenUnpaused() public {
        uint256 amount = getStandardTestAmount(6);
        fundEscrow(fixture, amount);

        vm.prank(OWNER);
        fixture.escrow.pause();

        vm.prank(OWNER);
        fixture.escrow.unpause();

        fixture.escrow.distribute();

        // Verify distribution worked
        assertTrue(fixture.token.balanceOf(PLATFORM) > 0);
        assertTrue(fixture.token.balanceOf(MERCHANT) > 0);
    }

    function test_SetMerchantAddress_WorksWhenPaused() public {
        vm.prank(OWNER);
        fixture.escrow.pause();

        vm.prank(OWNER);
        fixture.escrow.setMerchantAddress(NEW_MERCHANT);
        assertEq(fixture.escrow.getMerchantAddress(), NEW_MERCHANT);
    }

    function test_SetPlatformAddress_WorksWhenPaused() public {
        vm.prank(OWNER);
        fixture.escrow.pause();

        vm.prank(OWNER);
        fixture.escrow.setPlatformAddress(NEW_PLATFORM);
        assertEq(fixture.escrow.getPlatformAddress(), NEW_PLATFORM);
    }

    // ============ Getter Functions When Paused ============

    function test_GetterFunctions_WorkWhenPaused() public {
        vm.prank(OWNER);
        fixture.escrow.pause();

        // All getter functions should work when paused
        assertEq(fixture.escrow.getPlatformFee(), 250);
        assertEq(fixture.escrow.getMerchantAddress(), MERCHANT);
        assertEq(fixture.escrow.getPlatformAddress(), PLATFORM);
        assertTrue(fixture.escrow.paused());
    }

    // ============ Emergency Scenario Tests ============

    function test_EmergencyScenario_CompromisedAddresses() public {
        uint256 amount = getStandardTestAmount(6);
        fundEscrow(fixture, amount);

        // Step 1: Owner detects compromise and pauses
        vm.prank(OWNER);
        fixture.escrow.pause();

        // Step 2: Verify distribution is blocked
        vm.expectRevert();
        fixture.escrow.distribute();

        // Step 3: Owner updates compromised addresses while paused
        vm.prank(OWNER);
        fixture.escrow.setMerchantAddress(NEW_MERCHANT);
        vm.prank(OWNER);
        fixture.escrow.setPlatformAddress(NEW_PLATFORM);

        // Step 4: Owner unpauses with safe addresses
        vm.prank(OWNER);
        fixture.escrow.unpause();

        // Step 5: Distribution works with new addresses
        fixture.escrow.distribute();

        // Verify funds went to new addresses
        assertTrue(fixture.token.balanceOf(NEW_PLATFORM) > 0);
        assertTrue(fixture.token.balanceOf(NEW_MERCHANT) > 0);
        assertEq(fixture.token.balanceOf(PLATFORM), 0);
        assertEq(fixture.token.balanceOf(MERCHANT), 0);
    }

    function test_EmergencyScenario_FeeManipulationPrevention() public {
        // Malicious actor cannot change fees when paused
        vm.prank(OWNER);
        fixture.escrow.pause();

        // Even owner cannot change fees when paused (prevents accidental changes)
        vm.prank(OWNER);
        vm.expectRevert();
        fixture.escrow.setPlatformFee(5000); // Attempt to set max fee

        // Verify fee remains unchanged
        assertEq(fixture.escrow.getPlatformFee(), 250);
    }

    // ============ Multi-Contract Pause Tests ============

    function test_MultipleContracts_IndependentPauseStates() public {
        (EscrowFixture memory usdcFixture, EscrowFixture memory daiFixture, EscrowFixture memory wbtcFixture) =
            createMultiTokenFixtures();

        // Pause only USDC contract
        vm.prank(OWNER);
        usdcFixture.escrow.pause();

        // Verify pause states
        assertTrue(usdcFixture.escrow.paused());
        assertFalse(daiFixture.escrow.paused());
        assertFalse(wbtcFixture.escrow.paused());

        // Verify only USDC distribution is blocked
        uint256 amount = 1000 * 10 ** 6; // 1000 tokens

        fundEscrow(usdcFixture, amount);
        fundEscrow(daiFixture, amount * 10 ** 12); // Adjust for 18 decimals
        fundEscrow(wbtcFixture, amount / 10000); // Adjust for 8 decimals

        // USDC distribution should fail
        vm.expectRevert();
        usdcFixture.escrow.distribute();

        // Other distributions should work
        daiFixture.escrow.distribute();
        wbtcFixture.escrow.distribute();
    }

    // ============ Event Emission Tests ============

    function test_PauseEvents_EmittedCorrectly() public {
        // Test pause event
        vm.prank(OWNER);
        vm.expectEmit(true, true, true, true);
        emit ContractPaused(OWNER);
        fixture.escrow.pause();

        // Test unpause event
        vm.prank(OWNER);
        vm.expectEmit(true, true, true, true);
        emit ContractUnpaused(OWNER);
        fixture.escrow.unpause();
    }

    function test_PauseEvents_WithDifferentCallers() public {
        // Create escrow with different owner
        address differentOwner = address(0x999);
        CloakEscrow newEscrow = new CloakEscrow(MERCHANT, address(fixture.token), PLATFORM, differentOwner);

        // Test pause event with different owner
        vm.prank(differentOwner);
        vm.expectEmit(true, true, true, true);
        emit ContractPaused(differentOwner);
        newEscrow.pause();

        // Test unpause event with different owner
        vm.prank(differentOwner);
        vm.expectEmit(true, true, true, true);
        emit ContractUnpaused(differentOwner);
        newEscrow.unpause();
    }

    // ============ Access Control Tests ============

    function test_PauseAccess_OnlyOwnerCanPause() public {
        address[] memory nonOwners = new address[](3);
        nonOwners[0] = MERCHANT;
        nonOwners[1] = PLATFORM;
        nonOwners[2] = USER;

        for (uint256 i = 0; i < nonOwners.length; i++) {
            vm.prank(nonOwners[i]);
            vm.expectRevert();
            fixture.escrow.pause();

            assertFalse(fixture.escrow.paused());
        }
    }

    function test_UnpauseAccess_OnlyOwnerCanUnpause() public {
        vm.prank(OWNER);
        fixture.escrow.pause();

        address[] memory nonOwners = new address[](3);
        nonOwners[0] = MERCHANT;
        nonOwners[1] = PLATFORM;
        nonOwners[2] = USER;

        for (uint256 i = 0; i < nonOwners.length; i++) {
            vm.prank(nonOwners[i]);
            vm.expectRevert();
            fixture.escrow.unpause();

            assertTrue(fixture.escrow.paused());
        }
    }
}
