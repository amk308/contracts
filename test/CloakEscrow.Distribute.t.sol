// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {CloakEscrow} from "../src/CloakEscrow.sol";
import {CloakEscrowFixtures} from "./fixtures/CloakEscrowFixtures.sol";

contract CloakEscrowDistributeTest is Test, CloakEscrowFixtures {
    EscrowFixture public usdcFixture;
    EscrowFixture public daiFixture;
    EscrowFixture public wbtcFixture;
    
    event FundsDistributed(uint256 platformAmount, uint256 merchantAmount);
    
    function setUp() public {
        setupMockUsers();
        (usdcFixture, daiFixture, wbtcFixture) = createMultiTokenFixtures();
    }
    
    // ============ Distribution Tests - 6 Decimals (USDC) ============
    
    function test_Distribute_USDC_DefaultFee() public {
        uint256 amount = getStandardTestAmount(6);
        fundEscrow(usdcFixture, amount);
        
        (uint256 expectedPlatform, uint256 expectedMerchant) = calculateDistribution(amount, 250);
        
        vm.expectEmit(true, true, true, true);
        emit FundsDistributed(expectedPlatform, expectedMerchant);
        
        usdcFixture.escrow.distribute();
        
        assertEq(usdcFixture.token.balanceOf(PLATFORM), expectedPlatform);
        assertEq(usdcFixture.token.balanceOf(MERCHANT), expectedMerchant);
        assertEq(usdcFixture.token.balanceOf(address(usdcFixture.escrow)), 0);
    }
    
    function test_Distribute_USDC_ZeroFee() public {
        vm.prank(OWNER);
        usdcFixture.escrow.setPlatformFee(0);
        
        uint256 amount = getStandardTestAmount(6);
        fundEscrow(usdcFixture, amount);
        
        usdcFixture.escrow.distribute();
        
        assertEq(usdcFixture.token.balanceOf(PLATFORM), 0);
        assertEq(usdcFixture.token.balanceOf(MERCHANT), amount);
        assertEq(usdcFixture.token.balanceOf(address(usdcFixture.escrow)), 0);
    }
    
    function test_Distribute_USDC_MaxFee() public {
        vm.prank(OWNER);
        usdcFixture.escrow.setPlatformFee(5000); // 50%
        
        uint256 amount = getStandardTestAmount(6);
        fundEscrow(usdcFixture, amount);
        
        uint256 platformAmount = amount / 2;
        uint256 merchantAmount = amount - platformAmount;
        
        usdcFixture.escrow.distribute();
        
        assertEq(usdcFixture.token.balanceOf(PLATFORM), platformAmount);
        assertEq(usdcFixture.token.balanceOf(MERCHANT), merchantAmount);
    }
    
    function test_Distribute_USDC_SmallAmount() public {
        uint256 smallAmount = 100; // 0.0001 USDC
        fundEscrow(usdcFixture, smallAmount);
        
        (uint256 expectedPlatform, uint256 expectedMerchant) = calculateDistribution(smallAmount, 250);
        
        usdcFixture.escrow.distribute();
        
        assertEq(usdcFixture.token.balanceOf(PLATFORM), expectedPlatform);
        assertEq(usdcFixture.token.balanceOf(MERCHANT), expectedMerchant);
    }
    
    // ============ Distribution Tests - 18 Decimals (DAI) ============
    
    function test_Distribute_DAI_DefaultFee() public {
        uint256 amount = getStandardTestAmount(18);
        fundEscrow(daiFixture, amount);
        
        (uint256 expectedPlatform, uint256 expectedMerchant) = calculateDistribution(amount, 250);
        
        daiFixture.escrow.distribute();
        
        assertEq(daiFixture.token.balanceOf(PLATFORM), expectedPlatform);
        assertEq(daiFixture.token.balanceOf(MERCHANT), expectedMerchant);
        assertEq(daiFixture.token.balanceOf(address(daiFixture.escrow)), 0);
    }
    
    function test_Distribute_DAI_CustomFee() public {
        vm.prank(OWNER);
        daiFixture.escrow.setPlatformFee(1000); // 10%
        
        uint256 amount = getStandardTestAmount(18);
        fundEscrow(daiFixture, amount);
        
        uint256 platformAmount = amount / 10;
        uint256 merchantAmount = amount - platformAmount;
        
        daiFixture.escrow.distribute();
        
        assertEq(daiFixture.token.balanceOf(PLATFORM), platformAmount);
        assertEq(daiFixture.token.balanceOf(MERCHANT), merchantAmount);
    }
    
    function test_Distribute_DAI_HighPrecisionAmount() public {
        uint256 preciseAmount = 123456789123456789; // 0.123456789123456789 DAI
        fundEscrow(daiFixture, preciseAmount);
        
        (uint256 expectedPlatform, uint256 expectedMerchant) = calculateDistribution(preciseAmount, 250);
        
        daiFixture.escrow.distribute();
        
        assertEq(daiFixture.token.balanceOf(PLATFORM), expectedPlatform);
        assertEq(daiFixture.token.balanceOf(MERCHANT), expectedMerchant);
    }
    
    // ============ Distribution Tests - 8 Decimals (WBTC) ============
    
    function test_Distribute_WBTC_DefaultFee() public {
        uint256 amount = getStandardTestAmount(8);
        fundEscrow(wbtcFixture, amount);
        
        (uint256 expectedPlatform, uint256 expectedMerchant) = calculateDistribution(amount, 250);
        
        wbtcFixture.escrow.distribute();
        
        assertEq(wbtcFixture.token.balanceOf(PLATFORM), expectedPlatform);
        assertEq(wbtcFixture.token.balanceOf(MERCHANT), expectedMerchant);
        assertEq(wbtcFixture.token.balanceOf(address(wbtcFixture.escrow)), 0);
    }
    
    function test_Distribute_WBTC_SmallAmount() public {
        uint256 smallAmount = 1000; // 0.00001 WBTC
        fundEscrow(wbtcFixture, smallAmount);
        
        (uint256 expectedPlatform, uint256 expectedMerchant) = calculateDistribution(smallAmount, 250);
        
        wbtcFixture.escrow.distribute();
        
        assertEq(wbtcFixture.token.balanceOf(PLATFORM), expectedPlatform);
        assertEq(wbtcFixture.token.balanceOf(MERCHANT), expectedMerchant);
    }
    
    // ============ Distribution Error Tests ============
    
    function test_Distribute_RevertNoBalance() public {
        vm.expectRevert(CloakEscrow.NoBalanceToDistribute.selector);
        usdcFixture.escrow.distribute();
    }
    
    function test_Distribute_RevertWhenPaused() public {
        uint256 amount = getStandardTestAmount(6);
        fundEscrow(usdcFixture, amount);
        
        vm.prank(OWNER);
        usdcFixture.escrow.pause();
        
        vm.expectRevert();
        usdcFixture.escrow.distribute();
    }
    
    // ============ Multiple Distribution Tests ============
    
    function test_Distribute_MultipleDistributions() public {
        uint256 amount = getStandardTestAmount(6);
        
        // First distribution
        fundEscrow(usdcFixture, amount);
        usdcFixture.escrow.distribute();
        
        uint256 firstPlatformBalance = usdcFixture.token.balanceOf(PLATFORM);
        uint256 firstMerchantBalance = usdcFixture.token.balanceOf(MERCHANT);
        
        // Second distribution
        fundEscrow(usdcFixture, amount);
        usdcFixture.escrow.distribute();
        
        assertEq(usdcFixture.token.balanceOf(PLATFORM), firstPlatformBalance * 2);
        assertEq(usdcFixture.token.balanceOf(MERCHANT), firstMerchantBalance * 2);
    }
    
    function test_Distribute_DifferentAmounts() public {
        uint256[] memory amounts = new uint256[](4);
        amounts[0] = 1000 * 10**6;  // 1000 USDC
        amounts[1] = 500 * 10**6;   // 500 USDC
        amounts[2] = 2000 * 10**6;  // 2000 USDC
        amounts[3] = 100 * 10**6;   // 100 USDC
        
        uint256 totalPlatform = 0;
        uint256 totalMerchant = 0;
        
        for (uint256 i = 0; i < amounts.length; i++) {
            fundEscrow(usdcFixture, amounts[i]);
            
            (uint256 expectedPlatform, uint256 expectedMerchant) = calculateDistribution(amounts[i], 250);
            totalPlatform += expectedPlatform;
            totalMerchant += expectedMerchant;
            
            usdcFixture.escrow.distribute();
        }
        
        assertEq(usdcFixture.token.balanceOf(PLATFORM), totalPlatform);
        assertEq(usdcFixture.token.balanceOf(MERCHANT), totalMerchant);
    }
    
    // ============ Precision and Rounding Tests ============
    
    function test_Distribute_RoundingPrecision() public {
        // Test with amount that doesn't divide evenly
        uint256 oddAmount = 1001; // 0.001001 USDC
        fundEscrow(usdcFixture, oddAmount);
        
        (uint256 expectedPlatform, uint256 expectedMerchant) = calculateDistribution(oddAmount, 250);
        
        usdcFixture.escrow.distribute();
        
        assertEq(usdcFixture.token.balanceOf(PLATFORM), expectedPlatform);
        assertEq(usdcFixture.token.balanceOf(MERCHANT), expectedMerchant);
        assertEq(usdcFixture.token.balanceOf(address(usdcFixture.escrow)), 0);
        
        // Verify total is preserved (no tokens lost to rounding)
        assertEq(expectedPlatform + expectedMerchant, oddAmount);
    }
    
    function test_Distribute_VerySmallFee() public {
        vm.prank(OWNER);
        usdcFixture.escrow.setPlatformFee(1); // 0.01%
        
        uint256 amount = 10000 * 10**6; // 10,000 USDC
        fundEscrow(usdcFixture, amount);
        
        (uint256 expectedPlatform, uint256 expectedMerchant) = calculateDistribution(amount, 1);
        
        usdcFixture.escrow.distribute();
        
        assertEq(usdcFixture.token.balanceOf(PLATFORM), expectedPlatform);
        assertEq(usdcFixture.token.balanceOf(MERCHANT), expectedMerchant);
    }
    
    // ============ Address Change During Distribution Tests ============
    
    function test_Distribute_AfterAddressChange() public {
        uint256 amount = getStandardTestAmount(6);
        fundEscrow(usdcFixture, amount);
        
        // Change addresses
        vm.prank(OWNER);
        usdcFixture.escrow.setMerchantAddress(NEW_MERCHANT);
        vm.prank(OWNER);
        usdcFixture.escrow.setPlatformAddress(NEW_PLATFORM);
        
        (uint256 expectedPlatform, uint256 expectedMerchant) = calculateDistribution(amount, 250);
        
        usdcFixture.escrow.distribute();
        
        // Verify funds go to new addresses
        assertEq(usdcFixture.token.balanceOf(NEW_PLATFORM), expectedPlatform);
        assertEq(usdcFixture.token.balanceOf(NEW_MERCHANT), expectedMerchant);
        
        // Verify old addresses receive nothing
        assertEq(usdcFixture.token.balanceOf(PLATFORM), 0);
        assertEq(usdcFixture.token.balanceOf(MERCHANT), 0);
    }
    
    // ============ Fuzz Tests ============
    
    function testFuzz_Distribute_USDC(uint256 amount, uint256 fee) public {
        vm.assume(amount > 0 && amount <= type(uint128).max);
        vm.assume(fee <= 5000);
        
        vm.prank(OWNER);
        usdcFixture.escrow.setPlatformFee(fee);
        
        // Mint tokens directly to escrow for fuzz testing
        usdcFixture.token.mint(address(usdcFixture.escrow), amount);
        
        (uint256 expectedPlatform, uint256 expectedMerchant) = calculateDistribution(amount, fee);
        
        usdcFixture.escrow.distribute();
        
        assertEq(usdcFixture.token.balanceOf(PLATFORM), expectedPlatform);
        assertEq(usdcFixture.token.balanceOf(MERCHANT), expectedMerchant);
        assertEq(usdcFixture.token.balanceOf(address(usdcFixture.escrow)), 0);
    }
    
    function testFuzz_Distribute_DAI(uint256 amount, uint256 fee) public {
        vm.assume(amount > 0 && amount <= type(uint128).max);
        vm.assume(fee <= 5000);
        
        vm.prank(OWNER);
        daiFixture.escrow.setPlatformFee(fee);
        
        daiFixture.token.mint(address(daiFixture.escrow), amount);
        
        (uint256 expectedPlatform, uint256 expectedMerchant) = calculateDistribution(amount, fee);
        
        daiFixture.escrow.distribute();
        
        assertEq(daiFixture.token.balanceOf(PLATFORM), expectedPlatform);
        assertEq(daiFixture.token.balanceOf(MERCHANT), expectedMerchant);
        assertEq(daiFixture.token.balanceOf(address(daiFixture.escrow)), 0);
    }
}
