// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;     // default in Remix

contract Swap {
    address public USDC;        // USDC contract address
    address public ft;          // assume peer-to-peer swap with one fixed rate taker
    address public vt;          // assume peer-to-peer swap with one variable rate taker
    uint256 public rate;       // constant fixed rate at which IRS is initiated
    uint256 public margin;     // initial margin requirement as percent of notional
    uint256 public deposit;    // initial margin as units of notional
    uint256 public threshold;  // liquidation threshold as percent of notional
    uint256 public penalty;    // liquidation penalty as percent of notional
    uint256 public notional;   // value of underlying USDC
    uint256 public duration;   // term of the contract
    uint256 public ftPayout;   // facilitate testing payout to fixed taker
    uint256 public vtPayout;   // facilitate testing payout to variable taker

    constructor() {
        USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;  // mainnet
        // avoid floating-point errors by storing basis points as integers
        rate = 100;         // swap initiates at 1% fixed rate
        margin = 1000;      // both sides must deposit 10% of notional
        threshold = 700;    // liquidate if current margin < 7% of notional
        penalty = 500;      // liquidatation penalty is 5% of notional
    }

    function stake(address token, uint256 amount) internal {
        require(amount > 0, "Cannot stake 0");
        require(token == USDC, "Unsupported token");
        // deposit initial margin
        IERC20(USDC).transferFrom(msg.sender, address(this), amount);
    }

    function takeFixedRate(address token, uint256 amount) public {
        stake(token, amount);
        ft = msg.sender;
    }

    function takeVariableRate(address token, uint256 amount) public {
        stake(token, amount);
        vt = msg.sender;
    }

    function initiate(uint256 n, uint256 d) public {
        // prerequisite: stake via takeFixedRate() or takeVariableRate()
        notional = n;
        duration = d;
        deposit = notional * margin;
    }

    function getCurrentRate() internal view returns (uint256) {
        // TODO: get current USDC rate from Aave
        return rate * 2;
    }

    function pay(address payee, uint256 amount) internal {
        IERC20(USDC).transferFrom(address(this), payee, amount);
    }

    function settle() public {
        uint currentRate = getCurrentRate();
        // inspired from https://github.com/NeapolitanSwaps/CherrySwap/blob/master/packages/smart-contracts/contracts/CherrySwap.sol#L250
        // TODO: check math
        uint variableTakerPayout = deposit + ( deposit * currentRate / rate ) - ( deposit * currentRate * duration );
        uint fixedTakerPayout = deposit + ( deposit * currentRate * duration) - ( deposit * currentRate / rate );
        require(fixedTakerPayout + variableTakerPayout == 2 * deposit, "Total payouts should equal total deposits");
        pay(vt, variableTakerPayout);
        pay(ft, fixedTakerPayout);
    }

    function liquidate() public {
        uint currentRate = getCurrentRate();
        // TODO: check math
        uint buffer = margin - threshold;
        uint payout = deposit + notional * buffer + penalty;
        require(payout < 2 * deposit, "Cannot payout more than deposits");
        if (currentRate - rate > buffer) {
            vtPayout = payout;
            ftPayout = 0;
            pay(vt, payout);
        } else if (rate - currentRate < buffer) {
            ftPayout = payout;
            vtPayout = 0;
            pay(ft, payout);
        }
    }
}

// https://ethereumdev.io/understand-the-erc20-token-smart-contract/
interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}
