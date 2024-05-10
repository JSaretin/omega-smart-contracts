// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;
import {IERC20, IUniswapV2Router01} from "./Interfaces.sol";

contract Trader {
    IUniswapV2Router01 public router;
    uint16 public constant PERCENT_DEMONINATOR = 1_000; // 100% TAX
    uint256 public tradeSlipage = 300; // 30%

    constructor() {
        address routerAddr;
        uint256 chainId = block.chainid;
        if      (chainId == 1)    routerAddr = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
        else if (chainId == 56)   routerAddr = 0x10ED43C718714eb63d5aA57B78B54704E256024E;
        else if (chainId == 137)  routerAddr = 0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff;
        else if (chainId == 8453) routerAddr = 0x327Df1E6de05895d2ab08513aaDD9313Fe505d86;
        
        router = IUniswapV2Router01(routerAddr);
    }

    function _swapTokenToCoin(address tokenAddress, address receiver, uint256 amount) internal {
        address[] memory path = new address[](2);
        path[0] = tokenAddress;
        path[1] = router.WETH();
        IERC20 token = IERC20(tokenAddress);
        if (token.allowance(address(this), address(router)) < amount) token.approve(address(router), amount);
        uint256 expectedOut = router.getAmountsOut(amount, path)[1];
        uint256 minExpectedAmount = expectedOut - ((expectedOut * tradeSlipage) / PERCENT_DEMONINATOR);
        try router.swapExactTokensForETH(amount, minExpectedAmount, path, receiver, block.timestamp + 2 days)
        returns (uint256[] memory) {} catch {}
    }
}
