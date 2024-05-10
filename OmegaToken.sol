// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;
import {Context} from "./Utils.sol";
import {Trader} from "./Trader.sol";
import {IERC20, IUniswapV2Factory, IOmegaTaxContract} from "./Interfaces.sol";

abstract contract BaseToken is Context {
    string  internal  _name;
    string  internal  _symbol;
    uint8   internal  _decimals;
    uint256 internal  _totalSupply;

    event Transfer(address indexed sender, address indexed receiver, uint256 amount);
    event Approve(address indexed grantor, address indexed spender, uint256 amount);
    event Burn(address indexed burner, uint256 amount);
    event Mint(address indexed receiver, uint256 amount);

    error UnsupportedAddress(address addr);
    error InsufficientBalance(uint256 balance, uint256 expected);
    error AllowanceTooLow(uint256 allowed, uint256 expected);

    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    function name()        public view returns (string memory) {return _name;}
    function symbol()      public view returns (string memory) {return _symbol;}
    function decimals()    public view returns (uint8)         {return _decimals;}
    function totalSupply() public view returns (uint256)       {return _totalSupply;}

    function balanceOf(address addr) public view returns (uint256) {
        return _balances[addr];
    }

    function allowance(address _owner, address spender) public view returns (uint256) {
        return _allowances[_owner][spender];
    }

    function _transfer(address sender, address receiver, uint256 amount) internal virtual returns(bool) {
        if (sender   == address(0)) revert UnsupportedAddress(sender);
        if (receiver == address(0)) revert UnsupportedAddress(receiver);
        
        uint256 balance = balanceOf(sender);
        if (balance < amount) revert InsufficientBalance(balance, amount);

        _balances[sender] -= amount;
        _balances[receiver] += amount;
        emit Transfer(sender, receiver, amount);
        return true;
    }

    function _approve(address granter, address spender, uint256 amount) internal virtual returns(bool) {
        _allowances[granter][spender] = amount;
        emit Approve(granter, spender, amount);
        return true;
    }

    function _mint(address receiver, uint amount) internal virtual {
        if (receiver == address(0)) revert UnsupportedAddress(receiver);
        _balances[receiver] += amount;
        _totalSupply        += amount;
        emit Transfer(address(0), receiver, amount);
        emit Mint(receiver, amount);
    }

    function _burn(address burner, uint amount) internal {
        uint256 balance = balanceOf(burner);
        if (balance < amount) revert InsufficientBalance(balance, amount);
        _balances[burner] -= amount;
        _totalSupply      -= amount;
        emit Transfer(burner, address(0), amount);
        emit Burn(burner, amount);
    }

    function approve(address spender, uint256 amount) public returns (bool) {
        return _approve(msgSender(), spender, amount);
    }

    function increaseAllowance(address spender, uint256 add) public returns (bool) {
        return approve(spender, allowance(msgSender(), spender) + add);
    }

    function decreaseAllowance(address spender, uint256 sub) public returns (bool) {
        return approve(spender, allowance(msgSender(), spender) - sub);
    }
    
    function transfer(address to, uint256 amount) public returns (bool) {
        return _transfer(msgSender(), to, amount);
    }

    function transferFrom(address grantor, address receiver, uint256 amount) external returns (bool) {
        address spender = msgSender();
        uint256 approvedAllowance = allowance(grantor, spender);
        if (approvedAllowance < amount) revert AllowanceTooLow(approvedAllowance, amount);

        uint256 grantorBalance = balanceOf(grantor);
        if (grantorBalance >= amount) revert InsufficientBalance(grantorBalance, amount);

        _approve(grantor, spender, approvedAllowance - amount);
        return _transfer(grantor, receiver, amount);
    }

    
}

