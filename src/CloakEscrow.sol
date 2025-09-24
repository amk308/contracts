// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

contract CloakEscrow is Ownable, ReentrancyGuard, Pausable {
    // State variables
    address public merchantAddress;
    address public paymentTokenAddress;
    address public platformAddress;
    IERC20 public paymentToken;
    uint256 public platformFeeBasisPoints;

    // Constants
    uint256 public constant MAX_PLATFORM_FEE = 5000; // 50% maximum
    uint256 public constant BASIS_POINTS = 10000; // 100%

    // Custom errors
    error InvalidAddress();
    error InvalidFeeAmount();
    error NoBalanceToDistribute();
    error TransferFailed();

    // Events
    event PlatformFeeUpdated(uint256 oldFee, uint256 newFee);
    event MerchantAddressUpdated(address oldAddress, address newAddress);
    event PlatformAddressUpdated(address oldAddress, address newAddress);
    event FundsDistributed(uint256 platformAmount, uint256 merchantAmount);
    event ContractPaused(address account);
    event ContractUnpaused(address account);

    constructor(address _merchantAddress, address _paymentTokenAddress, address _platformAddress, address _owner)
        Ownable(_owner)
    {
        if (_merchantAddress == address(0) || _paymentTokenAddress == address(0) || _platformAddress == address(0)) {
            revert InvalidAddress();
        }

        merchantAddress = _merchantAddress;
        platformAddress = _platformAddress;
        paymentTokenAddress = _paymentTokenAddress;
        paymentToken = IERC20(_paymentTokenAddress);
        platformFeeBasisPoints = 250; // Default 2.5% platform fee
    }

    // Platform fee management
    function getPlatformFee() public view returns (uint256) {
        return platformFeeBasisPoints;
    }

    function setPlatformFee(uint256 _feeBasisPoints) external onlyOwner whenNotPaused {
        if (_feeBasisPoints > MAX_PLATFORM_FEE) {
            revert InvalidFeeAmount();
        }

        uint256 oldFee = platformFeeBasisPoints;
        platformFeeBasisPoints = _feeBasisPoints;
        emit PlatformFeeUpdated(oldFee, _feeBasisPoints);
    }

    // Merchant address management
    function getMerchantAddress() public view returns (address) {
        return merchantAddress;
    }

    function setMerchantAddress(address _merchantAddress) external onlyOwner {
        if (_merchantAddress == address(0)) {
            revert InvalidAddress();
        }

        address oldAddress = merchantAddress;
        merchantAddress = _merchantAddress;
        emit MerchantAddressUpdated(oldAddress, _merchantAddress);
    }

    // Platform address management
    function getPlatformAddress() public view returns (address) {
        return platformAddress;
    }

    function setPlatformAddress(address _platformAddress) external onlyOwner {
        if (_platformAddress == address(0)) {
            revert InvalidAddress();
        }

        address oldAddress = platformAddress;
        platformAddress = _platformAddress;
        emit PlatformAddressUpdated(oldAddress, _platformAddress);
    }

    // Distribution function
    function distribute() external nonReentrant whenNotPaused {
        uint256 contractBalance = paymentToken.balanceOf(address(this));

        if (contractBalance == 0) {
            revert NoBalanceToDistribute();
        }

        // Calculate platform fee
        uint256 platformAmount = (contractBalance * platformFeeBasisPoints) / BASIS_POINTS;
        uint256 merchantAmount = contractBalance - platformAmount;

        // Transfer platform fee
        if (platformAmount > 0) {
            bool platformTransferSuccess = paymentToken.transfer(platformAddress, platformAmount);
            if (!platformTransferSuccess) {
                revert TransferFailed();
            }
        }

        // Transfer remaining to merchant
        if (merchantAmount > 0) {
            bool merchantTransferSuccess = paymentToken.transfer(merchantAddress, merchantAmount);
            if (!merchantTransferSuccess) {
                revert TransferFailed();
            }
        }

        emit FundsDistributed(platformAmount, merchantAmount);
    }

    // Pause/Unpause functions
    function pause() external onlyOwner {
        _pause();
        emit ContractPaused(_msgSender());
    }

    function unpause() external onlyOwner {
        _unpause();
        emit ContractUnpaused(_msgSender());
    }
}
