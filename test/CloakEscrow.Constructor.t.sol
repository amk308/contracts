// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {CloakEscrow} from "../src/CloakEscrow.sol";
import {CloakEscrowFixtures} from "./fixtures/CloakEscrowFixtures.sol";

contract CloakEscrowConstructorTest is Test, CloakEscrowFixtures {
    EscrowFixture public fixture;
    
    function setUp() public {
        setupMockUsers();
        fixture = createSimpleFixture();
    }
    
    function test_Constructor_ValidParameters() public {
        CloakEscrow newEscrow = new CloakEscrow(
            MERCHANT, 
            address(fixture.token), 
            PLATFORM, 
            OWNER
        );
        
        assertEq(newEscrow.merchantAddress(), MERCHANT);
        assertEq(newEscrow.platformAddress(), PLATFORM);
        assertEq(newEscrow.paymentTokenAddress(), address(fixture.token));
        assertEq(newEscrow.owner(), OWNER);
        assertEq(newEscrow.platformFeeBasisPoints(), 250); // Default 2.5%
        assertFalse(newEscrow.paused());
    }
    
    function test_Constructor_RevertInvalidMerchantAddress() public {
        vm.expectRevert(CloakEscrow.InvalidAddress.selector);
        new CloakEscrow(address(0), address(fixture.token), PLATFORM, OWNER);
    }
    
    function test_Constructor_RevertInvalidTokenAddress() public {
        vm.expectRevert(CloakEscrow.InvalidAddress.selector);
        new CloakEscrow(MERCHANT, address(0), PLATFORM, OWNER);
    }
    
    function test_Constructor_RevertInvalidPlatformAddress() public {
        vm.expectRevert(CloakEscrow.InvalidAddress.selector);
        new CloakEscrow(MERCHANT, address(fixture.token), address(0), OWNER);
    }
    
    function test_Constructor_WithDifferentTokenDecimals() public {
        (EscrowFixture memory usdcFixture, EscrowFixture memory daiFixture, EscrowFixture memory wbtcFixture) = 
            createMultiTokenFixtures();
        
        // Verify all contracts are properly initialized
        assertEq(usdcFixture.escrow.paymentTokenAddress(), address(usdcFixture.token));
        assertEq(daiFixture.escrow.paymentTokenAddress(), address(daiFixture.token));
        assertEq(wbtcFixture.escrow.paymentTokenAddress(), address(wbtcFixture.token));
        
        // Verify token decimals are correct
        assertEq(usdcFixture.token.decimals(), 6);
        assertEq(daiFixture.token.decimals(), 18);
        assertEq(wbtcFixture.token.decimals(), 8);
    }
    
    function testFuzz_Constructor_ValidAddresses(
        address merchant,
        address platform,
        address owner
    ) public {
        vm.assume(merchant != address(0));
        vm.assume(platform != address(0));
        vm.assume(owner != address(0));
        
        CloakEscrow newEscrow = new CloakEscrow(
            merchant,
            address(fixture.token),
            platform,
            owner
        );
        
        assertEq(newEscrow.merchantAddress(), merchant);
        assertEq(newEscrow.platformAddress(), platform);
        assertEq(newEscrow.owner(), owner);
    }
}
