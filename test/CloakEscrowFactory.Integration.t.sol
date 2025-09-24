// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {CloakEscrowFactory} from "../src/CloakEscrowFactory.sol";
import {CloakEscrow} from "../src/CloakEscrow.sol";
import {CloakEscrowFactoryFixtures} from "./fixtures/CloakEscrowFactoryFixtures.sol";

contract CloakEscrowFactoryIntegrationTest is Test, CloakEscrowFactoryFixtures {
    FactoryFixture public fixture;

    // Events from CloakEscrow for testing
    event PlatformFeeUpdated(uint256 oldFee, uint256 newFee);
    event MerchantAddressUpdated(address oldAddress, address newAddress);
    event PlatformAddressUpdated(address oldAddress, address newAddress);
    event FundsDistributed(uint256 platformAmount, uint256 merchantAmount);
    event ContractPaused(address account);
    event ContractUnpaused(address account);

    function setUp() public {
        setupMockUsers();
        fixture = createFactoryFixture();
    }

    // ============ Basic Deployment and Configuration Tests ============

    function test_Integration_DeployAndVerifyConfiguration() public {
        // Deploy escrow from factory
        address escrowAddress = fixture.factory.deployEscrow(
            MERCHANT_ID_1,
            MERCHANT_1,
            address(fixture.usdcToken)
        );

        CloakEscrow escrow = CloakEscrow(escrowAddress);

        // Verify escrow configuration matches deployment parameters
        assertEq(escrow.merchantAddress(), MERCHANT_1);
        assertEq(escrow.paymentTokenAddress(), address(fixture.usdcToken));
        assertEq(escrow.platformAddress(), PLATFORM_ADDRESS);
        assertEq(escrow.owner(), DEFAULT_OWNER);
        assertEq(escrow.getPlatformFee(), 250); // Default 2.5%
        assertFalse(escrow.paused());
    }

    function test_Integration_MultipleEscrowsIndependentConfiguration() public {
        // Deploy escrow 1 for merchant 1 with USDC
        address escrow1 = fixture.factory.deployEscrow(
            MERCHANT_ID_1,
            MERCHANT_1,
            address(fixture.usdcToken)
        );

        // Deploy escrow 2 for merchant 2 with DAI
        address escrow2 = fixture.factory.deployEscrow(
            MERCHANT_ID_2,
            MERCHANT_2,
            address(fixture.daiToken)
        );

        CloakEscrow escrowContract1 = CloakEscrow(escrow1);
        CloakEscrow escrowContract2 = CloakEscrow(escrow2);

        // Verify independent configurations
        assertEq(escrowContract1.merchantAddress(), MERCHANT_1);
        assertEq(escrowContract1.paymentTokenAddress(), address(fixture.usdcToken));
        
        assertEq(escrowContract2.merchantAddress(), MERCHANT_2);
        assertEq(escrowContract2.paymentTokenAddress(), address(fixture.daiToken));

        // Verify they have different addresses
        assertTrue(escrow1 != escrow2);
    }

    // ============ Escrow Functionality Tests ============

    function test_Integration_FundAndDistribute() public {
        // Deploy escrow
        address escrowAddress = fixture.factory.deployEscrow(
            MERCHANT_ID_1,
            MERCHANT_1,
            address(fixture.usdcToken)
        );

        CloakEscrow escrow = CloakEscrow(escrowAddress);
        uint256 fundAmount = getMediumTestAmount(); // 1000 USDC

        // Fund the escrow
        vm.prank(ADMIN);
        fixture.usdcToken.transfer(escrowAddress, fundAmount);

        // Verify escrow balance
        assertEq(fixture.usdcToken.balanceOf(escrowAddress), fundAmount);

        // Record initial balances
        uint256 initialMerchantBalance = fixture.usdcToken.balanceOf(MERCHANT_1);
        uint256 initialPlatformBalance = fixture.usdcToken.balanceOf(PLATFORM_ADDRESS);

        // Calculate expected distribution (2.5% platform fee)
        uint256 expectedPlatformAmount = (fundAmount * 250) / 10000; // 25 USDC
        uint256 expectedMerchantAmount = fundAmount - expectedPlatformAmount; // 975 USDC

        // Distribute funds
        vm.expectEmit(true, true, true, true);
        emit FundsDistributed(expectedPlatformAmount, expectedMerchantAmount);
        escrow.distribute();

        // Verify final balances
        assertEq(fixture.usdcToken.balanceOf(MERCHANT_1), initialMerchantBalance + expectedMerchantAmount);
        assertEq(fixture.usdcToken.balanceOf(PLATFORM_ADDRESS), initialPlatformBalance + expectedPlatformAmount);
        assertEq(fixture.usdcToken.balanceOf(escrowAddress), 0);
    }

    function test_Integration_MultipleFundingAndDistribution() public {
        // Deploy escrow
        address escrowAddress = fixture.factory.deployEscrow(
            MERCHANT_ID_1,
            MERCHANT_1,
            address(fixture.usdcToken)
        );

        CloakEscrow escrow = CloakEscrow(escrowAddress);

        // Multiple funding rounds
        uint256[] memory fundAmounts = new uint256[](3);
        fundAmounts[0] = 500 * 10**6;  // 500 USDC
        fundAmounts[1] = 1000 * 10**6; // 1000 USDC
        fundAmounts[2] = 750 * 10**6;  // 750 USDC

        uint256 totalMerchantReceived = 0;
        uint256 totalPlatformReceived = 0;

        for (uint256 i = 0; i < fundAmounts.length; i++) {
            // Fund escrow
            vm.prank(ADMIN);
            fixture.usdcToken.transfer(escrowAddress, fundAmounts[i]);

            // Record balances before distribution
            uint256 merchantBalanceBefore = fixture.usdcToken.balanceOf(MERCHANT_1);
            uint256 platformBalanceBefore = fixture.usdcToken.balanceOf(PLATFORM_ADDRESS);

            // Distribute
            escrow.distribute();

            // Calculate what was received
            uint256 merchantReceived = fixture.usdcToken.balanceOf(MERCHANT_1) - merchantBalanceBefore;
            uint256 platformReceived = fixture.usdcToken.balanceOf(PLATFORM_ADDRESS) - platformBalanceBefore;

            totalMerchantReceived += merchantReceived;
            totalPlatformReceived += platformReceived;

            // Verify escrow is empty after distribution
            assertEq(fixture.usdcToken.balanceOf(escrowAddress), 0);
        }

        // Verify total amounts are correct
        uint256 totalFunded = fundAmounts[0] + fundAmounts[1] + fundAmounts[2];
        uint256 expectedTotalPlatform = (totalFunded * 250) / 10000;
        uint256 expectedTotalMerchant = totalFunded - expectedTotalPlatform;

        assertEq(totalPlatformReceived, expectedTotalPlatform);
        assertEq(totalMerchantReceived, expectedTotalMerchant);
    }

    // ============ Escrow Management Tests ============

    function test_Integration_EscrowOwnershipManagement() public {
        // Deploy escrow
        address escrowAddress = fixture.factory.deployEscrow(
            MERCHANT_ID_1,
            MERCHANT_1,
            address(fixture.usdcToken)
        );

        CloakEscrow escrow = CloakEscrow(escrowAddress);

        // Verify initial owner is DEFAULT_OWNER
        assertEq(escrow.owner(), DEFAULT_OWNER);

        // Change platform fee (only owner can do this)
        vm.prank(DEFAULT_OWNER);
        vm.expectEmit(true, true, true, true);
        emit PlatformFeeUpdated(250, 300);
        escrow.setPlatformFee(300); // 3%

        assertEq(escrow.getPlatformFee(), 300);

        // Non-owner should not be able to change fee
        vm.prank(USER);
        vm.expectRevert();
        escrow.setPlatformFee(400);
    }

    function test_Integration_EscrowAddressManagement() public {
        // Deploy escrow
        address escrowAddress = fixture.factory.deployEscrow(
            MERCHANT_ID_1,
            MERCHANT_1,
            address(fixture.usdcToken)
        );

        CloakEscrow escrow = CloakEscrow(escrowAddress);

        // Change merchant address
        vm.prank(DEFAULT_OWNER);
        vm.expectEmit(true, true, true, true);
        emit MerchantAddressUpdated(MERCHANT_1, NEW_MERCHANT);
        escrow.setMerchantAddress(NEW_MERCHANT);

        assertEq(escrow.merchantAddress(), NEW_MERCHANT);

        // Change platform address
        vm.prank(DEFAULT_OWNER);
        vm.expectEmit(true, true, true, true);
        emit PlatformAddressUpdated(PLATFORM_ADDRESS, NEW_PLATFORM);
        escrow.setPlatformAddress(NEW_PLATFORM);

        assertEq(escrow.platformAddress(), NEW_PLATFORM);
    }

    function test_Integration_EscrowPauseUnpause() public {
        // Deploy escrow
        address escrowAddress = fixture.factory.deployEscrow(
            MERCHANT_ID_1,
            MERCHANT_1,
            address(fixture.usdcToken)
        );

        CloakEscrow escrow = CloakEscrow(escrowAddress);

        // Initially not paused
        assertFalse(escrow.paused());

        // Pause escrow
        vm.prank(DEFAULT_OWNER);
        vm.expectEmit(true, true, true, true);
        emit ContractPaused(DEFAULT_OWNER);
        escrow.pause();

        assertTrue(escrow.paused());

        // Fund escrow while paused
        vm.prank(ADMIN);
        fixture.usdcToken.transfer(escrowAddress, getMediumTestAmount());

        // Distribution should fail when paused
        vm.expectRevert();
        escrow.distribute();

        // Unpause escrow
        vm.prank(DEFAULT_OWNER);
        vm.expectEmit(true, true, true, true);
        emit ContractUnpaused(DEFAULT_OWNER);
        escrow.unpause();

        assertFalse(escrow.paused());

        // Distribution should work after unpause
        escrow.distribute();
        assertEq(fixture.usdcToken.balanceOf(escrowAddress), 0);
    }

    // ============ Cross-Escrow Independence Tests ============

    function test_Integration_CrossEscrowIndependence() public {
        // Deploy two escrows for different merchants
        address escrow1 = fixture.factory.deployEscrow(
            MERCHANT_ID_1,
            MERCHANT_1,
            address(fixture.usdcToken)
        );

        address escrow2 = fixture.factory.deployEscrow(
            MERCHANT_ID_2,
            MERCHANT_2,
            address(fixture.usdcToken)
        );

        CloakEscrow escrowContract1 = CloakEscrow(escrow1);
        CloakEscrow escrowContract2 = CloakEscrow(escrow2);

        // Change settings on escrow1
        vm.startPrank(DEFAULT_OWNER);
        escrowContract1.setPlatformFee(300); // 3%
        escrowContract1.setMerchantAddress(NEW_MERCHANT);
        escrowContract1.pause();
        vm.stopPrank();

        // Verify escrow2 is unaffected
        assertEq(escrowContract2.getPlatformFee(), 250); // Still 2.5%
        assertEq(escrowContract2.merchantAddress(), MERCHANT_2); // Unchanged
        assertFalse(escrowContract2.paused()); // Not paused

        // Fund both escrows
        vm.startPrank(ADMIN);
        fixture.usdcToken.transfer(escrow1, getMediumTestAmount());
        fixture.usdcToken.transfer(escrow2, getMediumTestAmount());
        vm.stopPrank();

        // Escrow1 distribution should fail (paused)
        vm.expectRevert();
        escrowContract1.distribute();

        // Escrow2 distribution should succeed
        uint256 merchant2BalanceBefore = fixture.usdcToken.balanceOf(MERCHANT_2);
        escrowContract2.distribute();
        assertTrue(fixture.usdcToken.balanceOf(MERCHANT_2) > merchant2BalanceBefore);
    }

    // ============ Factory State vs Escrow State Tests ============

    function test_Integration_FactoryChangesDoNotAffectDeployedEscrows() public {
        // Deploy escrow with original factory settings
        address escrowAddress = fixture.factory.deployEscrow(
            MERCHANT_ID_1,
            MERCHANT_1,
            address(fixture.usdcToken)
        );

        CloakEscrow escrow = CloakEscrow(escrowAddress);

        // Verify initial escrow configuration
        assertEq(escrow.platformAddress(), PLATFORM_ADDRESS);

        // Change factory platform address
        fixture.factory.setPlatformAddress(NEW_PLATFORM);
        assertEq(fixture.factory.platformAddress(), NEW_PLATFORM);

        // Existing escrow should still have old platform address
        assertEq(escrow.platformAddress(), PLATFORM_ADDRESS);

        // Deploy new escrow after factory change
        address newEscrowAddress = fixture.factory.deployEscrow(
            MERCHANT_ID_2,
            MERCHANT_2,
            address(fixture.usdcToken)
        );

        CloakEscrow newEscrow = CloakEscrow(newEscrowAddress);

        // New escrow should have new platform address
        assertEq(newEscrow.platformAddress(), NEW_PLATFORM);

        // Old escrow should still have old platform address
        assertEq(escrow.platformAddress(), PLATFORM_ADDRESS);
    }

    // ============ Error Handling Tests ============

    function test_Integration_EscrowErrorHandling() public {
        // Deploy escrow
        address escrowAddress = fixture.factory.deployEscrow(
            MERCHANT_ID_1,
            MERCHANT_1,
            address(fixture.usdcToken)
        );

        CloakEscrow escrow = CloakEscrow(escrowAddress);

        // Try to distribute with no funds
        vm.expectRevert(CloakEscrow.NoBalanceToDistribute.selector);
        escrow.distribute();

        // Try to set invalid platform fee
        vm.prank(DEFAULT_OWNER);
        vm.expectRevert(CloakEscrow.InvalidFeeAmount.selector);
        escrow.setPlatformFee(6000); // 60% - exceeds maximum

        // Try to set zero merchant address
        vm.prank(DEFAULT_OWNER);
        vm.expectRevert(CloakEscrow.InvalidAddress.selector);
        escrow.setMerchantAddress(address(0));
    }

    // ============ Large Scale Integration Test ============

    function test_Integration_LargeScaleDeploymentAndOperation() public {
        uint256 escrowCount = 10;
        address[] memory escrows = new address[](escrowCount);
        
        // Deploy multiple escrows
        for (uint256 i = 0; i < escrowCount; i++) {
            bytes32 merchantId = generateRandomMerchantId(i);
            escrows[i] = fixture.factory.deployEscrow(
                merchantId,
                MERCHANT_1,
                address(fixture.usdcToken)
            );
        }

        // Fund and operate all escrows
        for (uint256 i = 0; i < escrowCount; i++) {
            CloakEscrow escrow = CloakEscrow(escrows[i]);
            
            // Fund escrow
            vm.prank(ADMIN);
            fixture.usdcToken.transfer(escrows[i], getSmallTestAmount());
            
            // Verify configuration
            assertEq(escrow.merchantAddress(), MERCHANT_1);
            assertEq(escrow.paymentTokenAddress(), address(fixture.usdcToken));
            
            // Distribute funds
            escrow.distribute();
            
            // Verify empty after distribution
            assertEq(fixture.usdcToken.balanceOf(escrows[i]), 0);
        }

        // Verify all escrows are tracked by factory
        for (uint256 i = 0; i < escrowCount; i++) {
            bytes32 merchantId = generateRandomMerchantId(i);
            assertTrue(fixture.factory.merchantExists(merchantId));
            assertEq(fixture.factory.getMerchantForEscrow(escrows[i]), merchantId);
        }
    }

    // ============ Different Token Integration Tests ============

    function test_Integration_DifferentTokenEscrows() public {
        // Deploy USDC escrow
        address usdcEscrow = fixture.factory.deployEscrow(
            MERCHANT_ID_1,
            MERCHANT_1,
            address(fixture.usdcToken)
        );

        // Deploy DAI escrow for same merchant
        address daiEscrow = fixture.factory.deployEscrow(
            MERCHANT_ID_1,
            MERCHANT_1,
            address(fixture.daiToken)
        );

        CloakEscrow usdcEscrowContract = CloakEscrow(usdcEscrow);
        CloakEscrow daiEscrowContract = CloakEscrow(daiEscrow);

        // Fund both escrows
        vm.startPrank(ADMIN);
        fixture.usdcToken.transfer(usdcEscrow, 1000 * 10**6); // 1000 USDC
        fixture.daiToken.transfer(daiEscrow, 1000 * 10**18);   // 1000 DAI
        vm.stopPrank();

        // Record initial balances
        uint256 initialUSDCBalance = fixture.usdcToken.balanceOf(MERCHANT_1);
        uint256 initialDAIBalance = fixture.daiToken.balanceOf(MERCHANT_1);

        // Distribute from both escrows
        usdcEscrowContract.distribute();
        daiEscrowContract.distribute();

        // Verify merchant received both tokens
        assertTrue(fixture.usdcToken.balanceOf(MERCHANT_1) > initialUSDCBalance);
        assertTrue(fixture.daiToken.balanceOf(MERCHANT_1) > initialDAIBalance);

        // Verify both escrows are empty
        assertEq(fixture.usdcToken.balanceOf(usdcEscrow), 0);
        assertEq(fixture.daiToken.balanceOf(daiEscrow), 0);
    }
}
