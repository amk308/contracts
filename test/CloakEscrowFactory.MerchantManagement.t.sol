// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {CloakEscrowFactory} from "../src/CloakEscrowFactory.sol";
import {CloakEscrowFactoryFixtures} from "./fixtures/CloakEscrowFactoryFixtures.sol";

contract CloakEscrowFactoryMerchantManagementTest is Test, CloakEscrowFactoryFixtures {
    FactoryFixture public fixture;

    function setUp() public {
        setupMockUsers();
        (fixture,) = createFactoryWithMultipleEscrows();
    }

    function getDeployments() internal returns (DeploymentResult[] memory deployments) {
        (, deployments) = createFactoryWithMultipleEscrows();
        return deployments;
    }

    // ============ Merchant Existence Tests ============

    function test_MerchantExists_True() public {
        assertTrue(fixture.factory.merchantExists(MERCHANT_ID_1));
        assertTrue(fixture.factory.merchantExists(MERCHANT_ID_2));
    }

    function test_MerchantExists_False() public {
        assertFalse(fixture.factory.merchantExists(MERCHANT_ID_3));
        assertFalse(fixture.factory.merchantExists(generateRandomMerchantId(999)));
    }

    function test_MerchantExists_AfterFirstDeployment() public {
        FactoryFixture memory newFixture = createFactoryFixture();

        // Before deployment
        assertFalse(newFixture.factory.merchantExists(MERCHANT_ID_3));

        // After deployment
        // No prank needed - test contract is owner
        newFixture.factory.deployEscrow(MERCHANT_ID_3, MERCHANT_1, address(newFixture.usdcToken));

        assertTrue(newFixture.factory.merchantExists(MERCHANT_ID_3));
    }

    // ============ Get Escrows for Merchant Tests ============

    function test_GetEscrowsForMerchant_MultipleEscrows() public {
        address[] memory merchant1Escrows = fixture.factory.getEscrowsForMerchant(MERCHANT_ID_1);
        address[] memory merchant2Escrows = fixture.factory.getEscrowsForMerchant(MERCHANT_ID_2);

        // Merchant 1 should have 2 escrows
        assertEq(merchant1Escrows.length, 2);
        assertTrue(merchant1Escrows[0] != address(0));
        assertTrue(merchant1Escrows[1] != address(0));

        // Merchant 2 should have 2 escrows
        assertEq(merchant2Escrows.length, 2);
        assertTrue(merchant2Escrows[0] != address(0));
        assertTrue(merchant2Escrows[1] != address(0));
    }

    function test_GetEscrowsForMerchant_EmptyArray() public {
        address[] memory escrows = fixture.factory.getEscrowsForMerchant(MERCHANT_ID_3);
        assertEq(escrows.length, 0);
    }

    function test_GetEscrowsForMerchant_OrderPreserved() public {
        FactoryFixture memory newFixture = createFactoryFixture();
        address[] memory deployedEscrows = new address[](5);

        // No prank needed - test contract is owner
        for (uint256 i = 0; i < 5; i++) {
            deployedEscrows[i] =
                newFixture.factory.deployEscrow(MERCHANT_ID_1, MERCHANT_1, address(newFixture.usdcToken));
        }
        // No prank used

        address[] memory retrievedEscrows = newFixture.factory.getEscrowsForMerchant(MERCHANT_ID_1);
        assertEq(retrievedEscrows.length, 5);

        for (uint256 i = 0; i < 5; i++) {
            assertEq(retrievedEscrows[i], deployedEscrows[i]);
        }
    }

    // ============ Get Merchant for Escrow Tests ============

    function test_GetMerchantForEscrow_Success() public {
        address[] memory merchant1Escrows = fixture.factory.getEscrowsForMerchant(MERCHANT_ID_1);
        address[] memory merchant2Escrows = fixture.factory.getEscrowsForMerchant(MERCHANT_ID_2);

        // Test merchant 1 escrows
        for (uint256 i = 0; i < merchant1Escrows.length; i++) {
            bytes32 merchantId = fixture.factory.getMerchantForEscrow(merchant1Escrows[i]);
            assertEq(merchantId, MERCHANT_ID_1);
        }

        // Test merchant 2 escrows
        for (uint256 i = 0; i < merchant2Escrows.length; i++) {
            bytes32 merchantId = fixture.factory.getMerchantForEscrow(merchant2Escrows[i]);
            assertEq(merchantId, MERCHANT_ID_2);
        }
    }

    function test_GetMerchantForEscrow_RevertNonExistentEscrow() public {
        address fakeEscrow = address(0x999);

        vm.expectRevert(CloakEscrowFactory.EscrowNotFound.selector);
        fixture.factory.getMerchantForEscrow(fakeEscrow);
    }

    function test_GetMerchantForEscrow_RevertZeroAddress() public {
        vm.expectRevert(CloakEscrowFactory.EscrowNotFound.selector);
        fixture.factory.getMerchantForEscrow(address(0));
    }

    // ============ Merchant Counter Tests ============

    function test_GetMerchantCounter_AfterDeployments() public {
        // Merchant 1 deployed 2 escrows (counters 0, 1) -> next counter is 2
        assertEq(fixture.factory.getMerchantCounter(MERCHANT_ID_1), 2);

        // Merchant 2 deployed 2 escrows (counters 0, 1) -> next counter is 2
        assertEq(fixture.factory.getMerchantCounter(MERCHANT_ID_2), 2);

        // Merchant 3 never deployed -> counter is 0
        assertEq(fixture.factory.getMerchantCounter(MERCHANT_ID_3), 0);
    }

    function test_GetMerchantCounter_IncrementalIncrease() public {
        FactoryFixture memory newFixture = createFactoryFixture();

        // No prank needed - test contract is owner
        for (uint256 i = 0; i < 10; i++) {
            assertEq(newFixture.factory.getMerchantCounter(MERCHANT_ID_1), i);

            newFixture.factory.deployEscrow(MERCHANT_ID_1, MERCHANT_1, address(newFixture.usdcToken));

            assertEq(newFixture.factory.getMerchantCounter(MERCHANT_ID_1), i + 1);
        }
        // No prank used
    }

    // ============ Merchant Escrow Count Tests ============

    function test_GetMerchantEscrowCount_Accuracy() public {
        assertEq(fixture.factory.getMerchantEscrowCount(MERCHANT_ID_1), 2);
        assertEq(fixture.factory.getMerchantEscrowCount(MERCHANT_ID_2), 2);
        assertEq(fixture.factory.getMerchantEscrowCount(MERCHANT_ID_3), 0);
    }

    function test_GetMerchantEscrowCount_MatchesArrayLength() public {
        address[] memory merchant1Escrows = fixture.factory.getEscrowsForMerchant(MERCHANT_ID_1);
        address[] memory merchant2Escrows = fixture.factory.getEscrowsForMerchant(MERCHANT_ID_2);
        address[] memory merchant3Escrows = fixture.factory.getEscrowsForMerchant(MERCHANT_ID_3);

        assertEq(fixture.factory.getMerchantEscrowCount(MERCHANT_ID_1), merchant1Escrows.length);
        assertEq(fixture.factory.getMerchantEscrowCount(MERCHANT_ID_2), merchant2Escrows.length);
        assertEq(fixture.factory.getMerchantEscrowCount(MERCHANT_ID_3), merchant3Escrows.length);
    }

    // ============ Cross-Merchant Isolation Tests ============

    function test_MerchantIsolation_CountersIndependent() public {
        FactoryFixture memory newFixture = createFactoryFixture();

        // No prank needed - test contract is owner

        // Deploy 3 escrows for merchant 1
        for (uint256 i = 0; i < 3; i++) {
            newFixture.factory.deployEscrow(MERCHANT_ID_1, MERCHANT_1, address(newFixture.usdcToken));
        }

        // Deploy 1 escrow for merchant 2
        newFixture.factory.deployEscrow(MERCHANT_ID_2, MERCHANT_2, address(newFixture.usdcToken));

        // No prank used

        // Verify independent counters
        assertEq(newFixture.factory.getMerchantCounter(MERCHANT_ID_1), 3);
        assertEq(newFixture.factory.getMerchantCounter(MERCHANT_ID_2), 1);
        assertEq(newFixture.factory.getMerchantEscrowCount(MERCHANT_ID_1), 3);
        assertEq(newFixture.factory.getMerchantEscrowCount(MERCHANT_ID_2), 1);
    }

    function test_MerchantIsolation_EscrowArraysIndependent() public {
        address[] memory merchant1Escrows = fixture.factory.getEscrowsForMerchant(MERCHANT_ID_1);
        address[] memory merchant2Escrows = fixture.factory.getEscrowsForMerchant(MERCHANT_ID_2);

        // Verify no overlap between merchant escrow arrays
        for (uint256 i = 0; i < merchant1Escrows.length; i++) {
            for (uint256 j = 0; j < merchant2Escrows.length; j++) {
                assertTrue(merchant1Escrows[i] != merchant2Escrows[j]);
            }
        }
    }

    // ============ Edge Case Tests ============

    function test_MerchantManagement_ZeroMerchantId() public {
        // Zero merchant ID should be treated as valid (though not recommended)
        FactoryFixture memory newFixture = createFactoryFixture();

        // No prank needed - test contract is owner
        address escrow = newFixture.factory.deployEscrow(bytes32(0), MERCHANT_1, address(newFixture.usdcToken));

        assertTrue(newFixture.factory.merchantExists(bytes32(0)));
        assertEq(newFixture.factory.getMerchantForEscrow(escrow), bytes32(0));
    }

    function test_MerchantManagement_MaxBytes32MerchantId() public {
        bytes32 maxMerchantId = bytes32(type(uint256).max);
        FactoryFixture memory newFixture = createFactoryFixture();

        // No prank needed - test contract is owner
        address escrow = newFixture.factory.deployEscrow(maxMerchantId, MERCHANT_1, address(newFixture.usdcToken));

        assertTrue(newFixture.factory.merchantExists(maxMerchantId));
        assertEq(newFixture.factory.getMerchantForEscrow(escrow), maxMerchantId);
    }

    // ============ Large Scale Tests ============

    function test_MerchantManagement_ManyMerchants() public {
        FactoryFixture memory newFixture = createFactoryFixture();
        uint256 merchantCount = 50;

        // No prank needed - test contract is owner
        for (uint256 i = 0; i < merchantCount; i++) {
            bytes32 merchantId = generateRandomMerchantId(i);
            newFixture.factory.deployEscrow(merchantId, MERCHANT_1, address(newFixture.usdcToken));

            assertTrue(newFixture.factory.merchantExists(merchantId));
            assertEq(newFixture.factory.getMerchantEscrowCount(merchantId), 1);
        }
        // No prank used
    }
}
