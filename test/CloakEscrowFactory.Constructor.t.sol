// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {CloakEscrowFactory} from "../src/CloakEscrowFactory.sol";
import {CloakEscrowFactoryFixtures} from "./fixtures/CloakEscrowFactoryFixtures.sol";

contract CloakEscrowFactoryConstructorTest is Test, CloakEscrowFactoryFixtures {
    function setUp() public {
        setupMockUsers();
    }

    // ============ Constructor Success Tests ============

    function test_Constructor_Success() public {
        CloakEscrowFactory factory = new CloakEscrowFactory(PLATFORM_ADDRESS, DEFAULT_OWNER);

        assertEq(factory.owner(), address(this));
        assertEq(factory.platformAddress(), PLATFORM_ADDRESS);
        assertEq(factory.defaultOwner(), DEFAULT_OWNER);
        assertFalse(factory.paused());
    }

    function test_Constructor_SuccessWithDifferentAddresses() public {
        address customPlatform = address(0x123);
        address customOwner = address(0x456);

        CloakEscrowFactory factory = new CloakEscrowFactory(customPlatform, customOwner);

        assertEq(factory.owner(), address(this));
        assertEq(factory.platformAddress(), customPlatform);
        assertEq(factory.defaultOwner(), customOwner);
    }

    // ============ Constructor Failure Tests ============

    function test_Constructor_RevertZeroPlatformAddress() public {
        vm.expectRevert(CloakEscrowFactory.InvalidAddress.selector);
        new CloakEscrowFactory(address(0), DEFAULT_OWNER);
    }

    function test_Constructor_RevertZeroDefaultOwner() public {
        vm.expectRevert(CloakEscrowFactory.InvalidAddress.selector);
        new CloakEscrowFactory(PLATFORM_ADDRESS, address(0));
    }

    function test_Constructor_RevertBothZeroAddresses() public {
        vm.expectRevert(CloakEscrowFactory.InvalidAddress.selector);
        new CloakEscrowFactory(address(0), address(0));
    }

    // ============ Initial State Tests ============

    function test_InitialState_EmptyMappings() public {
        CloakEscrowFactory factory = new CloakEscrowFactory(PLATFORM_ADDRESS, DEFAULT_OWNER);

        // Check merchant mappings are empty
        assertEq(factory.getMerchantEscrowCount(MERCHANT_ID_1), 0);
        assertEq(factory.getMerchantCounter(MERCHANT_ID_1), 0);
        assertFalse(factory.merchantExists(MERCHANT_ID_1));

        // Check escrow arrays are empty
        address[] memory escrows = factory.getEscrowsForMerchant(MERCHANT_ID_1);
        assertEq(escrows.length, 0);
    }

    function test_InitialState_MultipleRandomMerchants() public {
        CloakEscrowFactory factory = new CloakEscrowFactory(PLATFORM_ADDRESS, DEFAULT_OWNER);

        for (uint256 i = 0; i < 10; i++) {
            bytes32 randomMerchantId = generateRandomMerchantId(i);

            assertEq(factory.getMerchantEscrowCount(randomMerchantId), 0);
            assertEq(factory.getMerchantCounter(randomMerchantId), 0);
            assertFalse(factory.merchantExists(randomMerchantId));

            address[] memory escrows = factory.getEscrowsForMerchant(randomMerchantId);
            assertEq(escrows.length, 0);
        }
    }
}
