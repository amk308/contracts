// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {CloakEscrowFactory} from "../src/CloakEscrowFactory.sol";
import {CloakEscrowFactoryFixtures} from "./fixtures/CloakEscrowFactoryFixtures.sol";

contract CloakEscrowFactoryAddressManagementTest is Test, CloakEscrowFactoryFixtures {
    FactoryFixture public fixture;

    event PlatformAddressUpdated(address oldAddress, address newAddress);
    event DefaultOwnerUpdated(address oldOwner, address newOwner);

    function setUp() public {
        setupMockUsers();
        fixture = createFactoryFixture();
    }

    // ============ Platform Address Management Tests ============

    function test_SetPlatformAddress_Success() public {
        address oldAddress = fixture.factory.platformAddress();
        
        // No prank needed - test contract is owner
        vm.expectEmit(true, true, true, true);
        emit PlatformAddressUpdated(oldAddress, NEW_PLATFORM);
        fixture.factory.setPlatformAddress(NEW_PLATFORM);

        assertEq(fixture.factory.platformAddress(), NEW_PLATFORM);
    }

    function test_SetPlatformAddress_SuccessMultipleTimes() public {
        address[] memory newAddresses = new address[](3);
        newAddresses[0] = address(0x111);
        newAddresses[1] = address(0x222);
        newAddresses[2] = address(0x333);

        // No prank needed - test contract is owner
        for (uint256 i = 0; i < newAddresses.length; i++) {
            address oldAddress = fixture.factory.platformAddress();
            
            vm.expectEmit(true, true, true, true);
            emit PlatformAddressUpdated(oldAddress, newAddresses[i]);
            fixture.factory.setPlatformAddress(newAddresses[i]);
            
            assertEq(fixture.factory.platformAddress(), newAddresses[i]);
        }
        // No prank used
    }

    function test_SetPlatformAddress_RevertNotOwner() public {
        vm.prank(USER);
        vm.expectRevert();
        fixture.factory.setPlatformAddress(NEW_PLATFORM);

        // Verify address unchanged
        assertEq(fixture.factory.platformAddress(), PLATFORM_ADDRESS);
    }

    function test_SetPlatformAddress_RevertZeroAddress() public {
        // No prank needed - test contract is owner
        vm.expectRevert(CloakEscrowFactory.InvalidAddress.selector);
        fixture.factory.setPlatformAddress(address(0));

        // Verify address unchanged
        assertEq(fixture.factory.platformAddress(), PLATFORM_ADDRESS);
    }

    function test_SetPlatformAddress_AffectsNewDeployments() public {
        // Deploy escrow with original platform address
        // No prank needed - test contract is owner
        address escrow1 = fixture.factory.deployEscrow(
            MERCHANT_ID_1,
            MERCHANT_1,
            address(fixture.usdcToken)
        );

        // Change platform address
        // No prank needed - test contract is owner
        fixture.factory.setPlatformAddress(NEW_PLATFORM);

        // Deploy escrow with new platform address
        // No prank needed - test contract is owner
        address escrow2 = fixture.factory.deployEscrow(
            MERCHANT_ID_2,
            MERCHANT_2,
            address(fixture.usdcToken)
        );

        // Verify escrows have different platform addresses
        verifyEscrowConfiguration(escrow1, MERCHANT_1, address(fixture.usdcToken), PLATFORM_ADDRESS, DEFAULT_OWNER);
        verifyEscrowConfiguration(escrow2, MERCHANT_2, address(fixture.usdcToken), NEW_PLATFORM, DEFAULT_OWNER);
    }

    // ============ Default Owner Management Tests ============

    function test_SetDefaultOwner_Success() public {
        address oldOwner = fixture.factory.defaultOwner();
        
        // No prank needed - test contract is owner
        vm.expectEmit(true, true, true, true);
        emit DefaultOwnerUpdated(oldOwner, NEW_DEFAULT_OWNER);
        fixture.factory.setDefaultOwner(NEW_DEFAULT_OWNER);

        assertEq(fixture.factory.defaultOwner(), NEW_DEFAULT_OWNER);
    }

    function test_SetDefaultOwner_SuccessMultipleTimes() public {
        address[] memory newOwners = new address[](3);
        newOwners[0] = address(0x111);
        newOwners[1] = address(0x222);
        newOwners[2] = address(0x333);

        // No prank needed - test contract is owner
        for (uint256 i = 0; i < newOwners.length; i++) {
            address oldOwner = fixture.factory.defaultOwner();
            
            vm.expectEmit(true, true, true, true);
            emit DefaultOwnerUpdated(oldOwner, newOwners[i]);
            fixture.factory.setDefaultOwner(newOwners[i]);
            
            assertEq(fixture.factory.defaultOwner(), newOwners[i]);
        }
        // No prank used
    }

    function test_SetDefaultOwner_RevertNotOwner() public {
        vm.prank(USER);
        vm.expectRevert();
        fixture.factory.setDefaultOwner(NEW_DEFAULT_OWNER);

        // Verify owner unchanged
        assertEq(fixture.factory.defaultOwner(), DEFAULT_OWNER);
    }

    function test_SetDefaultOwner_RevertZeroAddress() public {
        // No prank needed - test contract is owner
        vm.expectRevert(CloakEscrowFactory.InvalidAddress.selector);
        fixture.factory.setDefaultOwner(address(0));

        // Verify owner unchanged
        assertEq(fixture.factory.defaultOwner(), DEFAULT_OWNER);
    }

    function test_SetDefaultOwner_AffectsNewDeployments() public {
        // Deploy escrow with original default owner
        // No prank needed - test contract is owner
        address escrow1 = fixture.factory.deployEscrow(
            MERCHANT_ID_1,
            MERCHANT_1,
            address(fixture.usdcToken)
        );

        // Change default owner
        // No prank needed - test contract is owner
        fixture.factory.setDefaultOwner(NEW_DEFAULT_OWNER);

        // Deploy escrow with new default owner
        // No prank needed - test contract is owner
        address escrow2 = fixture.factory.deployEscrow(
            MERCHANT_ID_2,
            MERCHANT_2,
            address(fixture.usdcToken)
        );

        // Verify escrows have different owners
        verifyEscrowConfiguration(escrow1, MERCHANT_1, address(fixture.usdcToken), PLATFORM_ADDRESS, DEFAULT_OWNER);
        verifyEscrowConfiguration(escrow2, MERCHANT_2, address(fixture.usdcToken), PLATFORM_ADDRESS, NEW_DEFAULT_OWNER);
    }

    // ============ Combined Address Management Tests ============

    function test_SetBothAddresses_Success() public {
        // No prank needed - test contract is owner
        
        // Change both addresses
        fixture.factory.setPlatformAddress(NEW_PLATFORM);
        fixture.factory.setDefaultOwner(NEW_DEFAULT_OWNER);
        
        // No prank used

        // Verify both changes
        assertEq(fixture.factory.platformAddress(), NEW_PLATFORM);
        assertEq(fixture.factory.defaultOwner(), NEW_DEFAULT_OWNER);
    }

    function test_SetBothAddresses_AffectsNewDeployments() public {
        // No prank needed - test contract is owner
        
        // Change both addresses
        fixture.factory.setPlatformAddress(NEW_PLATFORM);
        fixture.factory.setDefaultOwner(NEW_DEFAULT_OWNER);
        
        // Deploy escrow with new addresses
        address escrow = fixture.factory.deployEscrow(
            MERCHANT_ID_1,
            MERCHANT_1,
            address(fixture.usdcToken)
        );
        
        // No prank used

        // Verify escrow uses new addresses
        verifyEscrowConfiguration(escrow, MERCHANT_1, address(fixture.usdcToken), NEW_PLATFORM, NEW_DEFAULT_OWNER);
    }

    // ============ Address Prediction After Changes ============

    function test_PredictEscrowAddress_AfterPlatformChange() public {
        // Predict address with original platform
        address predicted1 = fixture.factory.predictEscrowAddress(
            MERCHANT_ID_1,
            MERCHANT_1,
            address(fixture.usdcToken)
        );

        // Change platform address
        // No prank needed - test contract is owner
        fixture.factory.setPlatformAddress(NEW_PLATFORM);

        // Predict address with new platform
        address predicted2 = fixture.factory.predictEscrowAddress(
            MERCHANT_ID_1,
            MERCHANT_1,
            address(fixture.usdcToken)
        );

        // Addresses should be different
        assertTrue(predicted1 != predicted2);

        // Deploy and verify prediction accuracy
        // No prank needed - test contract is owner
        address deployed = fixture.factory.deployEscrow(
            MERCHANT_ID_1,
            MERCHANT_1,
            address(fixture.usdcToken)
        );

        assertEq(deployed, predicted2);
    }

    function test_PredictEscrowAddress_AfterDefaultOwnerChange() public {
        // Predict address with original owner
        address predicted1 = fixture.factory.predictEscrowAddress(
            MERCHANT_ID_1,
            MERCHANT_1,
            address(fixture.usdcToken)
        );

        // Change default owner
        // No prank needed - test contract is owner
        fixture.factory.setDefaultOwner(NEW_DEFAULT_OWNER);

        // Predict address with new owner
        address predicted2 = fixture.factory.predictEscrowAddress(
            MERCHANT_ID_1,
            MERCHANT_1,
            address(fixture.usdcToken)
        );

        // Addresses should be different
        assertTrue(predicted1 != predicted2);

        // Deploy and verify prediction accuracy
        // No prank needed - test contract is owner
        address deployed = fixture.factory.deployEscrow(
            MERCHANT_ID_1,
            MERCHANT_1,
            address(fixture.usdcToken)
        );

        assertEq(deployed, predicted2);
    }

    // ============ Edge Cases ============

    function test_SetSameAddress_Success() public {
        address currentPlatform = fixture.factory.platformAddress();
        address currentOwner = fixture.factory.defaultOwner();

        // No prank needed - test contract is owner
        
        // Setting same addresses should succeed
        vm.expectEmit(true, true, true, true);
        emit PlatformAddressUpdated(currentPlatform, currentPlatform);
        fixture.factory.setPlatformAddress(currentPlatform);
        
        vm.expectEmit(true, true, true, true);
        emit DefaultOwnerUpdated(currentOwner, currentOwner);
        fixture.factory.setDefaultOwner(currentOwner);
        
        // No prank used

        // Verify addresses unchanged
        assertEq(fixture.factory.platformAddress(), currentPlatform);
        assertEq(fixture.factory.defaultOwner(), currentOwner);
    }

    function test_AddressManagement_DoesNotAffectExistingEscrows() public {
        // Deploy escrow with original addresses
        // No prank needed - test contract is owner
        address escrow = fixture.factory.deployEscrow(
            MERCHANT_ID_1,
            MERCHANT_1,
            address(fixture.usdcToken)
        );

        // Change both addresses
        // No prank needed - test contract is owner
        fixture.factory.setPlatformAddress(NEW_PLATFORM);
        fixture.factory.setDefaultOwner(NEW_DEFAULT_OWNER);
        // No prank used

        // Verify existing escrow still has original addresses
        verifyEscrowConfiguration(escrow, MERCHANT_1, address(fixture.usdcToken), PLATFORM_ADDRESS, DEFAULT_OWNER);
    }
}