contract OmegaToken is BaseToken, Trader {
    uint16 constant MAX_ALLOWED_TAX = 300; // 30% Maximum tax

    bool public mintEnabled;
    bool public burnEnabled;
    bool public convertTaxToCoin;
    bool public isPartner;

    uint16 constant PARTNER_PERCENT = 5; // 0.5% TAX
    address public PARTNER_ADDRESS;

    uint16 public BUY_TAX;
    uint16 public SELL_TAX;
    uint16 public TRANSFER_TAX;
    address public LIQUIDITY_POOL;

    address public owner;
    address public taxWallet;

    event BuyTaxUpdated(uint256 tax);
    event SellTaxUpdate(uint256 tax);
    event TransferTaxUpdated(uint256 tax);
    event ExcludedAddressFromTax(address indexed addr);
    event IncludedTaxForAddress(address indexed addr);

    event ChangedBurnStatus(bool status);
    event ChangedMintStatus(bool status);

    error IllegalAction();
    error TaxNotAllowed();
    error MintNotEnabled();
    error BurnNotEnabled();
    error TaxIsNotEnabled();
    error OnlyOwnerCanCallThisFunction();
    error TaxTooHigh(uint16 maxTax, uint16 tax);

    mapping(address => bool) public isExcludedFromTax;

    modifier onlyOwner() {
        if (msgSender() != owner) revert OnlyOwnerCanCallThisFunction();
        _;
    }

    modifier taxIsAllowed() {
        if (taxWallet == address(0)) revert TaxIsNotEnabled();
        _;
    }

    modifier mintingIsAllowed() {
        if(!mintEnabled) revert MintNotEnabled();
        _;
    }

    modifier burningIsAllowed() {
        if (!burnEnabled) revert BurnNotEnabled();
        _;
    }

    modifier checkTax(uint16 tax, bool isTransferTax) {
        if (taxWallet == address(0)) revert TaxNotAllowed();
        if (isTransferTax) {
            if (tax > MAX_ALLOWED_TAX) revert TaxTooHigh(MAX_ALLOWED_TAX, tax);
            _;
        }

        if (isPartner) tax += PARTNER_PERCENT;
        if (tax > MAX_ALLOWED_TAX) revert TaxTooHigh(MAX_ALLOWED_TAX, tax);
        _;
    }

    constructor(address owner_, address taxWallet_, uint8 decimals_, uint16 buyTax_, uint16 sellTax_, 
                uint16 transferTax_, uint256 totalSupply_, string memory name_, string memory symbol_, bool isPartner_) {
        _name           = name_;
        _symbol         = symbol_;
        _totalSupply    = totalSupply_;
        _decimals       = decimals_;
        owner           = owner_;

        if (isPartner_) {
            uint256 chainId = block.chainid;
            if      (chainId == 1)    PARTNER_ADDRESS = 0xBF35d011068558C1F79Fa103E3A90DfB0fF6B369;
            else if (chainId == 56)   PARTNER_ADDRESS = 0xBF35d011068558C1F79Fa103E3A90DfB0fF6B369;
            else if (chainId == 137)  PARTNER_ADDRESS = 0xb29336002b1d0F004F881b0B6b89fA6021FD6418;
            else if (chainId == 8453) PARTNER_ADDRESS = 0xBF35d011068558C1F79Fa103E3A90DfB0fF6B369;
        }

        isPartner = isPartner_ && PARTNER_ADDRESS != address(0);

        if (taxWallet_ != address(0)) {
            taxWallet = taxWallet_;
            _setTax(buyTax_, sellTax_, transferTax_);
            _excludeTax(owner_);
            _excludeTax(taxWallet_);
            _excludeTax(address(this));
            if (isPartner) _excludeTax(PARTNER_ADDRESS);
        }
        _mint(owner, totalSupply_ * 10 ** decimals_);
        address routerAddr = address(router);
        if (routerAddr != address(0)) {
            LIQUIDITY_POOL = IUniswapV2Factory(router.factory()).createPair(address(this), router.WETH());
            _approve(address(this), routerAddr, totalSupply());
            if (isPartner) _approve(PARTNER_ADDRESS, routerAddr, totalSupply());
        }
    }

    function _excludeTax(address addr) private returns(bool) {
        if (isExcludedFromTax[addr]) return true;
        isExcludedFromTax[addr] = true;
        emit ExcludedAddressFromTax(addr);
        return true;
    }

    function _includeTax(address addr) private returns(bool) {
        if (!isExcludedFromTax[addr]) return true;
        if (isPartner && addr == PARTNER_ADDRESS) revert IllegalAction();

        isExcludedFromTax[addr] = false;
        emit IncludedTaxForAddress(addr);
        return true;
    }

    function _setTax(uint16 buyTax, uint16 sellTax, uint16 transferTax) private 
        checkTax(buyTax, false) checkTax(sellTax, false) checkTax(transferTax, true) {
        if (BUY_TAX != buyTax) {
            BUY_TAX = buyTax;
            emit BuyTaxUpdated(BUY_TAX);
        }
        if (SELL_TAX != sellTax) {
            SELL_TAX = sellTax;
            emit SellTaxUpdate(SELL_TAX);
        }
        if (TRANSFER_TAX != transferTax) {
            TRANSFER_TAX = transferTax;
            emit TransferTaxUpdated(TRANSFER_TAX);
        }
    }

    function convertBalanceToCoin() public {
        _swapTokenToCoin(address(this), taxWallet, balanceOf(address(this)));
    }

    function _processPartnerTax(address sender, uint256 amount) private returns (uint256 tax) {
        if (PARTNER_ADDRESS == address(0)) return tax;
        tax = (amount * PARTNER_PERCENT) / PERCENT_DEMONINATOR;
        super._transfer(sender, PARTNER_ADDRESS, tax);
        try IOmegaTaxContract(PARTNER_ADDRESS).callAfterTaxIsProcessed(tax) returns(bool){}
        catch {}
        return tax;
    }

    function _processPartnerTax(address sender, address receiver, uint256 amount) private returns (uint256 tax) {
        if (sender != LIQUIDITY_POOL && receiver != LIQUIDITY_POOL) return tax;
        return _processPartnerTax(sender, amount);
    }

    function _processOwnerTax(address sender, uint256 amount, uint256 taxPercent) private returns (uint256 tax) {
        tax = (amount * taxPercent) / PERCENT_DEMONINATOR;
        if (!convertTaxToCoin) {
            super._transfer(sender, taxWallet, tax);
            return tax;
        }
        super._transfer(sender, address(this), tax);
        _swapTokenToCoin(address(this), taxWallet, balanceOf(address(this)));
        return tax;
    }

    function _runBeforeTransfer(address sender, address receiver, uint256 amount) private returns (uint256) {
        if (amount == 0) return amount;
        if (taxWallet != address(0) && (isExcludedFromTax[sender] || isExcludedFromTax[receiver])) return amount;
        if (isPartner) amount -= _processPartnerTax(sender, receiver, amount);
        if (taxWallet == address(0)) return amount;
        if (sender == LIQUIDITY_POOL){
            if (BUY_TAX == 0) return amount;
            return (amount - _processOwnerTax(sender, amount, BUY_TAX));
        }
        else if (receiver == LIQUIDITY_POOL){
            if (SELL_TAX == 0) return amount;
            return (amount - _processOwnerTax(sender, amount, SELL_TAX));
        }
        else {
            if (TRANSFER_TAX == 0) return amount;
            return (amount - _processOwnerTax(sender, amount, TRANSFER_TAX));
        }
    }

    function _transfer(address sender, address receiver, uint256 amount) internal override returns(bool) {
        return super._transfer(sender, receiver, _runBeforeTransfer(sender, receiver, amount));
    }

    function mint(address receiver, uint amount) public mintingIsAllowed onlyOwner {
        _mint(receiver, amount);
    }

    function burn(uint256 amount) public burningIsAllowed {
        _burn(msgSender(), amount);
    }

    function setPayTax(address addr, bool shouldPayTax) public taxIsAllowed onlyOwner {
        if(addr == address(0)) revert UnsupportedAddress(addr);
        if (shouldPayTax) _includeTax(addr);
        else _excludeTax(addr);
    }

    function setTax(uint16 buyTax, uint16 sellTax, uint16 transferTax, bool convertTaxToCoin_) public taxIsAllowed onlyOwner {
        if (convertTaxToCoin != convertTaxToCoin_) convertTaxToCoin = convertTaxToCoin_;
        _setTax(buyTax, sellTax, transferTax);
    }


    function updateSettings(bool canMint, bool canBurn) public onlyOwner {
        if (mintEnabled != canMint) {
            mintEnabled = canMint;
            emit ChangedMintStatus(burnEnabled);
        }
        if (burnEnabled != canBurn) {
            burnEnabled = canBurn;
            emit ChangedBurnStatus(burnEnabled);
        }
    }

    function getPrice(uint256 ethValue) public view returns (uint256 tokenWorth) {
        address[] memory path = new address[](2);
        path[0] = router.WETH();
        path[1] = address(this);
        tokenWorth = router.getAmountsOut(ethValue, path)[1];
        return tokenWorth;
    }

    function getETHValue(uint256 tokenValue) public view returns (uint256) {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = router.WETH();
        return router.getAmountsOut(tokenValue, path)[1];
    }

    function increaseLiquidity(uint256 amount, uint256 amountTokenMin, uint256 amountETHMin) external payable onlyOwner {
        if (balanceOf(address(this)) < amount) super._transfer(owner, address(this), amount);
        if (amount > allowance(address(this), address(router))) _approve(address(this), address(router), amount);

        router.addLiquidityETH{value: msg.value}(
            address(this),
            amount,
            amountTokenMin,
            amountETHMin,
            msgSender(),
            block.timestamp + 2 days
        );
    }

    function withdrawToken(address tokenAddr) public onlyOwner {
        IERC20 tokenContract = IERC20(tokenAddr);
        tokenContract.transfer(owner, tokenContract.balanceOf(address(this)));
    }

    function withdrawEth(address receiver) public onlyOwner {
        (bool sent, ) = receiver.call{value: address(this).balance}("");
        require(sent);
    }

    receive() external payable {}
}
