//SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

interface ICustomERC20 {
    function transfer(address to, uint256 amount) external returns(bool);
    function transferFrom(address from, address to, uint256 amount) external returns(bool);
    function balanceOf(address account) external view returns(uint256);
}

contract CustomDeFiLending {
    ICustomERC20 public stablecoin;
    uint256 public constant COLLATERAL_RATIO = 150; //150% collateral requirement
    uint256 public constant LIQUIDATION_RATIO = 120; //120% liquidation threshold

    struct Loan {
        uint256 collateral;
        uint256 debt;
    }

    mapping(address => Loan) public loans;

    bool private _locked; //reentrancy lock

    event Deposited(address indexed user, uint256 amount);
    event Borrowed(address indexed user, uint256 amount);
    event Repaid(address indexed user, uint256 amount);
    event Liquidated(address indexed user, address indexed liquidator);

    constructor(address _stablecoin) {
        stablecoin = ICustomERC20(_stablecoin);
    }

    modifier nonReentrant() {
        require(!_locked, "Reentrant call detected");
        _locked = true;
        _;
        _locked = false;
    }

    modifier loanCheck(address user) {
        require(loans[user].collateral > 0, "No collateral deposited");
        uint256 maxBorrow = (loans[user].collateral * 100) / COLLATERAL_RATIO;
        require(loans[user].debt <= maxBorrow, "Loan exceeds limit");
        _;
    }

    function depositCollateral() external payable nonReentrant {
        require(msg.value > 0, "Must deposit ETH");
        loans[msg.sender].collateral += msg.value;
        emit Deposited(msg.sender, msg.value);
    }

    function borrow(uint256 amount) external loanCheck(msg.sender) nonReentrant {
        loans[msg.sender].debt += amount;
        require(stablecoin.transfer(msg.sender, amount), "Transfer failed");
        emit Borrowed(msg.sender, amount);
    }

    function repay(uint256 amount) external loanCheck(msg.sender) nonReentrant {
        require(loans[msg.sender].debt >= amount, "Repaying too much");
        require(stablecoin.transferFrom(msg.sender, address(this), amount), "Transfer failed");
        loans[msg.sender].debt -= amount;
        emit Repaid(msg.sender, amount);
    }

    function withdrawCollateral() external nonReentrant {
        require(loans[msg.sender].debt == 0, "Debt must be repaid first");
        uint256 amount = loans[msg.sender].collateral;
        loans[msg.sender].collateral = 0;
        payable(msg.sender).transfer(amount);
    }

    function liquidate(address user) external nonReentrant {
        require(loans[user].collateral > 0, "No collateral");
        uint256 requiredCollateral = (loans[user].debt * LIQUIDATION_RATIO) / 100;
        require(loans[user].collateral < requiredCollateral, "Cannor liquidate yet");

        uint256 seizedCollateral = loans[user].collateral;
        loans[user].collateral = 0;
        loans[user].debt = 0;
        payable(msg.sender).transfer(seizedCollateral);

        emit Liquidated(user, msg.sender);
    }

    receive() external payable {}
}