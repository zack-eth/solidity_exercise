// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;
import "remix_tests.sol"; // this import is automatically injected by Remix.
import "remix_accounts.sol"; // this import is automatically injected by Remix.
import "../contracts/Swap.sol";

contract SwapTest {
   
    Swap swap;
    address ft;
    address vt;
    address USDC;

    function beforeAll() public {
        swap = new Swap();
        ft = TestsAccounts.getAccount(0);
        vt = TestsAccounts.getAccount(1);
        USDC = swap.USDC();
    }
    
    /// #value: 100
    /// #sender: account-0
    function takeFixedRate() public payable {
        swap.takeFixedRate(USDC, 100);
    }

    /// #value: 100
    /// #sender: account-1
    function takeVariableRate() public payable {
        swap.takeVariableRate(USDC, 100);
    }

    function initiate() internal returns (bool) {
        uint256 notional = 100;
        uint256 duration = 1;
        swap.initiate(notional, duration);
    }

    function liquidate() internal returns (bool) {
        // swap.liquidate();
        return swap.vtPayout() == 0;
    }
}
