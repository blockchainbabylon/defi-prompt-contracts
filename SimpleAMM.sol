//SPDX-license-Identifier: MIT
pragma solidity 0.8.26;

/*
Create a smart contract for an Automated Market Maker (AMM) on the Ethereum blockchain.
The contract should allow users to:

Add liquidity to a pool with two tokens (ETH and a token of your choice).
Remove liquidity and withdraw their proportionate share of tokens and ETH.
Swap ETH for tokens and tokens for ETH, adjusting the price based on the reserves in the pool 
using the constant product formula (x * y = k).
Implement a 0.3% fee on each trade.
Ensure that the contract doesn’t rely on any external imports or libraries and is self-contained.
*/

contract SimpleAMM {
    uint256 public tokenReserve;
    uint256 public ethReserve;
    uint256 public totalLiquidity;
    mapping(address => uint256) public liquidity;

    event LiquidityAdded(address indexed provider, uint256 ethAmount, uint256 tokenAmount);
    event LiquidityRemoved(address indexed provider, uint256 ethAmount, uint256 tokenAmount);
    event Swapped(address indexed user, uint256 ethIn, uint256 tokenOut);
    event SwappedReverse(address indexed user, uint256 tokenIn, uint256 ethOut);

    function addLiquidity() external payable returns(uint256) {
        require(msg.value > 0, "Must deposit ETH");

        uint256 tokenAmount = (msg.value * tokenReserve) / ethReserve;
        if (totalLiquidity == 0) {
            tokenAmount = msg.value;
            totalLiquidity = msg.value;
        }

        require(tokenAmount > 0, "Not enough tokens available");

        ethReserve += msg.value;
        tokenReserve += tokenAmount;
        liquidity[msg.sender] += msg.value;
        totalLiquidity += msg.value;

        emit LiquidityAdded(msg.sender, msg.value, tokenAmount);
        return msg.value;
    }

    function removeLiquidity(uint256 amount) external returns(uint256 ethAmount, uint256 tokenAmount) {
        require(amount > 0 && liquidity[msg.sender] >= amount, "Invalid liquidity amount");
        ethAmount = (amount * ethReserve) / totalLiquidity;
        tokenAmount = (amount * tokenReserve) / totalLiquidity;

        ethReserve -= ethAmount;
        tokenReserve -= tokenAmount;
        liquidity[msg.sender] -= amount;
        totalLiquidity -= amount;

        payable(msg.sender).transfer(ethAmount);

        emit LiquidityRemoved(msg.sender, ethAmount, tokenAmount);
    }

    function swapEthForTokens() external payable {
        require(msg.value > 0, "Must send ETH");

        uint256 tokensOut = getSwapAmount(msg.value, ethReserve, tokenReserve);
        require(tokensOut > 0, "Insufficient liquidity");

        ethReserve += msg.value;
        tokenReserve -= tokensOut;

        emit Swapped(msg.sender, msg.value, tokensOut);
    }

    function swapTokensForEth(uint256 tokenAmount) external {
        require(tokenAmount > 0, "Must send tokens");

        uint256 ethOut = getSwapAmount(tokenAmount, tokenReserve, ethReserve);
        require(ethOut > 0, "Insufficient liquidity");

        tokenReserve += tokenAmount;
        ethReserve -= ethOut;

        payable(msg.sender).transfer(ethOut);

        emit SwappedReverse(msg.sender, tokenAmount, ethOut);
    }

    function getSwapAmount(uint256 inputAmount, uint256 inputReserve, uint256 outputReserve) public pure returns(uint256) {
        uint256 inputAmountWithFee = inputAmount * 997;
        uint256 numerator = inputAmountWithFee * outputReserve;
        uint256 denominator = (inputReserve * 1000) + inputAmountWithFee;
        return numerator / denominator;
    }
}
