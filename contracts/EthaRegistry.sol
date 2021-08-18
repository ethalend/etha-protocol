//SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./wallet/SmartWallet.sol";
import "./utils/CloneFactory.sol";

/**
 * @title Logic Registry
 */
contract LogicRegistry is OwnableUpgradeable {
	using SafeMath for uint256;

	/// @dev address timelock contract
	address public timelock;

	/// EVENTS
	event LogEnableLogic(address indexed logicAddress);
	event LogDisableLogic(address indexed logicAddress);

	/// @notice Map of logic proxy state
	mapping(address => bool) public logicProxies;

	/// @dev
	/// @param _logicAddress (address)
	/// @return  (bool)
	function logic(address _logicAddress) external view returns (bool) {
		return logicProxies[_logicAddress];
	}

	/// @dev Enable logic proxy address
	/// @param _logicAddress (address)
	function enableLogic(address _logicAddress) public onlyOwner {
		require(_logicAddress != address(0), "ZERO ADDRESS");
		logicProxies[_logicAddress] = true;
		emit LogEnableLogic(_logicAddress);
	}

	/// @dev Enable multiple logic proxy addresses
	/// @param _logicAddresses (addresses)
	function enableLogicMultiple(address[] calldata _logicAddresses) external {
		for (uint256 i = 0; i < _logicAddresses.length; i++) {
			enableLogic(_logicAddresses[i]);
		}
	}

	/// @dev Disable logic proxy address
	/// @param _logicAddress (address)
	function disableLogic(address _logicAddress) public onlyOwner {
		require(_logicAddress != address(0), "ZERO ADDRESS");
		logicProxies[_logicAddress] = false;
		emit LogDisableLogic(_logicAddress);
	}

	/// @dev Disable multiple logic proxy addresses
	/// @param _logicAddresses (addresses)
	function disableLogicMultiple(address[] calldata _logicAddresses) external {
		for (uint256 i = 0; i < _logicAddresses.length; i++) {
			disableLogic(_logicAddresses[i]);
		}
	}
}

/**
 * @dev Deploys a new proxy instance and sets msg.sender as owner of proxy
 */
contract WalletRegistry is LogicRegistry, CloneFactory {
	event Created(address indexed owner, address proxy);
	event LogRecord(
		address indexed currentOwner,
		address indexed nextOwner,
		address proxy
	);

	/// @dev implementation address of Smart Wallet
	address public implementation;

	/// @notice Address to UserWallet proxy map
	mapping(address => SmartWallet) public wallets;

	/// @notice Address to Bool registration status map
	mapping(address => bool) public walletRegistered;

	/// @dev Deploys a new proxy instance and sets custom owner of proxy
	/// Throws if the owner already have a UserWallet
	/// @return wallet - address of new Smart Wallet
	function deployWallet() external returns (SmartWallet wallet) {
		require(
			wallets[msg.sender] == SmartWallet(payable(0)),
			"multiple-proxy-per-user-not-allowed"
		);
		address payable _wallet = payable((createClone(implementation)));
		wallet = SmartWallet(_wallet);
		wallet.initialize(address(this), msg.sender);
		wallets[msg.sender] = wallet; // will be changed via record() in next line execution
		walletRegistered[address(_wallet)] = true;
		emit Created(msg.sender, address(wallet));
	}

	/// @dev Change the address implementation of the Smart Wallet
	/// @param _impl new implementation address of Smart Wallet
	function setImplementation(address _impl) external onlyOwner {
		implementation = _impl;
	}
}

/// @title ETHA Registry
contract EthaRegistry is WalletRegistry {
	/// @dev address of recipient receiving the protocol fees
	address public feeRecipient;

	/// @dev stores values shared accross logic contracts
	address public memoryAddr;

	/// @dev fee percentage charged when redeeming (1% = 1000)
	uint256 fee;

	/// @dev keep track of token addresses not allowed to withdraw (i.e. cETH)
	mapping(address => bool) public notAllowed;

	/// @dev keep track of lending distribution contract per token
	mapping(address => address) public distributionContract;

	// EVENTS
	event FeeUpdated(uint256 newFee);
	event FeeRecipientUpdated(address newRecipient);
	event FeeManagerUpdated(address newFeeManager);

	/// @dev address of feeManager contract
	address feeManager;

	function initialize(
		address _impl,
		address _feeRecipient,
		address _memoryAddr,
		address[] memory _initialLogics,
		uint256 _fee
	) external initializer {
		require(_feeRecipient != address(0), "ZERO ADDRESS");
		__Ownable_init();

		// Enable Logics for the first time
		for (uint256 i = 0; i < _initialLogics.length; i++) {
			require(_initialLogics[i] != address(0), "ZERO ADDRESS");
			logicProxies[_initialLogics[i]] = true;
		}

		implementation = _impl;
		fee = _fee;
		feeRecipient = _feeRecipient;
		memoryAddr = _memoryAddr;
	}

	function setFee(uint256 _fee) public onlyOwner {
		fee = _fee;
		emit FeeUpdated(_fee);
	}

	function setMemory(address _memoryAddr) public onlyOwner {
		memoryAddr = _memoryAddr;
	}

	function getFee() external view returns (uint256) {
		return fee;
	}

	function getFeeManager() external view returns (address) {
		return feeManager;
	}

	function changeFeeRecipient(address _feeRecipient) external onlyOwner {
		feeRecipient = _feeRecipient;
		emit FeeRecipientUpdated(_feeRecipient);
	}

	function changeFeeManager(address _feeManager) external onlyOwner {
		feeManager = _feeManager;
		emit FeeManagerUpdated(_feeManager);
	}

	/**
	 * @dev add erc20 token contract to not allowance set
	 */
	function addNotAllowed(address[] memory _tokens) external onlyOwner {
		for (uint256 i = 0; i < _tokens.length; i++) {
			notAllowed[_tokens[i]] = true;
		}
	}

	/**
	 * @dev remove erc20 token contract from not allowance set
	 */
	function removeNotAllowed(address[] memory _tokens) external onlyOwner {
		for (uint256 i = 0; i < _tokens.length; i++) {
			notAllowed[_tokens[i]] = false;
		}
	}

	/**
	 * @dev get ethereum address
	 */
	function getAddressETH() public pure returns (address eth) {
		eth = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
	}

	/**
	 * @dev Set Distribution Contract For Tokens
	 */
	function setDistribution(address token, address distAddress)
		external
		onlyOwner
	{
		require(
			token != address(0) && distAddress != address(0),
			"ZERO ADDRESS"
		);
		distributionContract[token] = distAddress;
	}

	/**
	 * @dev recover tokens sent to contract
	 */
	function sweep(
		address erc20,
		address recipient,
		uint256 amount
	) external onlyOwner {
		require(erc20 != address(0) && recipient != address(0), "ZERO ADDRESS");
		if (erc20 == getAddressETH()) {
			payable(recipient).transfer(amount);
		} else {
			IERC20(erc20).transfer(recipient, amount);
		}
	}
}
