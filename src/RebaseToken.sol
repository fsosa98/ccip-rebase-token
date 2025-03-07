// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

contract RebaseToken is ERC20, Ownable, AccessControl {
    error RebaseToken__InterestRateCanOnlyDecrease(uint256 oldInterestRate, uint256 newInterestRate);

    uint256 public constant PRECISION_FACTOR = 1e18;
    bytes32 public constant MINT_BURN_ROLE = keccak256("MINT_BURN_ROLE");
    uint256 private s_interestRate = (5 * PRECISION_FACTOR) / 1e8;
    mapping(address => uint256) public s_userInteresetRate;
    mapping(address => uint256) public s_userLastUpdatedTimestamp;

    event InterestRateSet(uint256 newInterestRate);

    constructor() ERC20("Rebase Token", "RBT") Ownable(msg.sender) {}

    function grantMintAndBurnRole(address _account) external onlyOwner {
        _grantRole(MINT_BURN_ROLE, _account);
    }

    function setInterestRate(uint256 _newInterestRate) external onlyOwner {
        if (_newInterestRate >= s_interestRate) {
            revert RebaseToken__InterestRateCanOnlyDecrease(s_interestRate, _newInterestRate);
        }
        s_interestRate = _newInterestRate;
        emit InterestRateSet(_newInterestRate);
    }

    function principleBalanceOf(address _user) external view returns (uint256) {
        return super.balanceOf(_user);
    }

    function mint(address _to, uint256 _amount) external onlyRole(MINT_BURN_ROLE) {
        _mintAccuredInterest(_to);
        s_userInteresetRate[_to] = s_interestRate;
        _mint(_to, _amount);
    }

    function burn(address _from, uint256 _amount) external onlyRole(MINT_BURN_ROLE) {
        _mintAccuredInterest(_from);
        _burn(_from, _amount);
    }

    function transfer(address _to, uint256 _amount) public override returns (bool) {
        _mintAccuredInterest(msg.sender);
        _mintAccuredInterest(_to);
        if (_amount == type(uint256).max) {
            _amount = balanceOf(_to);
        }
        if (s_userInteresetRate[_to] == 0) {
            s_userInteresetRate[_to] = s_userInteresetRate[msg.sender];
        }
        return super.transfer(_to, _amount);
    }

    function transferFrom(address _from, address _to, uint256 _amount) public override returns (bool) {
        _mintAccuredInterest(_from);
        _mintAccuredInterest(_to);
        if (_amount == type(uint256).max) {
            _amount = balanceOf(_to);
        }
        if (s_userInteresetRate[_to] == 0) {
            s_userInteresetRate[_to] = s_userInteresetRate[_from];
        }
        return super.transferFrom(_from, _to, _amount);
    }

    function balanceOf(address _user) public view override returns (uint256) {
        return (super.balanceOf(_user) * _calculateUserAccumulatedInterestSinceLastUpdate(_user)) / PRECISION_FACTOR;
    }

    function getUserInterestRate(address _user) external view returns (uint256) {
        return s_userInteresetRate[_user];
    }

    function getInterestRate() external view returns (uint256) {
        return s_interestRate;
    }

    function _calculateUserAccumulatedInterestSinceLastUpdate(address _user) internal view returns (uint256) {
        return PRECISION_FACTOR + (block.timestamp - s_userLastUpdatedTimestamp[_user]) * s_userInteresetRate[_user];
    }

    function _mintAccuredInterest(address _user) internal {
        uint256 balanceIncrese = balanceOf(_user) - super.balanceOf(_user);
        s_userLastUpdatedTimestamp[_user] = block.timestamp;
        _mint(_user, balanceIncrese);
    }
}
