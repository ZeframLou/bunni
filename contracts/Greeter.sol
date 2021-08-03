// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.3;

contract Greeter {
    string private _message;

    constructor(string memory initMessage) {
        _message = initMessage;
    }

    function greet() external view returns (string memory) {
        return _message;
    }

    function setGreeting(string calldata newMessage) external {
        _message = newMessage;
    }
}
