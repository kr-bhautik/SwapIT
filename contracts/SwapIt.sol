// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract SwapIt {
    using EnumerableSet for EnumerableSet.AddressSet;
    IUniswapV2Router02 private constant router = IUniswapV2Router02(address(0xeE567Fe1712Faf6149d80dA1E6934E354124CfE3));
    address private owner;
    uint256 private fees = 5; // 5 % (percentage)

    EnumerableSet.AddressSet private ownedTokens;

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "NOT AUTHORIZED.");
        _;
    }

    function setFees(uint256 _fees) public onlyOwner {
        require(fees > 0 , "Fees must be greater than 0");
        fees = _fees;
    }

// Views 
    function calculateFeesAndApplicableSwapAmount(uint256 amountIn) public view returns (uint256, uint256) {
        uint256 feesAmount = (amountIn * fees)/100;
        uint256 applicableSwapAmount = amountIn - feesAmount;

        return (feesAmount, applicableSwapAmount);
    }

    function getExptedAmount(uint256 token0Amount, address token0Addr, address token1Addr) public view returns (uint256 ){
        address[] memory path = new address[](2);
        path[0] = token0Addr;
        path[1] = token1Addr;

        uint256[] memory amounts = router.getAmountsOut(token0Amount, path);
        return amounts[1];
    }

    function getBalances() public view returns (address[] memory token, uint256[] memory balance) {
        uint n = ownedTokens.length();
        token = new address[](n);
        balance = new uint256[](n);
        for(uint i=0 ; i < n ; i++){
            IERC20 _token = IERC20(ownedTokens.at(i));
            uint256 bal = _token.balanceOf(address(this));

            token[i] = ownedTokens.at(i);
            balance[i] = bal;
        }     
    }

// Core Functions.
    function swapTokensForToken(address token0Addr, address token1Addr, uint256 token0Amount, uint56 amountOutMin, address to) public returns (uint256 ) {

        require(IERC20(token0Addr).transferFrom(msg.sender, address(this), token0Amount), "Token transferFrom failed.");
        (, uint256 applicableSwapAmount) = calculateFeesAndApplicableSwapAmount(token0Amount);

        require(IERC20(token0Addr).approve(address(router), applicableSwapAmount));
        
        address[] memory path = new address[](2);
        path[0] = token0Addr;
        path[1] = token1Addr;
        ownedTokens.add(token0Addr);

        uint[] memory amounts = router.swapExactTokensForTokens(applicableSwapAmount, amountOutMin, path, to, block.timestamp + 2 minutes);
        return amounts[1];
    }

    function swapTokensForEth(address tokenAddr, uint256 amountIn, uint56 amountOutMin, address to) public returns (uint256 ) {

        require(IERC20(tokenAddr).transferFrom(msg.sender, address(this), amountIn), "Token transferFrom failed.");
        (, uint256 applicableSwapAmount) = calculateFeesAndApplicableSwapAmount(amountIn);   
        require(IERC20(tokenAddr).approve(address(router), applicableSwapAmount));

        address[] memory path = new address[](2);
        path[0] = tokenAddr;
        path[1] = router.WETH();
        ownedTokens.add(tokenAddr);

        uint[] memory amounts = router.swapExactTokensForETH(applicableSwapAmount, amountOutMin, path, to, block.timestamp + 2 minutes);
        return amounts[1];
    }

    function swapEthForTokens(address tokenAddr, uint56 amountOutMin, address to) public payable  returns (uint256 ) {
        
        uint amountIn = msg.value;
        require( amountIn > 0, "Amount must be greater than zero.");
        address[] memory path = new address[](2);
        path[0] = router.WETH();
        path[1] = tokenAddr;
        (, uint256 applicableSwapAmount) = calculateFeesAndApplicableSwapAmount(amountIn);
        require(applicableSwapAmount > 0 , "Not enough fund sent to swap");

        uint[] memory amounts = router.swapExactETHForTokens{value: applicableSwapAmount}(amountOutMin, path, to, block.timestamp + 2 minutes);
        return amounts[1];
    }

    function withdraw() public onlyOwner {
        payable(owner).transfer(address(this).balance);
        uint n = ownedTokens.length();
        for(uint i = 0 ; i < n ; i++ ){
            IERC20 token = IERC20(ownedTokens.at(i));
            uint balance = token.balanceOf(address(this));
            if(balance > 0){
                token.transfer(owner, balance);
            }
        }
    } 
}

// 0xf8c3B2C4F3F48af50320B1946A134841895f3d15