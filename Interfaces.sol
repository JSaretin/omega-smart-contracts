// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

interface IERC20 {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function totalSupply() external view returns (uint256);
    function decimals() external view returns (uint8);

    function balanceOf(address owner) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);

    function transfer(address receiver, uint256 amount) external returns (bool);
    function transferFrom(address grantor, address receiver, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
}

interface IOmegaERC20 is IERC20 {
    function owner() external view returns(address);
}

interface IUniswapV2Factory {
    event PairCreated(address indexed token0, address indexed token1, address pair, uint);
    function getPair(address tokenA, address tokenB) external view returns (address pair);
    function createPair(address tokenA, address tokenB) external returns (address pair);
}

interface IUniswapV2Router01 {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);
    
    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);

    function addLiquidityETH(address token, uint amountTokenDesired, uint amountTokenMin, uint amountETHMin, address to, uint deadline)
        external payable returns (uint amountToken, uint amountETH, uint liquidity);

    function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline) 
        external returns (uint[] memory amounts);

}

interface IOmegaTaxContract {
    function omegaFactory() external view returns(address);
    function callAfterTaxIsProcessed(uint256 tax) external returns(bool);
}

interface IOmegaFactory {
    function totalCreatedPartnerContracts() external view returns (uint256);
    function isOmegaCreated(address contractAddress) external view returns (bool isCreated, bool isPartner);
    function getPartnerContractAtIndex(uint256 index) external view returns (address);
}