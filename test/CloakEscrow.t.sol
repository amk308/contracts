// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {CloakEscrow} from "../src/CloakEscrow.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// Mock ERC20 tokens with different decimals for testing
contract MockToken6Decimals is ERC20 {
    constructor() ERC20("Mock USDC", "USDC") {}

    function decimals() public pure override returns (uint8) {
        return 6;
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract MockToken18Decimals is ERC20 {
    constructor() ERC20("Mock DAI", "DAI") {}

    function decimals() public pure override returns (uint8) {
        return 18;
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract MockToken8Decimals is ERC20 {
    constructor() ERC20("Mock WBTC", "WBTC") {}

    function decimals() public pure override returns (uint8) {
        return 8;
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract CloakEscrowTest is Test {
    CloakEscrow public escrow6;
    CloakEscrow public escrow18;
    CloakEscrow public escrow8;

    MockToken6Decimals public token6;
    MockToken18Decimals public token18;
    MockToken8Decimals public token8;

    address public owner = address(0x1);
    address public merchant = address(0x2);
    address public platform = address(0x3);
    address public newMerchant = address(0x4);
    address public newPlatform = address(0x5);
    address public user = address(0x6);

    // Test amounts for different decimals
    uint256 public constant AMOUNT_6_DECIMALS = 1000 * 10 ** 6; // 1000 USDC
    uint256 public constant AMOUNT_18_DECIMALS = 1000 * 10 ** 18; // 1000 DAI
    uint256 public constant AMOUNT_8_DECIMALS = 1 * 10 ** 8; // 1 WBTC

    event PlatformFeeUpdated(uint256 oldFee, uint256 newFee);
    event MerchantAddressUpdated(address oldAddress, address newAddress);
    event PlatformAddressUpdated(address oldAddress, address newAddress);
    event FundsDistributed(uint256 platformAmount, uint256 merchantAmount);
    event ContractPaused(address account);
    event ContractUnpaused(address account);

    function setUp() public {
        // Deploy mock tokens
        token6 = new MockToken6Decimals();
        token18 = new MockToken18Decimals();
        token8 = new MockToken8Decimals();

        // Deploy escrow contracts for each token type
        escrow6 = new CloakEscrow(merchant, address(token6), platform, owner);
        escrow18 = new CloakEscrow(merchant, address(token18), platform, owner);
        escrow8 = new CloakEscrow(merchant, address(token8), platform, owner);

        // Mint tokens to user for testing
        token6.mint(user, AMOUNT_6_DECIMALS * 10); // 10,000 USDC
        token18.mint(user, AMOUNT_18_DECIMALS * 10); // 10,000 DAI
        token8.mint(user, AMOUNT_8_DECIMALS * 10); // 10 WBTC
    }

    // ============ Constructor Tests ============

    function test_Constructor_ValidParameters() public {
        CloakEscrow newEscrow = new CloakEscrow(merchant, address(token6), platform, owner);

        assertEq(newEscrow.merchantAddress(), merchant);
        assertEq(newEscrow.platformAddress(), platform);
        assertEq(newEscrow.paymentTokenAddress(), address(token6));
        assertEq(newEscrow.owner(), owner);
        assertEq(newEscrow.platformFeeBasisPoints(), 250); // Default 2.5%
        assertFalse(newEscrow.paused());
    }

    function test_Constructor_RevertInvalidMerchantAddress() public {
        vm.expectRevert(CloakEscrow.InvalidAddress.selector);
        new CloakEscrow(address(0), address(token6), platform, owner);
    }

    function test_Constructor_RevertInvalidTokenAddress() public {
        vm.expectRevert(CloakEscrow.InvalidAddress.selector);
        new CloakEscrow(merchant, address(0), platform, owner);
    }

    function test_Constructor_RevertInvalidPlatformAddress() public {
        vm.expectRevert(CloakEscrow.InvalidAddress.selector);
        new CloakEscrow(merchant, address(token6), address(0), owner);
    }

    // ============ Platform Fee Tests ============

    function test_GetPlatformFee() public {
        assertEq(escrow6.getPlatformFee(), 250);
        assertEq(escrow18.getPlatformFee(), 250);
        assertEq(escrow8.getPlatformFee(), 250);
    }

    function test_SetPlatformFee_ValidFee() public {
        vm.prank(owner);
        vm.expectEmit(true, true, true, true);
        emit PlatformFeeUpdated(250, 500);
        escrow6.setPlatformFee(500);

        assertEq(escrow6.getPlatformFee(), 500);
    }

    function test_SetPlatformFee_MaxFee() public {
        vm.prank(owner);
        escrow6.setPlatformFee(5000); // 50%
        assertEq(escrow6.getPlatformFee(), 5000);
    }

    function test_SetPlatformFee_ZeroFee() public {
        vm.prank(owner);
        escrow6.setPlatformFee(0);
        assertEq(escrow6.getPlatformFee(), 0);
    }

    function test_SetPlatformFee_RevertExceedsMax() public {
        vm.prank(owner);
        vm.expectRevert(CloakEscrow.InvalidFeeAmount.selector);
        escrow6.setPlatformFee(5001); // 50.01%
    }

    function test_SetPlatformFee_RevertNotOwner() public {
        vm.prank(user);
        vm.expectRevert();
        escrow6.setPlatformFee(500);
    }

    function test_SetPlatformFee_RevertWhenPaused() public {
        vm.prank(owner);
        escrow6.pause();

        vm.prank(owner);
        vm.expectRevert();
        escrow6.setPlatformFee(500);
    }

    // ============ Address Management Tests ============

    function test_GetMerchantAddress() public {
        assertEq(escrow6.getMerchantAddress(), merchant);
        assertEq(escrow18.getMerchantAddress(), merchant);
        assertEq(escrow8.getMerchantAddress(), merchant);
    }

    function test_SetMerchantAddress_Valid() public {
        vm.prank(owner);
        vm.expectEmit(true, true, true, true);
        emit MerchantAddressUpdated(merchant, newMerchant);
        escrow6.setMerchantAddress(newMerchant);

        assertEq(escrow6.getMerchantAddress(), newMerchant);
    }

    function test_SetMerchantAddress_RevertZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert(CloakEscrow.InvalidAddress.selector);
        escrow6.setMerchantAddress(address(0));
    }

    function test_SetMerchantAddress_RevertNotOwner() public {
        vm.prank(user);
        vm.expectRevert();
        escrow6.setMerchantAddress(newMerchant);
    }

    function test_SetMerchantAddress_WorksWhenPaused() public {
        vm.prank(owner);
        escrow6.pause();

        vm.prank(owner);
        escrow6.setMerchantAddress(newMerchant);
        assertEq(escrow6.getMerchantAddress(), newMerchant);
    }

    function test_GetPlatformAddress() public {
        assertEq(escrow6.getPlatformAddress(), platform);
        assertEq(escrow18.getPlatformAddress(), platform);
        assertEq(escrow8.getPlatformAddress(), platform);
    }

    function test_SetPlatformAddress_Valid() public {
        vm.prank(owner);
        vm.expectEmit(true, true, true, true);
        emit PlatformAddressUpdated(platform, newPlatform);
        escrow6.setPlatformAddress(newPlatform);

        assertEq(escrow6.getPlatformAddress(), newPlatform);
    }

    function test_SetPlatformAddress_RevertZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert(CloakEscrow.InvalidAddress.selector);
        escrow6.setPlatformAddress(address(0));
    }

    function test_SetPlatformAddress_RevertNotOwner() public {
        vm.prank(user);
        vm.expectRevert();
        escrow6.setPlatformAddress(newPlatform);
    }

    function test_SetPlatformAddress_WorksWhenPaused() public {
        vm.prank(owner);
        escrow6.pause();

        vm.prank(owner);
        escrow6.setPlatformAddress(newPlatform);
        assertEq(escrow6.getPlatformAddress(), newPlatform);
    }

    // ============ Distribution Tests - 6 Decimals ============

    function test_Distribute_6Decimals_DefaultFee() public {
        // Transfer tokens to escrow
        vm.prank(user);
        token6.transfer(address(escrow6), AMOUNT_6_DECIMALS);

        uint256 platformAmount = (AMOUNT_6_DECIMALS * 250) / 10000; // 2.5%
        uint256 merchantAmount = AMOUNT_6_DECIMALS - platformAmount;

        vm.expectEmit(true, true, true, true);
        emit FundsDistributed(platformAmount, merchantAmount);

        escrow6.distribute();

        assertEq(token6.balanceOf(platform), platformAmount);
        assertEq(token6.balanceOf(merchant), merchantAmount);
        assertEq(token6.balanceOf(address(escrow6)), 0);
    }

    function test_Distribute_6Decimals_ZeroFee() public {
        vm.prank(owner);
        escrow6.setPlatformFee(0);

        vm.prank(user);
        token6.transfer(address(escrow6), AMOUNT_6_DECIMALS);

        escrow6.distribute();

        assertEq(token6.balanceOf(platform), 0);
        assertEq(token6.balanceOf(merchant), AMOUNT_6_DECIMALS);
        assertEq(token6.balanceOf(address(escrow6)), 0);
    }

    function test_Distribute_6Decimals_MaxFee() public {
        vm.prank(owner);
        escrow6.setPlatformFee(5000); // 50%

        vm.prank(user);
        token6.transfer(address(escrow6), AMOUNT_6_DECIMALS);

        uint256 platformAmount = AMOUNT_6_DECIMALS / 2;
        uint256 merchantAmount = AMOUNT_6_DECIMALS - platformAmount;

        escrow6.distribute();

        assertEq(token6.balanceOf(platform), platformAmount);
        assertEq(token6.balanceOf(merchant), merchantAmount);
    }

    // ============ Distribution Tests - 18 Decimals ============

    function test_Distribute_18Decimals_DefaultFee() public {
        vm.prank(user);
        token18.transfer(address(escrow18), AMOUNT_18_DECIMALS);

        uint256 platformAmount = (AMOUNT_18_DECIMALS * 250) / 10000;
        uint256 merchantAmount = AMOUNT_18_DECIMALS - platformAmount;

        escrow18.distribute();

        assertEq(token18.balanceOf(platform), platformAmount);
        assertEq(token18.balanceOf(merchant), merchantAmount);
        assertEq(token18.balanceOf(address(escrow18)), 0);
    }

    function test_Distribute_18Decimals_CustomFee() public {
        vm.prank(owner);
        escrow18.setPlatformFee(1000); // 10%

        vm.prank(user);
        token18.transfer(address(escrow18), AMOUNT_18_DECIMALS);

        uint256 platformAmount = AMOUNT_18_DECIMALS / 10;
        uint256 merchantAmount = AMOUNT_18_DECIMALS - platformAmount;

        escrow18.distribute();

        assertEq(token18.balanceOf(platform), platformAmount);
        assertEq(token18.balanceOf(merchant), merchantAmount);
    }

    // ============ Distribution Tests - 8 Decimals ============

    function test_Distribute_8Decimals_DefaultFee() public {
        vm.prank(user);
        token8.transfer(address(escrow8), AMOUNT_8_DECIMALS);

        uint256 platformAmount = (AMOUNT_8_DECIMALS * 250) / 10000;
        uint256 merchantAmount = AMOUNT_8_DECIMALS - platformAmount;

        escrow8.distribute();

        assertEq(token8.balanceOf(platform), platformAmount);
        assertEq(token8.balanceOf(merchant), merchantAmount);
        assertEq(token8.balanceOf(address(escrow8)), 0);
    }

    function test_Distribute_8Decimals_SmallAmount() public {
        uint256 smallAmount = 1000; // 0.00001 WBTC
        vm.prank(user);
        token8.transfer(address(escrow8), smallAmount);

        uint256 platformAmount = (smallAmount * 250) / 10000;
        uint256 merchantAmount = smallAmount - platformAmount;

        escrow8.distribute();

        assertEq(token8.balanceOf(platform), platformAmount);
        assertEq(token8.balanceOf(merchant), merchantAmount);
    }

    // ============ Distribution Error Tests ============

    function test_Distribute_RevertNoBalance() public {
        vm.expectRevert(CloakEscrow.NoBalanceToDistribute.selector);
        escrow6.distribute();
    }

    function test_Distribute_RevertWhenPaused() public {
        vm.prank(user);
        token6.transfer(address(escrow6), AMOUNT_6_DECIMALS);

        vm.prank(owner);
        escrow6.pause();

        vm.expectRevert();
        escrow6.distribute();
    }

    // ============ Pausable Tests ============

    function test_Pause_Success() public {
        vm.prank(owner);
        vm.expectEmit(true, true, true, true);
        emit ContractPaused(owner);
        escrow6.pause();

        assertTrue(escrow6.paused());
    }

    function test_Unpause_Success() public {
        vm.prank(owner);
        escrow6.pause();

        vm.prank(owner);
        vm.expectEmit(true, true, true, true);
        emit ContractUnpaused(owner);
        escrow6.unpause();

        assertFalse(escrow6.paused());
    }

    function test_Pause_RevertNotOwner() public {
        vm.prank(user);
        vm.expectRevert();
        escrow6.pause();
    }

    function test_Unpause_RevertNotOwner() public {
        vm.prank(owner);
        escrow6.pause();

        vm.prank(user);
        vm.expectRevert();
        escrow6.unpause();
    }

    // ============ Edge Cases and Precision Tests ============

    function test_Distribute_RoundingPrecision_6Decimals() public {
        // Test with amount that doesn't divide evenly
        uint256 oddAmount = 1001; // 0.001001 USDC
        vm.prank(user);
        token6.transfer(address(escrow6), oddAmount);

        uint256 platformAmount = (oddAmount * 250) / 10000; // Should be 0 due to rounding
        uint256 merchantAmount = oddAmount - platformAmount;

        escrow6.distribute();

        assertEq(token6.balanceOf(platform), platformAmount);
        assertEq(token6.balanceOf(merchant), merchantAmount);
        assertEq(token6.balanceOf(address(escrow6)), 0);
    }

    function test_Distribute_MultipleDistributions() public {
        // First distribution
        vm.prank(user);
        token6.transfer(address(escrow6), AMOUNT_6_DECIMALS);
        escrow6.distribute();

        uint256 firstPlatformBalance = token6.balanceOf(platform);
        uint256 firstMerchantBalance = token6.balanceOf(merchant);

        // Second distribution
        vm.prank(user);
        token6.transfer(address(escrow6), AMOUNT_6_DECIMALS);
        escrow6.distribute();

        assertEq(token6.balanceOf(platform), firstPlatformBalance * 2);
        assertEq(token6.balanceOf(merchant), firstMerchantBalance * 2);
    }

    function test_EmergencyScenario_CompromisedAddresses() public {
        // Simulate compromised addresses scenario
        vm.prank(user);
        token6.transfer(address(escrow6), AMOUNT_6_DECIMALS);

        // Owner pauses contract
        vm.prank(owner);
        escrow6.pause();

        // Distribution should fail when paused
        vm.expectRevert();
        escrow6.distribute();

        // Owner updates addresses while paused
        vm.prank(owner);
        escrow6.setMerchantAddress(newMerchant);
        vm.prank(owner);
        escrow6.setPlatformAddress(newPlatform);

        // Owner unpauses
        vm.prank(owner);
        escrow6.unpause();

        // Distribution should work with new addresses
        escrow6.distribute();

        assertTrue(token6.balanceOf(newPlatform) > 0);
        assertTrue(token6.balanceOf(newMerchant) > 0);
        assertEq(token6.balanceOf(platform), 0);
        assertEq(token6.balanceOf(merchant), 0);
    }

    // ============ Fuzz Tests ============

    function testFuzz_SetPlatformFee(uint256 fee) public {
        vm.assume(fee <= 5000);

        vm.prank(owner);
        escrow6.setPlatformFee(fee);
        assertEq(escrow6.getPlatformFee(), fee);
    }

    function testFuzz_Distribute_6Decimals(uint256 amount, uint256 fee) public {
        vm.assume(amount > 0 && amount <= type(uint128).max);
        vm.assume(fee <= 5000);

        vm.prank(owner);
        escrow6.setPlatformFee(fee);

        // Mint and transfer tokens
        token6.mint(address(escrow6), amount);

        uint256 platformAmount = (amount * fee) / 10000;
        uint256 merchantAmount = amount - platformAmount;

        escrow6.distribute();

        assertEq(token6.balanceOf(platform), platformAmount);
        assertEq(token6.balanceOf(merchant), merchantAmount);
        assertEq(token6.balanceOf(address(escrow6)), 0);
    }
}
