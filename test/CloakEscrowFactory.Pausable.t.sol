// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {CloakEscrowFactory} from "../src/CloakEscrowFactory.sol";
import {CloakEscrowFactoryFixtures} from "./fixtures/CloakEscrowFactoryFixtures.sol";

contract CloakEscrowFactoryPausableTest is Test, CloakEscrowFactoryFixtures {
    FactoryFixture public fixture;

    function setUp() public {
        setupMockUsers();
        fixture = createFactoryFixture();
    }

    // ============ Pause Function Tests ============

    function test_Pause_Success() public {
        assertFalse(fixture.factory.paused());

        // No prank needed - test contract is owner
        fixture.factory.pause();

        assertTrue(fixture.factory.paused());
    }

    function test_Pause_RevertNotOwner() public {
        vm.prank(USER);
        vm.expectRevert();
        fixture.factory.pause();

        assertFalse(fixture.factory.paused());
    }

    function test_Pause_RevertAlreadyPaused() public {
        // No prank needed - test contract is owner
        fixture.factory.pause();

        // No prank needed - test contract is owner
        vm.expectRevert();
        fixture.factory.pause();
    }

    // ============ Unpause Function Tests ============

    function test_Unpause_Success() public {
        // First pause
        // No prank needed - test contract is owner
        fixture.factory.pause();
        assertTrue(fixture.factory.paused());

        // Then unpause
        // No prank needed - test contract is owner
        fixture.factory.unpause();
        assertFalse(fixture.factory.paused());
    }

    function test_Unpause_RevertNotOwner() public {
        // Pause first
        // No prank needed - test contract is owner
        fixture.factory.pause();

        // Try to unpause as non-owner
        vm.prank(USER);
        vm.expectRevert();
        fixture.factory.unpause();

        assertTrue(fixture.factory.paused());
    }

    function test_Unpause_RevertNotPaused() public {
        assertFalse(fixture.factory.paused());

        // No prank needed - test contract is owner
        vm.expectRevert();
        fixture.factory.unpause();
    }

    // ============ Deployment When Paused Tests ============

    function test_DeployEscrow_RevertWhenPaused() public {
        // Pause the factory
        // No prank needed - test contract is owner
        fixture.factory.pause();

        // Try to deploy escrow
        // No prank needed - test contract is owner
        vm.expectRevert();
        fixture.factory.deployEscrow(MERCHANT_ID_1, MERCHANT_1, address(fixture.usdcToken));

        // Verify no escrow was deployed
        assertFalse(fixture.factory.merchantExists(MERCHANT_ID_1));
        assertEq(fixture.factory.getMerchantEscrowCount(MERCHANT_ID_1), 0);
    }

    function test_DeployEscrow_SuccessAfterUnpause() public {
        // Pause and unpause
        // No prank needed - test contract is owner
        fixture.factory.pause();
        fixture.factory.unpause();

        // Deploy escrow should work
        address escrow = fixture.factory.deployEscrow(MERCHANT_ID_1, MERCHANT_1, address(fixture.usdcToken));
        // No prank used

        assertTrue(escrow != address(0));
        assertTrue(fixture.factory.merchantExists(MERCHANT_ID_1));
    }

    // ============ Read Functions When Paused Tests ============

    function test_ReadFunctions_WorkWhenPaused() public {
        // Deploy an escrow first
        // No prank needed - test contract is owner
        address escrow = fixture.factory.deployEscrow(MERCHANT_ID_1, MERCHANT_1, address(fixture.usdcToken));

        // Pause the factory
        // No prank needed - test contract is owner
        fixture.factory.pause();

        // All read functions should still work
        assertTrue(fixture.factory.merchantExists(MERCHANT_ID_1));
        assertEq(fixture.factory.getMerchantEscrowCount(MERCHANT_ID_1), 1);
        assertEq(fixture.factory.getMerchantCounter(MERCHANT_ID_1), 1);
        assertEq(fixture.factory.getMerchantForEscrow(escrow), MERCHANT_ID_1);

        address[] memory escrows = fixture.factory.getEscrowsForMerchant(MERCHANT_ID_1);
        assertEq(escrows.length, 1);
        assertEq(escrows[0], escrow);

        // Prediction should also work
        address predicted = fixture.factory.predictEscrowAddress(MERCHANT_ID_2, MERCHANT_2, address(fixture.usdcToken));
        assertTrue(predicted != address(0));
    }

    // ============ Address Management When Paused Tests ============

    function test_SetPlatformAddress_WorksWhenPaused() public {
        // No prank needed - test contract is owner
        fixture.factory.pause();

        // Should be able to change platform address when paused
        fixture.factory.setPlatformAddress(NEW_PLATFORM);
        // No prank used

        assertEq(fixture.factory.platformAddress(), NEW_PLATFORM);
    }

    function test_SetDefaultOwner_WorksWhenPaused() public {
        // No prank needed - test contract is owner
        fixture.factory.pause();

        // Should be able to change default owner when paused
        fixture.factory.setDefaultOwner(NEW_DEFAULT_OWNER);
        // No prank used

        assertEq(fixture.factory.defaultOwner(), NEW_DEFAULT_OWNER);
    }

    // ============ Pause State Transitions ============

    function test_PauseUnpause_MultipleCycles() public {
        // No prank needed - test contract is owner

        for (uint256 i = 0; i < 5; i++) {
            // Pause
            fixture.factory.pause();
            assertTrue(fixture.factory.paused());

            // Unpause
            fixture.factory.unpause();
            assertFalse(fixture.factory.paused());
        }

        // No prank used
    }

    function test_PauseUnpause_DeploymentsBetweenCycles() public {
        // No prank needed - test contract is owner

        // Deploy -> Pause -> Unpause -> Deploy
        address escrow1 = fixture.factory.deployEscrow(MERCHANT_ID_1, MERCHANT_1, address(fixture.usdcToken));

        fixture.factory.pause();
        fixture.factory.unpause();

        address escrow2 = fixture.factory.deployEscrow(MERCHANT_ID_1, MERCHANT_1, address(fixture.daiToken));

        // No prank used

        // Verify both deployments succeeded
        assertTrue(escrow1 != address(0));
        assertTrue(escrow2 != address(0));
        assertEq(fixture.factory.getMerchantEscrowCount(MERCHANT_ID_1), 2);
    }

    // ============ Paused Factory Fixture Tests ============

    function test_PausedFactoryFixture_InitiallyPaused() public {
        FactoryFixture memory pausedFixture = createPausedFactoryFixture();
        assertTrue(pausedFixture.factory.paused());
    }

    function test_PausedFactoryFixture_CannotDeploy() public {
        FactoryFixture memory pausedFixture = createPausedFactoryFixture();

        // No prank needed - test contract is owner
        vm.expectRevert();
        pausedFixture.factory.deployEscrow(MERCHANT_ID_1, MERCHANT_1, address(pausedFixture.usdcToken));
    }

    function test_PausedFactoryFixture_CanUnpause() public {
        FactoryFixture memory pausedFixture = createPausedFactoryFixture();

        // No prank needed - test contract is owner
        pausedFixture.factory.unpause();
        assertFalse(pausedFixture.factory.paused());

        // Should be able to deploy after unpause
        // No prank needed - test contract is owner
        address escrow = pausedFixture.factory.deployEscrow(MERCHANT_ID_1, MERCHANT_1, address(pausedFixture.usdcToken));

        assertTrue(escrow != address(0));
    }

    // ============ Edge Cases ============

    function test_Pause_DoesNotAffectExistingEscrows() public {
        // Deploy escrow
        // No prank needed - test contract is owner
        address escrow = fixture.factory.deployEscrow(MERCHANT_ID_1, MERCHANT_1, address(fixture.usdcToken));

        // Fund the escrow
        fundEscrowFromFixture(fixture, escrow, getMediumTestAmount());

        // Pause factory
        // No prank needed - test contract is owner
        fixture.factory.pause();

        // Existing escrow should still function normally
        verifyEscrowConfiguration(escrow, MERCHANT_1, address(fixture.usdcToken), PLATFORM_ADDRESS, DEFAULT_OWNER);

        // Escrow should still be able to distribute (not affected by factory pause)
        // Note: This tests that factory pause doesn't affect deployed escrows
        assertTrue(fixture.usdcToken.balanceOf(escrow) > 0);
    }

    function test_Pause_PreservesFactoryState() public {
        // Deploy multiple escrows
        // No prank needed - test contract is owner
        address escrow1 = fixture.factory.deployEscrow(MERCHANT_ID_1, MERCHANT_1, address(fixture.usdcToken));
        address escrow2 = fixture.factory.deployEscrow(MERCHANT_ID_2, MERCHANT_2, address(fixture.daiToken));
        // No prank used

        // Pause factory
        // No prank needed - test contract is owner
        fixture.factory.pause();

        // Verify all state is preserved
        assertTrue(fixture.factory.merchantExists(MERCHANT_ID_1));
        assertTrue(fixture.factory.merchantExists(MERCHANT_ID_2));
        assertEq(fixture.factory.getMerchantForEscrow(escrow1), MERCHANT_ID_1);
        assertEq(fixture.factory.getMerchantForEscrow(escrow2), MERCHANT_ID_2);
        assertEq(fixture.factory.getMerchantEscrowCount(MERCHANT_ID_1), 1);
        assertEq(fixture.factory.getMerchantEscrowCount(MERCHANT_ID_2), 1);
    }
}
