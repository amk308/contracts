// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {CloakEscrowFactory} from "../src/CloakEscrowFactory.sol";
import {CloakEscrow} from "../src/CloakEscrow.sol";
import {CloakEscrowFactoryFixtures} from "./fixtures/CloakEscrowFactoryFixtures.sol";

contract CloakEscrowFactoryDeploymentTest is Test, CloakEscrowFactoryFixtures {
    FactoryFixture public fixture;

    event EscrowDeployed(
        bytes32 indexed merchantId, address indexed escrowAddress, uint256 counter, address paymentToken
    );
    event MerchantRegistered(bytes32 indexed merchantId);

    function setUp() public {
        setupMockUsers();
        fixture = createFactoryFixture();
    }

    // ============ Single Deployment Tests ============

    function test_DeployEscrow_Success() public {
        address predictedAddress =
            fixture.factory.predictEscrowAddress(MERCHANT_ID_1, MERCHANT_1, address(fixture.usdcToken));

        // No prank needed - test contract is owner
        vm.expectEmit(true, true, true, true);
        emit MerchantRegistered(MERCHANT_ID_1);
        vm.expectEmit(true, true, true, true);
        emit EscrowDeployed(MERCHANT_ID_1, predictedAddress, 0, address(fixture.usdcToken));

        address deployedAddress = fixture.factory.deployEscrow(MERCHANT_ID_1, MERCHANT_1, address(fixture.usdcToken));

        // Verify deployment
        assertEq(deployedAddress, predictedAddress);
        assertTrue(deployedAddress != address(0));

        // Verify factory state
        assertTrue(fixture.factory.merchantExists(MERCHANT_ID_1));
        assertEq(fixture.factory.getMerchantEscrowCount(MERCHANT_ID_1), 1);
        assertEq(fixture.factory.getMerchantCounter(MERCHANT_ID_1), 1);
        assertEq(fixture.factory.getMerchantForEscrow(deployedAddress), MERCHANT_ID_1);

        // Verify escrow configuration
        verifyEscrowConfiguration(
            deployedAddress, MERCHANT_1, address(fixture.usdcToken), PLATFORM_ADDRESS, DEFAULT_OWNER
        );
    }

    function test_DeployEscrow_SuccessWithDAI() public {
        // No prank needed - test contract is owner
        address deployedAddress = fixture.factory.deployEscrow(MERCHANT_ID_1, MERCHANT_1, address(fixture.daiToken));

        verifyEscrowConfiguration(
            deployedAddress, MERCHANT_1, address(fixture.daiToken), PLATFORM_ADDRESS, DEFAULT_OWNER
        );
    }

    function test_DeployEscrow_SuccessMultipleMerchants() public {
        // No prank needed - test contract is owner

        // Deploy for merchant 1
        address escrow1 = fixture.factory.deployEscrow(MERCHANT_ID_1, MERCHANT_1, address(fixture.usdcToken));

        // Deploy for merchant 2
        address escrow2 = fixture.factory.deployEscrow(MERCHANT_ID_2, MERCHANT_2, address(fixture.usdcToken));

        // No prank used

        // Verify both deployments
        assertTrue(escrow1 != escrow2);
        assertEq(fixture.factory.getMerchantForEscrow(escrow1), MERCHANT_ID_1);
        assertEq(fixture.factory.getMerchantForEscrow(escrow2), MERCHANT_ID_2);
    }

    // ============ Multiple Deployments for Same Merchant ============

    function test_DeployEscrow_MultipleForSameMerchant() public {
        // No prank needed - test contract is owner

        // First deployment - should emit MerchantRegistered
        vm.expectEmit(true, true, true, true);
        emit MerchantRegistered(MERCHANT_ID_1);
        address escrow1 = fixture.factory.deployEscrow(MERCHANT_ID_1, MERCHANT_1, address(fixture.usdcToken));

        // Second deployment - should NOT emit MerchantRegistered
        vm.recordLogs();
        address escrow2 = fixture.factory.deployEscrow(MERCHANT_ID_1, MERCHANT_1, address(fixture.daiToken));

        // Verify MerchantRegistered was not emitted for second deployment
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bool merchantRegisteredEmitted = false;
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == keccak256("MerchantRegistered(bytes32)")) {
                merchantRegisteredEmitted = true;
                break;
            }
        }
        assertFalse(merchantRegisteredEmitted);

        // No prank used

        // Verify state
        assertTrue(escrow1 != escrow2);
        assertEq(fixture.factory.getMerchantEscrowCount(MERCHANT_ID_1), 2);
        assertEq(fixture.factory.getMerchantCounter(MERCHANT_ID_1), 2);

        address[] memory escrows = fixture.factory.getEscrowsForMerchant(MERCHANT_ID_1);
        assertEq(escrows.length, 2);
        assertEq(escrows[0], escrow1);
        assertEq(escrows[1], escrow2);
    }

    function test_DeployEscrow_CounterIncrement() public {
        // No prank needed - test contract is owner

        for (uint256 i = 0; i < 5; i++) {
            assertEq(fixture.factory.getMerchantCounter(MERCHANT_ID_1), i);

            fixture.factory.deployEscrow(MERCHANT_ID_1, MERCHANT_1, address(fixture.usdcToken));

            assertEq(fixture.factory.getMerchantCounter(MERCHANT_ID_1), i + 1);
            assertEq(fixture.factory.getMerchantEscrowCount(MERCHANT_ID_1), i + 1);
        }

        // No prank used
    }

    // ============ Address Prediction Tests ============

    function test_PredictEscrowAddress_Accuracy() public {
        address predicted = fixture.factory.predictEscrowAddress(MERCHANT_ID_1, MERCHANT_1, address(fixture.usdcToken));

        // No prank needed - test contract is owner
        address deployed = fixture.factory.deployEscrow(MERCHANT_ID_1, MERCHANT_1, address(fixture.usdcToken));

        assertEq(predicted, deployed);
    }

    function test_PredictEscrowAddress_DifferentMerchants() public {
        address predicted1 = fixture.factory.predictEscrowAddress(MERCHANT_ID_1, MERCHANT_1, address(fixture.usdcToken));

        address predicted2 = fixture.factory.predictEscrowAddress(MERCHANT_ID_2, MERCHANT_2, address(fixture.usdcToken));

        assertTrue(predicted1 != predicted2);
    }

    function test_PredictEscrowAddress_DifferentTokens() public {
        address predicted1 = fixture.factory.predictEscrowAddress(MERCHANT_ID_1, MERCHANT_1, address(fixture.usdcToken));

        address predicted2 = fixture.factory.predictEscrowAddress(MERCHANT_ID_1, MERCHANT_1, address(fixture.daiToken));

        assertTrue(predicted1 != predicted2);
    }

    // ============ Deployment Failure Tests ============

    function test_DeployEscrow_RevertNotOwner() public {
        vm.prank(USER);
        vm.expectRevert();
        fixture.factory.deployEscrow(MERCHANT_ID_1, MERCHANT_1, address(fixture.usdcToken));
    }

    function test_DeployEscrow_RevertZeroMerchantAddress() public {
        // No prank needed - test contract is owner
        vm.expectRevert(CloakEscrowFactory.InvalidAddress.selector);
        fixture.factory.deployEscrow(MERCHANT_ID_1, address(0), address(fixture.usdcToken));
    }

    function test_DeployEscrow_RevertZeroTokenAddress() public {
        // No prank needed - test contract is owner
        vm.expectRevert(CloakEscrowFactory.InvalidAddress.selector);
        fixture.factory.deployEscrow(MERCHANT_ID_1, MERCHANT_1, address(0));
    }

    function test_DeployEscrow_RevertWhenPaused() public {
        // No prank needed - test contract is owner
        fixture.factory.pause();

        // No prank needed - test contract is owner
        vm.expectRevert();
        fixture.factory.deployEscrow(MERCHANT_ID_1, MERCHANT_1, address(fixture.usdcToken));
    }

    // ============ Gas Optimization Tests ============

    function test_DeployEscrow_GasUsage() public {
        // No prank needed - test contract is owner

        uint256 gasBefore = gasleft();
        fixture.factory.deployEscrow(MERCHANT_ID_1, MERCHANT_1, address(fixture.usdcToken));
        uint256 gasUsed = gasBefore - gasleft();

        // Gas usage should be reasonable (adjust threshold as needed)
        assertTrue(gasUsed < 2_000_000, "Gas usage too high");
    }
}
