// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;
import {Context} from "./Utils.sol";
import {IERC20, IOmegaFactory} from "./Interfaces.sol";
import {Trader} from "./Trader.sol";

contract OmegaPartnerTaxHandler is Context, Trader {
    address public owner;
    IOmegaFactory private _omegaFactory;
    bool public convertTaxToCoin;

    event UpdatedOmegaContract(address indexed oldFactory, 
                                address indexed newFactory);

    error OnlyOwnerCanCallThisFunction();
    error OmegaContractNotSet();
    error NonPartnerContract(address contractAddr);

    modifier onlyOwner() {
        if (msgSender() != owner) revert OnlyOwnerCanCallThisFunction();
        _;
    }

    modifier omegaFactoryIsNotZeroAddress() {
        if(address(omegaFactory()) == address(0)) revert OmegaContractNotSet();
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function omegaFactory() public view returns(address){
        return address(_omegaFactory);
    }

    function callAfterTaxIsProcessed(uint256) external returns (bool) {
        address contractAddr = msgSender();
        if (address(omegaFactory()) == address(0)) return true;
        (, bool isPartner) = _omegaFactory.isOmegaCreated(contractAddr);
        if (!isPartner) revert NonPartnerContract(contractAddr);
        if (!convertTaxToCoin) return true;
        _swapTokenToCoin(contractAddr, address(this), IERC20(contractAddr).balanceOf(address(this)));
        return true;
    }

    function swapTokenToCoin(address tokenAddress, address receiver, uint256 amount) public onlyOwner {
        _swapTokenToCoin(tokenAddress, receiver, amount);
    }

    function swapAllTokensBalanceToCoin(address receiver, uint256 fromIndex, uint256 toIndex) public onlyOwner {
        for (uint256 index; (index < (toIndex - fromIndex)); index++) {
            address tokenAddr = _omegaFactory.getPartnerContractAtIndex(fromIndex + index);
            if (tokenAddr == address(0)) continue;

            IERC20 token = IERC20(tokenAddr);
            uint256 balance = token.balanceOf(address(this));
            if (balance == 0) continue;
            _swapTokenToCoin(tokenAddr, receiver, balance);
        }
    }

    function toggleConvertTaxToCoin() public onlyOwner {
        convertTaxToCoin = !convertTaxToCoin;
    }

    function withdrawCoin(address receiver, uint256 amount) public onlyOwner {
        (bool sent,) = receiver.call{value: amount}("");
        require(sent);
    }

    function withrawAllCoin(address receiver) public onlyOwner {
        withdrawCoin(receiver, address(this).balance);
    }

    function withdrawToken(address tokenAddress, address receiver, uint256 amount) public onlyOwner {
        IERC20 tokenContract = IERC20(tokenAddress);
        tokenContract.transfer(receiver, amount);
    }

    function withdrawAllToken(address tokenAddress, address receiver) public onlyOwner {
        withdrawToken(tokenAddress, receiver, IERC20(tokenAddress).balanceOf(address(this)));
    }

    function setFactory(address newFactory) public onlyOwner {
        address oldAddress = address(_omegaFactory);
        _omegaFactory = IOmegaFactory(newFactory);
        emit UpdatedOmegaContract(oldAddress, newFactory);
    }
}
