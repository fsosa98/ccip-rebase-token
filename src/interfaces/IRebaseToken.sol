// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IRebaseToken {
    function grantMintAndBurnRole(address _account) external;

    function setInterestRate(uint256 _newInterestRate) external;

    function principleBalanceOf(address _user) external view returns (uint256);

    function mint(address _to, uint256 _amount, uint256 _userInterestRate) external;

    function burn(address _from, uint256 _amount) external;

    function transfer(address _to, uint256 _amount) external returns (bool);

    function transferFrom(address _from, address _to, uint256 _amount) external returns (bool);

    function balanceOf(address _user) external view returns (uint256);

    function getUserInterestRate(address _user) external view returns (uint256);

    function getInterestRate() external view returns (uint256);
}
