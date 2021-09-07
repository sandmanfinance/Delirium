/*
   o__ __o        o__ __o__/_   o           __o__   o__ __o        __o__   o         o    o          o  
 <|     v\      <|    v       <|>            |    <|     v\         |    <|>       <|>  <|\        /|> 
 / \     <\     < >           / \           / \   / \     <\       / \   / \       / \  / \\o    o// \ 
 \o/       \o    |            \o/           \o/   \o/     o/       \o/   \o/       \o/  \o/ v\  /v \o/ 
  |         |>   o__/_         |             |     |__  _<|         |     |         |    |   <\/>   |  
 / \       //    |            / \           < >    |       \       < >   < >       < >  / \        / \ 
 \o/      /     <o>           \o/            |    <o>       \o      |     \         /   \o/        \o/ 
  |      o       |             |             o     |         v\     o      o       o     |          |  
 / \  __/>      / \  _\o__/_  / \ _\o__/_  __|>_  / \         <\  __|>_    <\__ __/>    / \        / \ 
                                                                                                       
*/

// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract StrategyDividends is Ownable, ReentrancyGuard, Pausable {

    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    
    struct UserInfo {
        uint256 shares; // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.

        /**
         * We do some fancy math here. Basically, any point in time, the amount of USDC
         * entitled to a user but is pending to be distributed is:
         *
         *   amount = user.shares / sharesTotal * wantLockedTotal
         *   pending reward = (amount * pool.accPerShare) - user.rewardDebt
         *
         * Whenever a user deposits or withdraws want tokens to a pool. Here's what happens:
         *   1. The pool's `accPerShare` (and `lastRewardBlock`) gets updated.
         *   2. User receives the pending reward sent to his/her address.
         *   3. User's `amount` gets updated.
         *   4. User's `rewardDebt` gets updated.
         */
    }

    address public constant rewardTokenAddress = 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174;
    address public constant wantAddress = 0xf9b4dEFdDe04fe18F5ee6456607F8A2eC9fF6A75;

    address public vaultChefAddress;
    address public govAddress; // timelock contract

    mapping(address => UserInfo) public userInfo;
    uint256 public sharesTotal = 0;
    uint256 public wantLockedTotal = 0; // Will always be the same as sharesTotal, so vault doesnt break
    uint256 public accPerShare = 0;

    constructor(
        address _vaultChefAddress
    ) public {
        govAddress = msg.sender;
        vaultChefAddress = _vaultChefAddress;

        transferOwnership(vaultChefAddress);
    }
    
    modifier onlyGov() {
        require(msg.sender == govAddress, "!gov");
        _;
    }

    function pendingReward(address _user) external view returns (uint256) {
        UserInfo storage user = userInfo[_user];
        return user.shares.mul(accPerShare).div(1e18).sub(user.rewardDebt);
    }

    function deposit(address _userAddress, uint256 _wantAmt) external onlyOwner nonReentrant whenNotPaused returns (uint256) {
        UserInfo storage user = userInfo[_userAddress];
        
        uint256 pending = user.shares.mul(accPerShare).div(1e18).sub(user.rewardDebt);
        if (pending > 0) {
            IERC20(rewardTokenAddress).safeTransfer(_userAddress, pending);
        }

        IERC20(wantAddress).safeTransferFrom(
            msg.sender,
            address(this),
            _wantAmt
        );

        sharesTotal = sharesTotal.add(_wantAmt);
        wantLockedTotal = sharesTotal;
        user.shares = user.shares.add(_wantAmt);
        
        user.rewardDebt = user.shares.mul(accPerShare).div(1e18);

        return _wantAmt;
    }

    function withdraw(address _userAddress, uint256 _wantAmt) external onlyOwner nonReentrant returns (uint256) {
        require(_wantAmt > 0, "_wantAmt <= 0");
        UserInfo storage user = userInfo[_userAddress];
        
        uint256 pending = user.shares.mul(accPerShare).div(1e18).sub(user.rewardDebt);
        if (pending > 0) {
            IERC20(rewardTokenAddress).safeTransfer(_userAddress, pending);
        }

        uint256 wantAmt = IERC20(wantAddress).balanceOf(address(this));
        if (_wantAmt > wantAmt) {
            _wantAmt = wantAmt;
        }
        
        sharesTotal = sharesTotal.sub(_wantAmt);
        wantLockedTotal = sharesTotal;

        IERC20(wantAddress).safeTransfer(vaultChefAddress, _wantAmt);
        if (_wantAmt > user.shares) {
            user.shares = 0;
        } else {
            user.shares = user.shares.sub(_wantAmt);
        }
        
        user.rewardDebt = user.shares.mul(accPerShare).div(1e18);

        return _wantAmt;
    }
    
    function harvest() external nonReentrant {
        UserInfo storage user = userInfo[msg.sender];
        
        uint256 pending = user.shares.mul(accPerShare).div(1e18).sub(user.rewardDebt);
        if (pending > 0) {
            IERC20(rewardTokenAddress).safeTransfer(msg.sender, pending);
        }
        user.rewardDebt = user.shares.mul(accPerShare).div(1e18);
    }
    
    function depositReward(uint256 _depositAmt) external returns (bool) {
        IERC20(rewardTokenAddress).safeTransferFrom(msg.sender, address(this), _depositAmt);
        if (sharesTotal == 0) {
            return false;
        }
        accPerShare = accPerShare.add(_depositAmt.mul(1e18).div(sharesTotal));
        
        return true;
    }

    function pause() external onlyGov {
        _pause();
    }

    function unpause() external onlyGov {
        _unpause();
    }

    function setGov(address _govAddress) external onlyGov {
        govAddress = _govAddress;
    }
}