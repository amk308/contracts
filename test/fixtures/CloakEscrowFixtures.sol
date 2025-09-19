// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {CloakEscrow} from "../../src/CloakEscrow.sol";
import {MockERC20} from "../utils/MockERC20.sol";

/**
 * @title CloakEscrowFixtures
 * @dev Provides standardized test fixtures and setup utilities for CloakEscrow tests
 */
contract CloakEscrowFixtures is Test {
    // Standard test addresses
    address public constant OWNER = address(0x1);
    address public constant MERCHANT = address(0x2);
    address public constant PLATFORM = address(0x3);
    address public constant NEW_MERCHANT = address(0x4);
    address public constant NEW_PLATFORM = address(0x5);
    address public constant USER = address(0x6);
    address public constant ADMIN = address(0x7);
    
    // Token configurations
    struct TokenConfig {
        string name;
        string symbol;
        uint8 decimals;
        uint256 mintAmount;
    }
    
    // Standard token configurations for testing
    function getUSDCConfig() public pure returns (TokenConfig memory) {
        return TokenConfig("Mock USDC", "USDC", 6, 10000 * 10**6);
    }
    
    function getDAIConfig() public pure returns (TokenConfig memory) {
        return TokenConfig("Mock DAI", "DAI", 18, 10000 * 10**18);
    }
    
    function getWBTCConfig() public pure returns (TokenConfig memory) {
        return TokenConfig("Mock WBTC", "WBTC", 8, 10 * 10**8);
    }
    
    // Test fixture data
    struct EscrowFixture {
        CloakEscrow escrow;
        MockERC20 token;
        TokenConfig config;
    }
    
    /**
     * @dev Creates a complete escrow fixture with token and escrow contract
     * @param config Token configuration to use
     * @return fixture Complete fixture with escrow and token
     */
    function createEscrowFixture(TokenConfig memory config) public returns (EscrowFixture memory fixture) {
        // Deploy mock token
        fixture.token = new MockERC20(config.name, config.symbol, config.decimals);
        fixture.config = config;
        
        // Deploy escrow contract
        fixture.escrow = new CloakEscrow(
            MERCHANT,
            address(fixture.token),
            PLATFORM,
            OWNER
        );
        
        // Mint tokens to admin for distribution in tests
        fixture.token.mint(ADMIN, config.mintAmount);
        
        return fixture;
    }
    
    /**
     * @dev Creates multiple escrow fixtures for different token types
     * @return usdcFixture USDC (6 decimals) fixture
     * @return daiFixture DAI (18 decimals) fixture  
     * @return wbtcFixture WBTC (8 decimals) fixture
     */
    function createMultiTokenFixtures() public returns (
        EscrowFixture memory usdcFixture,
        EscrowFixture memory daiFixture,
        EscrowFixture memory wbtcFixture
    ) {
        usdcFixture = createEscrowFixture(getUSDCConfig());
        daiFixture = createEscrowFixture(getDAIConfig());
        wbtcFixture = createEscrowFixture(getWBTCConfig());
        
        return (usdcFixture, daiFixture, wbtcFixture);
    }
    
    /**
     * @dev Creates a simple escrow fixture with USDC (most common case)
     * @return fixture USDC escrow fixture
     */
    function createSimpleFixture() public returns (EscrowFixture memory fixture) {
        return createEscrowFixture(getUSDCConfig());
    }
    
    /**
     * @dev Creates a custom token configuration
     * @param name Token name
     * @param symbol Token symbol
     * @param decimals Token decimals
     * @param mintAmount Amount to mint to admin
     * @return config Custom token configuration
     */
    function createCustomTokenConfig(
        string memory name,
        string memory symbol,
        uint8 decimals,
        uint256 mintAmount
    ) public pure returns (TokenConfig memory config) {
        return TokenConfig(name, symbol, decimals, mintAmount);
    }
    
    /**
     * @dev Funds an escrow contract with tokens from admin
     * @param fixture The escrow fixture to fund
     * @param amount Amount of tokens to transfer
     */
    function fundEscrow(EscrowFixture memory fixture, uint256 amount) public {
        vm.prank(ADMIN);
        fixture.token.transfer(address(fixture.escrow), amount);
    }
    
    /**
     * @dev Gets standard test amounts for different token decimals
     * @param decimals Token decimals
     * @return testAmount Standard test amount for the given decimals
     */
    function getStandardTestAmount(uint8 decimals) public pure returns (uint256 testAmount) {
        if (decimals == 6) {
            return 1000 * 10**6; // 1000 USDC
        } else if (decimals == 18) {
            return 1000 * 10**18; // 1000 DAI
        } else if (decimals == 8) {
            return 1 * 10**8; // 1 WBTC
        } else {
            return 1000 * 10**decimals; // Default: 1000 tokens
        }
    }
    
    /**
     * @dev Calculates expected platform and merchant amounts
     * @param totalAmount Total amount to distribute
     * @param feeBasisPoints Platform fee in basis points
     * @return platformAmount Expected platform amount
     * @return merchantAmount Expected merchant amount
     */
    function calculateDistribution(uint256 totalAmount, uint256 feeBasisPoints) 
        public 
        pure 
        returns (uint256 platformAmount, uint256 merchantAmount) 
    {
        platformAmount = (totalAmount * feeBasisPoints) / 10000;
        merchantAmount = totalAmount - platformAmount;
        return (platformAmount, merchantAmount);
    }
    
    /**
     * @dev Sets up mock users with labeled addresses for better test readability
     */
    function setupMockUsers() public {
        vm.label(OWNER, "Owner");
        vm.label(MERCHANT, "Merchant");
        vm.label(PLATFORM, "Platform");
        vm.label(NEW_MERCHANT, "NewMerchant");
        vm.label(NEW_PLATFORM, "NewPlatform");
        vm.label(USER, "User");
        vm.label(ADMIN, "Admin");
    }
}
