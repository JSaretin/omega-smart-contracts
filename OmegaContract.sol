// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;
import {OmegaToken} from "./OmegaToken.sol";
import {Context} from "./Utils.sol";
import {IOmegaERC20 as IERC20} from "./Interfaces.sol";

contract OmegaFather is Context {

    struct OmegaStats {
        uint256 totalCreatedTokens;
        uint256 totalPartnerCreatedTokens;
        address[] allTokensAddresses;
        address[] allPartnerTokensAddresses;
    }

    struct ContractsInfo {
        uint256   totalCreated;
        address[] addrs;
    }

    struct ContractInfo {
        string  name;
        string  symbol;
        address addr;
        address owner;
        uint8   decimals;
        uint256 totalSupply;
        bool    isPartner;
        bool    isOmegaToken;
    }

    struct TokenInfo{
        bool isOmegaToken;
        bool isPartner;
    }

    OmegaStats stats;

    uint16  constant PERCENT_DEMONINATOR = 1_000; // 100%
    uint256 private _creationFee;
    uint16  private _partnerCreationFeePercentOff = 300; // 30%
    address public owner;

    event UpdatedCreationFee(uint256 fee);
    event UpdatePartnerPercentOff(uint16 percent);
    event CreateToken(address indexed tokenAddr, address indexed creator);
    
    
    error InsufficientFee(uint256 sent, uint256 expected);
    error OnlyOwnerCanCallThisFunction();


    mapping(address => ContractsInfo) creatorContracts;
    mapping(address => TokenInfo) omegaTokensInfo;

    constructor() {
        owner = msgSender();
    }

    modifier onlyOwner() {
        if (msgSender() != owner) revert OnlyOwnerCanCallThisFunction();
        _;
    }

    function getCreationFee() public view returns(uint256 nonPartner, uint256 partnerFee){
        (nonPartner, partnerFee) =  (_creationFee, ((_creationFee * _partnerCreationFeePercentOff) / PERCENT_DEMONINATOR));
    }

    function getStats() public view returns(uint256 allCreatedTokens, uint256 allCreatedPartnerTokens){
        allCreatedTokens = stats.totalCreatedTokens;
        allCreatedPartnerTokens = stats.totalPartnerCreatedTokens;
        
    }

    function isOmegaCreated(address contractAddr) public view returns (bool isCreated, bool isPartner){
        isPartner = omegaTokensInfo[contractAddr].isPartner;
        isCreated = omegaTokensInfo[contractAddr].isOmegaToken;
    }

    function getContractDetails(address contractAddr) public view returns(ContractInfo memory){
        IERC20 token = IERC20(contractAddr);
        (bool isOmegaToken, bool isPartner) = isOmegaCreated(contractAddr);
        return ContractInfo({
            addr:        contractAddr,
            owner:       token.owner(),
            name:        token.name(),
            symbol:      token.symbol(),
            decimals:    token.decimals(),
            totalSupply: token.totalSupply(),
            isOmegaToken:   isOmegaToken,
            isPartner:   isPartner
        });
    }

    function getContractAddressAtIndex(uint256 index) public view returns(address){
        return stats.allTokensAddresses[index];
    }

    function getPartnerContractAddressAtIndex(uint256 index) public view returns(address){
        return stats.allPartnerTokensAddresses[index];
    }

    function getContractAtIndex(uint256 index) public view returns(ContractInfo memory){
        return getContractDetails(getContractAddressAtIndex(index));
    }

    function getPartnerContractAtIndex(uint256 index) public view returns(ContractInfo memory){
        return getContractDetails(getPartnerContractAddressAtIndex(index));
    }

    function getCreatorTotalContractsCounts(address creator) public view returns (uint256) {
        return creatorContracts[creator].totalCreated;
    }

    function getCreatorContractsAddresses(address creator, uint256 fromIndex, uint256 toIndex) public view returns (address[] memory addrs) {
        addrs = new address[](toIndex - fromIndex);
        for (uint256 i; i < addrs.length; i++) addrs[i] = creatorContracts[creator].addrs[fromIndex + i];
    }

    function getCreatorContractsDetail(address creator, uint256 fromIndex, uint256 toIndex) public view returns (ContractInfo[] memory contracts) {
        contracts = new ContractInfo[](toIndex - fromIndex);
        address[] memory addrs = getCreatorContractsAddresses(creator, fromIndex, toIndex);
        for (uint256 i; i < contracts.length; i++) contracts[i] = getContractDetails(addrs[i]);
    }
    
    function updateCreationFee(uint256 creationFee_, uint16 partnerPercentOff) public onlyOwner {
        if (_creationFee != creationFee_){
            _creationFee = creationFee_;
            emit UpdatedCreationFee(creationFee_);
        }
        if (_partnerCreationFeePercentOff != partnerPercentOff){
            _partnerCreationFeePercentOff = partnerPercentOff;
            emit UpdatePartnerPercentOff(partnerPercentOff);
        }
    }

    function createToken(address taxWallet_, uint8 decimals_, uint16 buyTax_, uint16 sellTax_, uint16 transferTax_, 
                        uint256 totalSupply_, string memory name_, string memory symbol_, bool isPartner_) 
                                                                    external payable returns (address createdToken) {
        uint256 sentFee = msg.value;
        (uint256 nonePartnerFee, uint256 partnerFee) = getCreationFee();

        if      (!isPartner_ && nonePartnerFee > sentFee)           revert InsufficientFee(sentFee, nonePartnerFee);
        else if (isPartner_ && partnerFee > sentFee) revert InsufficientFee(sentFee, partnerFee);

        address creator = msgSender();
        createdToken = address(new OmegaToken(creator, taxWallet_, decimals_, buyTax_, sellTax_, transferTax_, totalSupply_, name_, symbol_, isPartner_));
        emit CreateToken(createdToken, creator);

        creatorContracts[creator].totalCreated += 1;
        creatorContracts[creator].addrs.push(createdToken);

        omegaTokensInfo[createdToken] = TokenInfo({
            isOmegaToken: true,
            isPartner: isPartner_
        });

        stats.totalCreatedTokens += 1;
        stats.allTokensAddresses.push(createdToken);

        if (isPartner_){
            stats.totalPartnerCreatedTokens += 1;
            stats.allPartnerTokensAddresses.push(createdToken);
        }
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

    receive() external payable {}
}
