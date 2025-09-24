// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {CloakEscrowFactory} from "../../src/CloakEscrowFactory.sol";
import {CloakEscrow} from "../../src/CloakEscrow.sol";
import {MockERC20} from "../utils/MockERC20.sol";

/**
 * @title CloakEscrowFactoryFixtures
 * @dev Provides standardized test fixtures and setup utilities for CloakEscrowFactory tests
 */
contract CloakEscrowFactoryFixtures is Test {
    // Standard test addresses
    address public constant FACTORY_OWNER = address(0x1);
    address public constant PLATFORM_ADDRESS = address(0x2);
    address public constant DEFAULT_OWNER = address(0x3);
    address public constant MERCHANT_1 = address(0x4);
    address public constant MERCHANT_2 = address(0x5);
    address public constant USER = address(0x6);
    address public constant ADMIN = address(0x7);
    address public constant NEW_PLATFORM = address(0x8);
    address public constant NEW_DEFAULT_OWNER = address(0x9);
    address public constant NEW_MERCHANT = address(0xA);

    // Standard merchant IDs
    bytes32 public constant MERCHANT_ID_1 = keccak256("merchant_1");
    bytes32 public constant MERCHANT_ID_2 = keccak256("merchant_2");
    bytes32 public constant MERCHANT_ID_3 = keccak256("merchant_3");
    bytes32 public constant INVALID_MERCHANT_ID = bytes32(0);

    // Token configurations
    struct TokenConfig {
        string name;
        string symbol;
        uint8 decimals;
        uint256 mintAmount;
    }

    // Factory fixture data
    struct FactoryFixture {
        CloakEscrowFactory factory;
        MockERC20 usdcToken;
        MockERC20 daiToken;
        TokenConfig usdcConfig;
        TokenConfig daiConfig;
    }

    // Deployment result data
    struct DeploymentResult {
        address escrowAddress;
        bytes32 merchantId;
        address merchantAddress;
        address paymentToken;
        uint256 counter;
    }

    /**
     * @dev Standard token configurations for testing
     */
    function getUSDCConfig() public pure returns (TokenConfig memory) {
        return TokenConfig("Mock USDC", "USDC", 6, 1000000 * 10 ** 6); // 1M USDC
    }

    function getDAIConfig() public pure returns (TokenConfig memory) {
        return TokenConfig("Mock DAI", "DAI", 18, 1000000 * 10 ** 18); // 1M DAI
    }

    /**
     * @dev Creates a complete factory fixture with tokens and factory contract
     * @return fixture Complete fixture with factory and tokens
     */
    function createFactoryFixture() public returns (FactoryFixture memory fixture) {
        // Get token configs
        fixture.usdcConfig = getUSDCConfig();
        fixture.daiConfig = getDAIConfig();

        // Deploy mock tokens
        fixture.usdcToken = new MockERC20(
            fixture.usdcConfig.name,
            fixture.usdcConfig.symbol,
            fixture.usdcConfig.decimals
        );
        fixture.daiToken = new MockERC20(
            fixture.daiConfig.name,
            fixture.daiConfig.symbol,
            fixture.daiConfig.decimals
        );

        // Deploy factory contract (test contract becomes owner)
        fixture.factory = new CloakEscrowFactory(PLATFORM_ADDRESS, DEFAULT_OWNER);

        // Mint tokens to admin for testing
        fixture.usdcToken.mint(ADMIN, fixture.usdcConfig.mintAmount);
        fixture.daiToken.mint(ADMIN, fixture.daiConfig.mintAmount);

        return fixture;
    }

    /**
     * @dev Creates a factory fixture and deploys a single escrow for testing
     * @param merchantId The merchant ID to use
     * @param merchantAddress The merchant address to use
     * @return fixture The factory fixture
     * @return result The deployment result
     */
    function createFactoryWithSingleEscrow(bytes32 merchantId, address merchantAddress)
        public
        returns (FactoryFixture memory fixture, DeploymentResult memory result)
    {
        fixture = createFactoryFixture();

        // Deploy escrow
        vm.prank(FACTORY_OWNER);
        address escrowAddress = fixture.factory.deployEscrow(
            merchantId,
            merchantAddress,
            address(fixture.usdcToken)
        );

        result = DeploymentResult({
            escrowAddress: escrowAddress,
            merchantId: merchantId,
            merchantAddress: merchantAddress,
            paymentToken: address(fixture.usdcToken),
            counter: 0
        });

        return (fixture, result);
    }

    /**
     * @dev Creates a factory fixture and deploys multiple escrows for testing
     * @return fixture The factory fixture
     * @return results Array of deployment results
     */
    function createFactoryWithMultipleEscrows()
        public
        returns (FactoryFixture memory fixture, DeploymentResult[] memory results)
    {
        fixture = createFactoryFixture();
        results = new DeploymentResult[](4);

        // No prank needed - test contract is owner

        // Deploy first escrow for merchant 1 (USDC)
        address escrow1 = fixture.factory.deployEscrow(
            MERCHANT_ID_1,
            MERCHANT_1,
            address(fixture.usdcToken)
        );
        results[0] = DeploymentResult({
            escrowAddress: escrow1,
            merchantId: MERCHANT_ID_1,
            merchantAddress: MERCHANT_1,
            paymentToken: address(fixture.usdcToken),
            counter: 0
        });

        // Deploy second escrow for merchant 1 (DAI)
        address escrow2 = fixture.factory.deployEscrow(
            MERCHANT_ID_1,
            MERCHANT_1,
            address(fixture.daiToken)
        );
        results[1] = DeploymentResult({
            escrowAddress: escrow2,
            merchantId: MERCHANT_ID_1,
            merchantAddress: MERCHANT_1,
            paymentToken: address(fixture.daiToken),
            counter: 1
        });

        // Deploy first escrow for merchant 2 (USDC)
        address escrow3 = fixture.factory.deployEscrow(
            MERCHANT_ID_2,
            MERCHANT_2,
            address(fixture.usdcToken)
        );
        results[2] = DeploymentResult({
            escrowAddress: escrow3,
            merchantId: MERCHANT_ID_2,
            merchantAddress: MERCHANT_2,
            paymentToken: address(fixture.usdcToken),
            counter: 0
        });

        // Deploy second escrow for merchant 2 (USDC)
        address escrow4 = fixture.factory.deployEscrow(
            MERCHANT_ID_2,
            MERCHANT_2,
            address(fixture.usdcToken)
        );
        results[3] = DeploymentResult({
            escrowAddress: escrow4,
            merchantId: MERCHANT_ID_2,
            merchantAddress: MERCHANT_2,
            paymentToken: address(fixture.usdcToken),
            counter: 1
        });

        // No prank used

        return (fixture, results);
    }

    /**
     * @dev Creates a paused factory fixture for testing pause functionality
     * @return fixture The factory fixture (paused)
     */
    function createPausedFactoryFixture() public returns (FactoryFixture memory fixture) {
        fixture = createFactoryFixture();

        // Pause the factory (no prank needed - test contract is owner)
        fixture.factory.pause();

        return fixture;
    }

    /**
     * @dev Predicts the address of an escrow contract
     * @param factory The factory contract
     * @param merchantId The merchant ID
     * @param merchantAddress The merchant address
     * @param paymentToken The payment token address
     * @return predictedAddress The predicted escrow address
     */
    function predictEscrowAddress(
        CloakEscrowFactory factory,
        bytes32 merchantId,
        address merchantAddress,
        address paymentToken
    ) public view returns (address predictedAddress) {
        return factory.predictEscrowAddress(merchantId, merchantAddress, paymentToken);
    }

    /**
     * @dev Verifies that an escrow contract is properly configured
     * @param escrowAddress The escrow contract address
     * @param expectedMerchant Expected merchant address
     * @param expectedToken Expected payment token address
     * @param expectedPlatform Expected platform address
     * @param expectedOwner Expected owner address
     */
    function verifyEscrowConfiguration(
        address escrowAddress,
        address expectedMerchant,
        address expectedToken,
        address expectedPlatform,
        address expectedOwner
    ) public view {
        CloakEscrow escrow = CloakEscrow(escrowAddress);

        assertEq(escrow.merchantAddress(), expectedMerchant, "Merchant address mismatch");
        assertEq(escrow.paymentTokenAddress(), expectedToken, "Payment token mismatch");
        assertEq(escrow.platformAddress(), expectedPlatform, "Platform address mismatch");
        assertEq(escrow.owner(), expectedOwner, "Owner address mismatch");
    }

    /**
     * @dev Gets standard test amounts for different scenarios
     */
    function getSmallTestAmount() public pure returns (uint256) {
        return 100 * 10 ** 6; // 100 USDC
    }

    function getMediumTestAmount() public pure returns (uint256) {
        return 1000 * 10 ** 6; // 1000 USDC
    }

    function getLargeTestAmount() public pure returns (uint256) {
        return 10000 * 10 ** 6; // 10000 USDC
    }

    /**
     * @dev Generates a random merchant ID for testing
     * @param seed Seed for randomization
     * @return merchantId Random merchant ID
     */
    function generateRandomMerchantId(uint256 seed) public pure returns (bytes32 merchantId) {
        return keccak256(abi.encodePacked("merchant", seed));
    }

    /**
     * @dev Sets up mock users with labeled addresses for better test readability
     */
    function setupMockUsers() public {
        vm.label(FACTORY_OWNER, "FactoryOwner");
        vm.label(PLATFORM_ADDRESS, "PlatformAddress");
        vm.label(DEFAULT_OWNER, "DefaultOwner");
        vm.label(MERCHANT_1, "Merchant1");
        vm.label(MERCHANT_2, "Merchant2");
        vm.label(USER, "User");
        vm.label(ADMIN, "Admin");
        vm.label(NEW_PLATFORM, "NewPlatform");
        vm.label(NEW_DEFAULT_OWNER, "NewDefaultOwner");
        vm.label(NEW_MERCHANT, "NewMerchant");
    }

    /**
     * @dev Helper to fund an escrow contract through the factory fixture
     * @param fixture The factory fixture
     * @param escrowAddress The escrow address to fund
     * @param amount Amount to transfer
     */
    function fundEscrowFromFixture(
        FactoryFixture memory fixture,
        address escrowAddress,
        uint256 amount
    ) public {
        vm.prank(ADMIN);
        fixture.usdcToken.transfer(escrowAddress, amount);
    }
}
