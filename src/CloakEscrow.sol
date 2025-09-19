// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract CloakEscrow {
    address public merchantAddress;
    address public paymentTokenAddress;
    address public platformAddress;
    IERC20 public paymentToken;
    

    constructor(address _merchantAddress, address _paymentTokenAddress, address _platformAddress) {
        merchantAddress = _merchantAddress;
        platformAddress = _platformAddress;
        paymentTokenAddress = _paymentTokenAddress;
        paymentToken = IERC20(_paymentTokenAddress);
    }
    
}