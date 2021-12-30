// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.7.6;

import {SafeMath} from "@openzeppelin/contracts/math/SafeMath.sol";
import {IERC20Permit} from "@openzeppelin/contracts/drafts/IERC20Permit.sol";

import {IERC20} from "../interfaces/IERC20.sol";

/// @notice Modern and gas efficient ERC20 + EIP-2612 implementation.
/// @author Modified from solmate (https://github.com/Rari-Capital/solmate/blob/main/src/tokens/ERC20.sol)
abstract contract ERC20 is IERC20 {
    using SafeMath for uint256;

    /*///////////////////////////////////////////////////////////////
                             METADATA STORAGE
    //////////////////////////////////////////////////////////////*/

    string public override name;

    string public override symbol;

    uint8 public immutable override decimals;

    /*///////////////////////////////////////////////////////////////
                              ERC20 STORAGE
    //////////////////////////////////////////////////////////////*/

    uint256 public override totalSupply;

    mapping(address => uint256) public override balanceOf;

    mapping(address => mapping(address => uint256)) public override allowance;

    /*///////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _decimals
    ) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
    }

    /*///////////////////////////////////////////////////////////////
                              ERC20 LOGIC
    //////////////////////////////////////////////////////////////*/

    function approve(address spender, uint256 amount)
        public
        virtual
        override
        returns (bool)
    {
        allowance[msg.sender][spender] = amount;

        emit Approval(msg.sender, spender, amount);

        return true;
    }

    function transfer(address to, uint256 amount)
        public
        virtual
        override
        returns (bool)
    {
        balanceOf[msg.sender] = balanceOf[msg.sender].sub(amount);

        // Cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value.
        balanceOf[to] += amount;

        emit Transfer(msg.sender, to, amount);

        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual override returns (bool) {
        uint256 _allowance = allowance[from][msg.sender];
        if (_allowance != type(uint256).max) {
            allowance[from][msg.sender] = _allowance.sub(amount);
        }

        balanceOf[from] = balanceOf[from].sub(amount);

        // Cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value.
        balanceOf[to] += amount;

        emit Transfer(from, to, amount);

        return true;
    }

    /*///////////////////////////////////////////////////////////////
                       INTERNAL MINT/BURN LOGIC
    //////////////////////////////////////////////////////////////*/

    function _mint(address to, uint256 amount) internal virtual {
        totalSupply = totalSupply.add(amount);

        // Cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value.
        balanceOf[to] += amount;

        emit Transfer(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) internal virtual {
        balanceOf[from] = balanceOf[from].sub(amount);

        // Cannot underflow because a user's balance
        // will never be larger than the total supply.
        totalSupply -= amount;

        emit Transfer(from, address(0), amount);
    }
}
