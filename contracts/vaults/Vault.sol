//SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "../interfaces/IStrat.sol";
import "../interfaces/IVault.sol";
import "./DividendToken.sol";
import "../utils/Timelock.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "../interfaces/IDistribution.sol";

contract Vault is Ownable, Pausable, DividendToken {
	using SafeMath for uint256;
	using SafeERC20 for IERC20Detailed;
	using SafeERC20 for IERC20;

	// EVENTS
	event HarvesterChanged(address newHarvester);
	event FeeUpdate(uint256 newFee);
	event StrategyChanged(address newStrat);
	event DepositLimitUpdated(uint256 newLimit);
	event NewDistribution(address newDistribution);

	IERC20Detailed public underlying;
	IERC20 public rewards;
	IStrat public strat;
	Timelock public timelock;

	address public harvester;

	uint256 constant MAX_FEE = 10000;
	uint256 public performanceFee = 0; // 0% of profit

	// if depositLimit = 0 then there is no deposit limit
	uint256 public depositLimit;
	uint256 public lastDistribution;
	address public distribution;

	modifier onlyHarvester {
		require(msg.sender == harvester);
		_;
	}

	constructor(
		IERC20Detailed underlying_,
		IERC20 target_,
		IERC20 rewards_,
		address harvester_,
		string memory name_,
		string memory symbol_
	) DividendToken(target_, name_, symbol_, underlying_.decimals()) {
		underlying = underlying_;
		rewards = rewards_;
		harvester = harvester_;
		depositLimit = 20000 * (10**underlying_.decimals()); // 20k initial deposit limit
		timelock = new Timelock(msg.sender, 2 days);
		_pause(); // paused until a strategy is connected
	}

	function calcTotalValue() public view returns (uint256 underlyingAmount) {
		return strat.calcTotalValue();
	}

	function totalYield() public returns (uint256) {
		return strat.totalYield();
	}

	function deposit(uint256 amount) external whenNotPaused {
		require(amount > 0, "ZERO-AMOUNT");
		if (depositLimit > 0) {
			// if deposit limit is 0, then there is no deposit limit
			require(totalSupply().add(amount) <= depositLimit);
		}

		underlying.safeTransferFrom(msg.sender, address(strat), amount);
		strat.invest();

		_mint(msg.sender, amount);

		if (distribution != address(0)) {
			IDistribution(distribution).stake(msg.sender, amount);
		}
	}

	function withdraw(uint256 amount) external {
		require(amount > 0, "ZERO-AMOUNT");

		_burn(msg.sender, amount);

		strat.divest(amount);
		underlying.safeTransfer(msg.sender, amount);

		if (distribution != address(0)) {
			IDistribution(distribution).withdraw(msg.sender, amount);
		}

		// Claim profits when withdrawing
		claim();
	}

	function unclaimedProfit(address user) external view returns (uint256) {
		return withdrawableDividendOf(user);
	}

	function claim() public returns (uint256 claimed) {
		claimed = withdrawDividend(msg.sender);

		if (distribution != address(0)) {
			IDistribution(distribution).getReward(msg.sender);
		}
	}

	// Used to claim on behalf of certain contracts e.g. Uniswap pool
	function claimOnBehalf(address recipient) external {
		require(msg.sender == harvester || msg.sender == owner());
		withdrawDividend(recipient);
	}

	// ==== ONLY OWNER ===== //

	function updateDistribution(address newDistribution) public onlyOwner {
		distribution = newDistribution;
		emit NewDistribution(newDistribution);
	}

	function pauseDeposits(bool trigger) external onlyOwner {
		if (trigger) _pause();
		else _unpause();
	}

	function changeHarvester(address harvester_) external onlyOwner {
		harvester = harvester_;

		emit HarvesterChanged(harvester_);
	}

	function changePerformanceFee(uint256 fee_) external onlyOwner {
		require(fee_ <= MAX_FEE);
		performanceFee = fee_;

		emit FeeUpdate(fee_);
	}

	// if limit == 0 then there is no deposit limit
	function setDepositLimit(uint256 limit) external onlyOwner {
		depositLimit = limit;

		emit DepositLimitUpdated(limit);
	}

	// Any tokens (other than the target) that are sent here by mistake are recoverable by the owner
	function sweep(address _token) external onlyOwner {
		require(_token != address(target));
		IERC20(_token).transfer(
			owner(),
			IERC20(_token).balanceOf(address(this))
		);
	}

	// ==== ONLY HARVESTER ===== //

	function harvest() external onlyHarvester returns (uint256 afterFee) {
		// Divest and claim rewards
		uint256 claimed = strat.claim();

		require(claimed > 0, "Nothing to harvest");

		if (performanceFee > 0) {
			// Calculate fees on underlying
			uint256 fee = claimed.mul(performanceFee).div(MAX_FEE);
			afterFee = claimed.sub(fee);
			rewards.safeTransfer(owner(), fee);
		} else {
			afterFee = claimed;
		}

		// Transfer rewards to harvester
		rewards.safeTransfer(harvester, afterFee);
	}

	function distribute(uint256 amount) external onlyHarvester {
		distributeDividends(amount);
		lastDistribution = block.timestamp;
	}

	// ==== ONLY TIMELOCK ===== //

	// The owner has to wait 2 days to confirm changing the strat.
	// This protects users from an upgrade to a malicious strategy
	// Users must watch the timelock contract on Etherscan for any transactions
	function setStrat(IStrat strat_, bool force) external {
		if (address(strat) != address(0)) {
			require(msg.sender == address(timelock), "Only Timelock");
			uint256 prevTotalValue = strat.calcTotalValue();
			strat.divest(prevTotalValue);
			underlying.safeTransfer(
				address(strat_),
				underlying.balanceOf(address(this))
			);
			strat_.invest();
			if (!force) {
				require(strat_.calcTotalValue() >= prevTotalValue);
				require(strat.calcTotalValue() == 0);
			}
		} else {
			require(msg.sender == owner());
			_unpause();
		}
		strat = strat_;

		emit StrategyChanged(address(strat));
	}
}
