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

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./DeliriumToken.sol";

// MasterChef is the master of Delirium. He can make Delirium and he is a fair guy.
//
// Note that it's ownable and the owner wields tremendous power. The ownership
// will be transferred to a governance smart contract once DELIRIUM is sufficiently
// distributed and the community can show to govern itself.
//
// Have fun reading it. Hopefully it's bug-free. God bless.
contract MasterChefV2 is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // Info of each user.
    struct UserInfo {
        uint256 amount;         // How many LP tokens the user has provided.
        uint256 rewardDebt;     // Reward debt. See explanation below.
        //
        // We do some fancy math here. Basically, any point in time, the amount of DELIRIUMs
        // entitled to a user but is pending to be distributed is:
        //
        //   pending reward = (user.amount * pool.accDeliriumPerShare) - user.rewardDebt
        //
        // Whenever a user deposits or withdraws LP tokens to a pool. Here's what happens:
        //   1. The pool's `accDeliriumPerShare` (and `lastRewardBlock`) gets updated.
        //   2. User receives the pending reward sent to his/her address.
        //   3. User's `amount` gets updated.
        //   4. User's `rewardDebt` gets updated.
    }

    // Info of each pool.
    struct PoolInfo {
        IERC20 lpToken;           // Address of LP token contract.
        uint256 allocPoint;       // How many allocation points assigned to this pool. DELIRIUMs to distribute per block.
        uint256 lastRewardBlock;  // Last block number that DELIRIUMs distribution occurs.
        uint256 accDeliriumPerShare;   // Accumulated DELIRIUMs per share, times 1e12. See below.
        uint16 depositFeeBP;      // Deposit fee in basis points
        uint256 lpSupply;
    }

    uint256 public deliriumMaximumSupply = 500 * (10 ** 3) * (10 ** 18); // 500,000 delirium

    // The DELIRIUM TOKEN!
    DeliriumToken public immutable delirium;
    // DELIRIUM tokens created per block.
    uint256 public deliriumPerBlock;
    // Deposit Fee address
    address public feeAddress;

    // Info of each pool.
    PoolInfo[] public poolInfo;
    // Info of each user that stakes LP tokens.
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;
    // Total allocation points. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint = 0;
    // The block number when DELIRIUM mining starts.
    uint256 public startBlock;
    // The block number when DELIRIUM mining ends.
    uint256 public emmissionEndBlock = type(uint256).max;

    event addPool(uint256 indexed pid, address lpToken, uint256 allocPoint, uint256 depositFeeBP);
    event setPool(uint256 indexed pid, address lpToken, uint256 allocPoint, uint256 depositFeeBP);
    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event SetEmissionRate(address indexed caller, uint256 previousAmount, uint256 newAmount);
    event SetFeeAddress(address indexed user, address indexed newAddress);
    event SetStartBlock(uint256 newStartBlock);
    
    constructor(
        DeliriumToken _delirium,
        address _feeAddress,
        uint256 _deliriumPerBlock,
        uint256 _startBlock
    ) {
        require(_feeAddress != address(0), "!nonzero");

        delirium = _delirium;
        feeAddress = _feeAddress;
        deliriumPerBlock = _deliriumPerBlock;
        startBlock = _startBlock;
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    mapping(IERC20 => bool) public poolExistence;
    modifier nonDuplicated(IERC20 _lpToken) {
        require(poolExistence[_lpToken] == false, "nonDuplicated: duplicated");
        _;
    }

    // Add a new lp to the pool. Can only be called by the owner.
    function add(uint256 _allocPoint, IERC20 _lpToken, uint16 _depositFeeBP, bool _withUpdate) external onlyOwner nonDuplicated(_lpToken) {
        // Make sure the provided token is ERC20
        _lpToken.balanceOf(address(this));

        require(_depositFeeBP <= 401, "add: invalid deposit fee basis points");
        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 lastRewardBlock = block.number > startBlock ? block.number : startBlock;
        totalAllocPoint = totalAllocPoint + _allocPoint;
        poolExistence[_lpToken] = true;

        poolInfo.push(PoolInfo({
        lpToken : _lpToken,
        allocPoint : _allocPoint,
        lastRewardBlock : lastRewardBlock,
        accDeliriumPerShare : 0,
        depositFeeBP : _depositFeeBP,
        lpSupply: 0
        }));

        emit addPool(poolInfo.length - 1, address(_lpToken), _allocPoint, _depositFeeBP);
    }

    // Update the given pool's DELIRIUM allocation point and deposit fee. Can only be called by the owner.
    function set(uint256 _pid, uint256 _allocPoint, uint16 _depositFeeBP, bool _withUpdate) external onlyOwner {
        require(_depositFeeBP <= 401, "set: invalid deposit fee basis points");
        if (_withUpdate) {
            massUpdatePools();
        }
        totalAllocPoint = totalAllocPoint - poolInfo[_pid].allocPoint + _allocPoint;
        poolInfo[_pid].allocPoint = _allocPoint;
        poolInfo[_pid].depositFeeBP = _depositFeeBP;

        emit setPool(_pid, address(poolInfo[_pid].lpToken), _allocPoint, _depositFeeBP);
    }

    // Return reward multiplier over the given _from to _to block.
    function getMultiplier(uint256 _from, uint256 _to) public view returns (uint256) {
        // As we set the multiplier to 0 here after emmissionEndBlock
        // deposits aren't blocked after farming ends.
        if (_from > emmissionEndBlock)
            return 0;
        if (_to > emmissionEndBlock)
            return emmissionEndBlock - _from;
        else
            return _to - _from;
    }

    // View function to see pending DELIRIUMs on frontend.
    function pendingDelirium(uint256 _pid, address _user) external view returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accDeliriumPerShare = pool.accDeliriumPerShare;
        if (block.number > pool.lastRewardBlock && pool.lpSupply != 0 && totalAllocPoint > 0) {
            uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
            uint256 deliriumReward = (multiplier * deliriumPerBlock * pool.allocPoint) / totalAllocPoint;
            accDeliriumPerShare = accDeliriumPerShare + ((deliriumReward * 1e12) / pool.lpSupply);
        }

        return ((user.amount * accDeliriumPerShare) /  1e12) - user.rewardDebt;
    }

    // Update reward variables for all pools. Be careful of gas spending!
    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.number <= pool.lastRewardBlock) {
            return;
        }

        if (pool.lpSupply == 0 || pool.allocPoint == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }

        uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
        uint256 deliriumReward = (multiplier * deliriumPerBlock * pool.allocPoint) / totalAllocPoint;

        // This shouldn't happen, but just in case we stop rewards.
        if (delirium.totalSupply() > deliriumMaximumSupply)
            deliriumReward = 0;
        else if ((delirium.totalSupply() + deliriumReward) > deliriumMaximumSupply)
            deliriumReward = deliriumMaximumSupply - delirium.totalSupply();

        if (deliriumReward > 0)
            delirium.mint(address(this), deliriumReward);

        // The first time we reach Delirium max supply we solidify the end of farming.
        if (delirium.totalSupply() >= deliriumMaximumSupply && emmissionEndBlock == type(uint256).max)
            emmissionEndBlock = block.number;

        pool.accDeliriumPerShare = pool.accDeliriumPerShare + ((deliriumReward * 1e12) / pool.lpSupply);
        pool.lastRewardBlock = block.number;
    }

    // Deposit LP tokens to MasterChef for DELIRIUM allocation.
    function deposit(uint256 _pid, uint256 _amount) external nonReentrant {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);
        if (user.amount > 0) {
            uint256 pending = ((user.amount * pool.accDeliriumPerShare) / 1e12) - user.rewardDebt;
            if (pending > 0) {
                safeDeliriumTransfer(msg.sender, pending);
            }
        }
        if (_amount > 0) {
            uint256 balanceBefore = pool.lpToken.balanceOf(address(this));
            pool.lpToken.safeTransferFrom(address(msg.sender), address(this), _amount);
            _amount = pool.lpToken.balanceOf(address(this)) - balanceBefore;
            require(_amount > 0, "we dont accept deposits of 0 size");

            if (pool.depositFeeBP > 0) {
                uint256 depositFee = (_amount * pool.depositFeeBP) / 10000;
                pool.lpToken.safeTransfer(feeAddress, depositFee);
                user.amount = user.amount + _amount - depositFee;
                pool.lpSupply = pool.lpSupply + _amount - depositFee;
            } else {
                user.amount = user.amount + _amount;
                pool.lpSupply = pool.lpSupply + _amount;
            }
        }
        user.rewardDebt = (user.amount * pool.accDeliriumPerShare) / 1e12;

        emit Deposit(msg.sender, _pid, _amount);
    }

    // Withdraw LP tokens from MasterChef.
    function withdraw(uint256 _pid, uint256 _amount) external nonReentrant {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >= _amount, "withdraw: not good");
        updatePool(_pid);
        uint256 pending = ((user.amount * pool.accDeliriumPerShare) / 1e12) - user.rewardDebt;
        if (pending > 0) {
            safeDeliriumTransfer(msg.sender, pending);
        }
        if (_amount > 0) {
            user.amount = user.amount - _amount;
            pool.lpToken.safeTransfer(address(msg.sender), _amount);
            pool.lpSupply = pool.lpSupply - _amount;
        }
        user.rewardDebt = (user.amount * pool.accDeliriumPerShare) / 1e12;
        emit Withdraw(msg.sender, _pid, _amount);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) external nonReentrant {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        uint256 amount = user.amount;
        user.amount = 0;
        user.rewardDebt = 0;
        pool.lpToken.safeTransfer(address(msg.sender), amount);

        // In the case of an accounting error, we choose to let the user emergency withdraw anyway
        if (pool.lpSupply >=  amount)
            pool.lpSupply = pool.lpSupply - amount;
        else
            pool.lpSupply = 0;

        emit EmergencyWithdraw(msg.sender, _pid, amount);
    }

    // Safe delirium transfer function, just in case if rounding error causes pool to not have enough DELIRIUMs.
    function safeDeliriumTransfer(address _to, uint256 _amount) internal {
        uint256 deliriumBal = delirium.balanceOf(address(this));
        bool transferSuccess = false;
        if (_amount > deliriumBal) {
            transferSuccess = delirium.transfer(_to, deliriumBal);
        } else {
            transferSuccess = delirium.transfer(_to, _amount);
        }
        require(transferSuccess, "safeDeliriumTransfer: transfer failed");
    }

    function setFeeAddress(address _feeAddress) external onlyOwner {
        require(_feeAddress != address(0), "!nonzero");
        feeAddress = _feeAddress;
        emit SetFeeAddress(msg.sender, _feeAddress);
    }

    function setStartBlock(uint256 _newStartBlock) external onlyOwner {
        require(block.number < startBlock, "cannot change start block if sale has already commenced");
        require(block.number < _newStartBlock, "cannot set start block in the past");
        startBlock = _newStartBlock;

        emit SetStartBlock(startBlock);
    }

    function setEmissionRate(uint256 _deliriumPerBlock) public onlyOwner {
        require(_deliriumPerBlock > 0);

        massUpdatePools();
        deliriumPerBlock = _deliriumPerBlock;
        
        emit SetEmissionRate(msg.sender, deliriumPerBlock, _deliriumPerBlock);
    }
}