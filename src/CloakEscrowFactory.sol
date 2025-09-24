// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {CloakEscrow} from "./CloakEscrow.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

contract CloakEscrowFactory is Ownable, Pausable {
    // State variables
    mapping(bytes32 => address[]) public merchantEscrows; // merchantId => escrow addresses
    mapping(bytes32 => uint256) public merchantCounters; // merchantId => deployment counter
    mapping(address => bytes32) public escrowToMerchant; // escrow address => merchantId
    mapping(address => bool) public escrowExists; // escrow address => exists

    address public platformAddress;
    address public defaultOwner;

    // Events
    event EscrowDeployed(
        bytes32 indexed merchantId, address indexed escrowAddress, uint256 counter, address paymentToken
    );
    event MerchantRegistered(bytes32 indexed merchantId);
    event PlatformAddressUpdated(address oldAddress, address newAddress);
    event DefaultOwnerUpdated(address oldOwner, address newOwner);

    // Custom errors
    error InvalidAddress();
    error MerchantNotFound();
    error EscrowNotFound();
    error DeploymentFailed();

    constructor(address _platformAddress, address _defaultOwner) Ownable(msg.sender) {
        if (_platformAddress == address(0) || _defaultOwner == address(0)) {
            revert InvalidAddress();
        }

        platformAddress = _platformAddress;
        defaultOwner = _defaultOwner;
    }

    /**
     * @notice Deploy a new escrow contract for a merchant
     * @param merchantId The unique identifier for the merchant (bytes32)
     * @param merchantAddress The merchant's payout address
     * @param paymentTokenAddress The ERC20 token address for payments
     * @return escrowAddress The address of the deployed escrow contract
     */
    function deployEscrow(bytes32 merchantId, address merchantAddress, address paymentTokenAddress)
        external
        onlyOwner
        whenNotPaused
        returns (address escrowAddress)
    {
        if (merchantAddress == address(0) || paymentTokenAddress == address(0)) {
            revert InvalidAddress();
        }

        // Increment counter for this merchant
        uint256 currentCounter = merchantCounters[merchantId];
        merchantCounters[merchantId] = currentCounter + 1;

        // Generate salt using merchantId and counter
        bytes32 salt = keccak256(abi.encodePacked(merchantId, currentCounter));

        // Deploy escrow contract using CREATE2
        bytes memory bytecode = abi.encodePacked(
            type(CloakEscrow).creationCode,
            abi.encode(merchantAddress, paymentTokenAddress, platformAddress, defaultOwner)
        );

        assembly {
            escrowAddress := create2(0, add(bytecode, 0x20), mload(bytecode), salt)
            if iszero(escrowAddress) { revert(0, 0) }
        }

        if (escrowAddress == address(0)) {
            revert DeploymentFailed();
        }

        // Update mappings
        merchantEscrows[merchantId].push(escrowAddress);
        escrowToMerchant[escrowAddress] = merchantId;
        escrowExists[escrowAddress] = true;

        // Emit events
        if (merchantEscrows[merchantId].length == 1) {
            emit MerchantRegistered(merchantId);
        }

        emit EscrowDeployed(merchantId, escrowAddress, currentCounter, paymentTokenAddress);

        return escrowAddress;
    }

    /**
     * @notice Predict the address of the next escrow contract for a merchant
     * @param merchantId The merchant identifier
     * @param merchantAddress The merchant's payout address
     * @param paymentTokenAddress The ERC20 token address for payments
     * @return predictedAddress The predicted address of the next escrow contract
     */
    function predictEscrowAddress(bytes32 merchantId, address merchantAddress, address paymentTokenAddress)
        external
        view
        returns (address predictedAddress)
    {
        uint256 nextCounter = merchantCounters[merchantId];
        bytes32 salt = keccak256(abi.encodePacked(merchantId, nextCounter));

        bytes memory bytecode = abi.encodePacked(
            type(CloakEscrow).creationCode,
            abi.encode(merchantAddress, paymentTokenAddress, platformAddress, defaultOwner)
        );

        bytes32 hash = keccak256(abi.encodePacked(bytes1(0xff), address(this), salt, keccak256(bytecode)));

        return address(uint160(uint256(hash)));
    }

    /**
     * @notice Get all escrow addresses for a merchant
     * @param merchantId The merchant identifier
     * @return escrowAddresses Array of escrow contract addresses
     */
    function getEscrowsForMerchant(bytes32 merchantId) external view returns (address[] memory escrowAddresses) {
        return merchantEscrows[merchantId];
    }

    /**
     * @notice Get the merchant ID for an escrow contract
     * @param escrowAddress The escrow contract address
     * @return merchantId The merchant identifier
     */
    function getMerchantForEscrow(address escrowAddress) external view returns (bytes32 merchantId) {
        if (!escrowExists[escrowAddress]) {
            revert EscrowNotFound();
        }
        return escrowToMerchant[escrowAddress];
    }

    /**
     * @notice Get the number of escrows deployed for a merchant
     * @param merchantId The merchant identifier
     * @return count Number of deployed escrows
     */
    function getMerchantEscrowCount(bytes32 merchantId) external view returns (uint256 count) {
        return merchantEscrows[merchantId].length;
    }

    /**
     * @notice Get the current counter for a merchant
     * @param merchantId The merchant identifier
     * @return counter Current deployment counter
     */
    function getMerchantCounter(bytes32 merchantId) external view returns (uint256 counter) {
        return merchantCounters[merchantId];
    }

    /**
     * @notice Check if a merchant has any deployed escrows
     * @param merchantId The merchant identifier
     * @return exists True if merchant has deployed escrows
     */
    function merchantExists(bytes32 merchantId) external view returns (bool exists) {
        return merchantEscrows[merchantId].length > 0;
    }

    /**
     * @notice Update the platform address
     * @param _platformAddress New platform address
     */
    function setPlatformAddress(address _platformAddress) external onlyOwner {
        if (_platformAddress == address(0)) {
            revert InvalidAddress();
        }

        address oldAddress = platformAddress;
        platformAddress = _platformAddress;
        emit PlatformAddressUpdated(oldAddress, _platformAddress);
    }

    /**
     * @notice Update the default owner for new escrow contracts
     * @param _defaultOwner New default owner address
     */
    function setDefaultOwner(address _defaultOwner) external onlyOwner {
        if (_defaultOwner == address(0)) {
            revert InvalidAddress();
        }

        address oldOwner = defaultOwner;
        defaultOwner = _defaultOwner;
        emit DefaultOwnerUpdated(oldOwner, _defaultOwner);
    }

    /**
     * @notice Pause the factory (prevents new deployments)
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @notice Unpause the factory
     */
    function unpause() external onlyOwner {
        _unpause();
    }
}
