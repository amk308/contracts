// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {CloakEscrow} from "../src/CloakEscrow.sol";
import {CloakEscrowFixtures} from "./fixtures/CloakEscrowFixtures.sol";

contract CloakEscrowPlatformFeeTest is Test, CloakEscrowFixtures {
    EscrowFixture public fixture;
    
    event PlatformFeeUpdated(uint256 oldFee, uint256 newFee);
    
    function setUp() public {
        setupMockUsers();
        fixture = createSimpleFixture();
    }
    
    function test_GetPlatformFee_DefaultValue() public view {
        assertEq(fixture.escrow.getPlatformFee(), 250); // 2.5%
    }
    
    function test_GetPlatformFee_MultipleTokens() public {
        (EscrowFixture memory usdcFixture, EscrowFixture memory daiFixture, EscrowFixture memory wbtcFixture) = 
            createMultiTokenFixtures();
        
        assertEq(usdcFixture.escrow.getPlatformFee(), 250);
        assertEq(daiFixture.escrow.getPlatformFee(), 250);
        assertEq(wbtcFixture.escrow.getPlatformFee(), 250);
    }
    
    function test_SetPlatformFee_ValidFee() public {
        vm.prank(OWNER);
        vm.expectEmit(true, true, true, true);
        emit PlatformFeeUpdated(250, 500);
        fixture.escrow.setPlatformFee(500);
        
        assertEq(fixture.escrow.getPlatformFee(), 500);
    }
    
    function test_SetPlatformFee_MaxFee() public {
        vm.prank(OWNER);
        fixture.escrow.setPlatformFee(5000); // 50%
        assertEq(fixture.escrow.getPlatformFee(), 5000);
    }
    
    function test_SetPlatformFee_ZeroFee() public {
        vm.prank(OWNER);
        vm.expectEmit(true, true, true, true);
        emit PlatformFeeUpdated(250, 0);
        fixture.escrow.setPlatformFee(0);
        
        assertEq(fixture.escrow.getPlatformFee(), 0);
    }
    
    function test_SetPlatformFee_RevertExceedsMax() public {
        vm.prank(OWNER);
        vm.expectRevert(CloakEscrow.InvalidFeeAmount.selector);
        fixture.escrow.setPlatformFee(5001); // 50.01%
    }
    
    function test_SetPlatformFee_RevertNotOwner() public {
        vm.prank(USER);
        vm.expectRevert();
        fixture.escrow.setPlatformFee(500);
    }
    
    function test_SetPlatformFee_RevertWhenPaused() public {
        vm.prank(OWNER);
        fixture.escrow.pause();
        
        vm.prank(OWNER);
        vm.expectRevert();
        fixture.escrow.setPlatformFee(500);
    }
    
    function test_SetPlatformFee_MultipleFeeChanges() public {
        uint256[] memory fees = new uint256[](5);
        fees[0] = 100;  // 1%
        fees[1] = 500;  // 5%
        fees[2] = 1000; // 10%
        fees[3] = 2500; // 25%
        fees[4] = 0;    // 0%
        
        for (uint256 i = 0; i < fees.length; i++) {
            vm.prank(OWNER);
            fixture.escrow.setPlatformFee(fees[i]);
            assertEq(fixture.escrow.getPlatformFee(), fees[i]);
        }
    }
    
    function test_SetPlatformFee_EmitsCorrectEvent() public {
        vm.prank(OWNER);
        vm.expectEmit(true, true, true, true);
        emit PlatformFeeUpdated(250, 1500);
        fixture.escrow.setPlatformFee(1500);
        
        // Change again to test different old value
        vm.prank(OWNER);
        vm.expectEmit(true, true, true, true);
        emit PlatformFeeUpdated(1500, 750);
        fixture.escrow.setPlatformFee(750);
    }
    
    function testFuzz_SetPlatformFee_ValidRange(uint256 fee) public {
        vm.assume(fee <= 5000);
        
        vm.prank(OWNER);
        fixture.escrow.setPlatformFee(fee);
        assertEq(fixture.escrow.getPlatformFee(), fee);
    }
    
    function testFuzz_SetPlatformFee_InvalidRange(uint256 fee) public {
        vm.assume(fee > 5000 && fee <= type(uint256).max);
        
        vm.prank(OWNER);
        vm.expectRevert(CloakEscrow.InvalidFeeAmount.selector);
        fixture.escrow.setPlatformFee(fee);
    }
    
    function test_PlatformFee_BoundaryValues() public {
        // Test boundary values
        uint256[] memory boundaryFees = new uint256[](3);
        boundaryFees[0] = 0;    // Minimum
        boundaryFees[1] = 5000; // Maximum
        boundaryFees[2] = 2500; // Middle
        
        for (uint256 i = 0; i < boundaryFees.length; i++) {
            vm.prank(OWNER);
            fixture.escrow.setPlatformFee(boundaryFees[i]);
            assertEq(fixture.escrow.getPlatformFee(), boundaryFees[i]);
        }
    }
}
