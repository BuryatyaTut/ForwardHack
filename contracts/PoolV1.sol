// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;
 
// Uncomment this line to use console.log
import "hardhat/console.sol";
import "./IERC20.sol";
 
 
// WARNING: WHEN DEPLOYING CHANGE EVERYTHING TO PRIVATE ?
 
contract PoolV1 {
    struct PoolInfo {
        address admin;
        address influencer; 
        address project; 
        IERC20 projectToken; 
        IERC20 payingToken;
 
        uint raiseStartTime;
        uint raiseEndTime;
 
        uint kolspadFeePercent;
        uint influencerFeePercent;
 
        uint minInvestorBalance;
        uint maxInvestorBalance;
        uint poolSize;
    }
 
    enum PoolState {
        ANNOUNCED, RAISING, RAISED, CLAIM, CANCELED, FINISHED
    }
 
    // -------------------------------------------------
    PoolInfo pool;
    PoolState public poolState;
 
    uint public poolBalance;
    uint kolspadRoyalty;
    uint influencerRoyalty;
    mapping(address => uint) investorBalance;
    uint finalPoolBalace;
 
    uint8 wavesCnt;
    mapping(uint8 => uint) wavesSize;
    mapping(address => uint8) usersWave;
 
    mapping(uint8 => bool) isInfluencerTaskCompleted;
 
    modifier onlyAdmin {
        require(msg.sender == pool.admin, "ADMIN: caller should be admin");
        _;
    }
 
    constructor (PoolInfo memory _pool) {
        poolState = PoolState.ANNOUNCED;
        pool = _pool;
    }
 
    // ----------------- PUBLIC FUNCTIONS ---------------------------------------
 
    function deposit(uint amount) public {
        require(block.timestamp > pool.raiseStartTime && block.timestamp < pool.raiseEndTime, "USER: pool is not open");
        require(poolState == PoolState.RAISING || poolState == PoolState.ANNOUNCED, "USER:pool isn't raising");
        require(investorBalance[msg.sender] + amount >= pool.minInvestorBalance && investorBalance[msg.sender] + amount <= pool.maxInvestorBalance, "USER: wrong balance");
        require(pool.poolSize - (poolBalance + amount) >= pool.minInvestorBalance || pool.poolSize - (poolBalance + amount) == 0, "USER: wrong amoun to deposit");
 
        poolBalance += amount;
        finalPoolBalace += amount;
        investorBalance[msg.sender] += amount;
 
        uint feeKolpad = amount * pool.kolspadFeePercent / 100;
        uint feeInfluencer = amount * pool.influencerFeePercent / 100;
 
        kolspadRoyalty += feeKolpad;
        influencerRoyalty += feeInfluencer;
 
        pool.payingToken.transferFrom(msg.sender, address(this), amount + feeKolpad + feeInfluencer);
 
        if (poolBalance >= pool.poolSize) {
            poolState = PoolState.RAISED;
        }
    }
 
    function claimTokens() public {
        require(poolState == PoolState.CLAIM, "USER: can't claim tokens yet");
        require(usersWave[msg.sender] < wavesCnt, "USER: already claimed");
 
        uint reward = 0;
        uint8 currWave = usersWave[msg.sender];
        while(currWave < wavesCnt) {
            reward += wavesSize[currWave];
            currWave += 1;
        }
 
        reward = reward * investorBalance[msg.sender] / finalPoolBalace;
        bool success = pool.projectToken.transfer(msg.sender, reward);
        require(success, "Transfer to project failed");
    }
 
    function claimDepositUSDT(uint amount) public { 
        require(poolState == PoolState.CANCELED, "USER: pool is not canceled");
        require(investorBalance[msg.sender] >= amount, "USER: insufficient balance");
 
        investorBalance[msg.sender] -= amount;
        poolBalance -= amount;
 
        bool success = pool.payingToken.transfer(msg.sender, amount);
        require(success, "Transfer to project failed");
    }
 
    // ----------------- ADMIN FUNCTIONS -------------------------------------
 
    function transferUSDTToProject(uint amount) public onlyAdmin {
        require(poolState == PoolState.RAISED, "ADMIN:pool stte should be RAISED");
        require(block.timestamp > pool.raiseEndTime, "ADMIN:pool isn't closed");
        require(poolBalance >= amount, "ADMIN:insf balance");
 
        poolBalance -= amount;
        bool success = pool.payingToken.transfer(pool.project, amount);
        require(success, "Transfer to project failed");
    }
 
    function setProjectAddress(address _project) public onlyAdmin {
        pool.project = _project;
    }
 
    function setEndTime(uint _time) public onlyAdmin {
        pool.raiseEndTime = _time;
    }
 
    function setPoolSize(uint _amount) public onlyAdmin {
        require(pool.poolSize < _amount, "ADMIN: can't set smaller pool size");
        pool.poolSize = _amount;
    }
 
    function setPoolState(PoolState _state) public onlyAdmin {
        require(poolState != _state, "ADMIN: pool state is the same");
 
        if (_state == PoolState.RAISING) {
            console.log("Raising");
        }
 
        poolState = _state; 
    }
 
    function changeInfluencerTaskStatus(uint8 id, bool status) public onlyAdmin {
        require(status != isInfluencerTaskCompleted[id], "ADMIN: task's status is already the same");
        isInfluencerTaskCompleted[id] = status;
    }
 
    function withdrawRoyalty() public onlyAdmin {
        require(kolspadRoyalty > 0, "ADMIN: insf balance");
 
        uint amount = kolspadRoyalty;
        kolspadRoyalty = 0;
        bool success = pool.payingToken.transfer(pool.admin, amount);
        require(success, "Transfer to project failed");
    }
 
    function cancelPool() public onlyAdmin {
        require(poolState != PoolState.CLAIM || poolState != PoolState.CANCELED, "ADMIN: wrong pool state");
 
        poolState = PoolState.CANCELED;
    }
 
    function confirmNewWave(uint amount) public onlyAdmin {
        wavesSize[wavesCnt] = amount;
        wavesCnt += 1;
    }
 
    // ------------------- INFLUENCER FUNCTIONS --------------------------
 
    function withdrawRoyaltyInfluencer() public {
        require(msg.sender == pool.influencer, "INFL: not influencer address");
        require(influencerRoyalty > 0, "INFL: insf balance");
        //require( influencer is good );
 
        uint amount = influencerRoyalty;
        influencerRoyalty = 0;
 
        bool success = pool.payingToken.transfer(msg.sender, amount);
        require(success, "Transfer to project failed");
    }
 
    // ------------------- GENERAL FUNCTIONS -----------------------------
 
}