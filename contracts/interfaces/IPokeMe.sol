//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ITaskTreasury {
	event FundsDeposited(
		address indexed sender,
		address indexed token,
		uint256 indexed amount
	);
	event FundsWithdrawn(
		address indexed receiver,
		address indexed initiator,
		address indexed token,
		uint256 amount
	);

	/// @notice Function to deposit Funds which will be used to execute transactions on various services
	/// @param _receiver Address receiving the credits
	/// @param _token Token to be credited, use "0xeeee...." for ETH
	/// @param _amount Amount to be credited
	function depositFunds(
		address _receiver,
		address _token,
		uint256 _amount
	) external payable;

	/// @notice Function to withdraw Funds back to the _receiver
	/// @param _receiver Address receiving the credits
	/// @param _token Token to be credited, use "0xeeee...." for ETH
	/// @param _amount Amount to be credited
	function withdrawFunds(
		address payable _receiver,
		address _token,
		uint256 _amount
	) external;

	// View Funcs

	/// @notice Helper func to get all deposited tokens by a user
	/// @param _user User to get the balances from
	function getCreditTokensByUser(address _user)
		external
		view
		returns (address[] memory);

	function userTokenBalance(address, address) external view returns (uint256);
}

interface IPokeMe {
	event TaskCreated(
		address taskCreator,
		address execAddress,
		bytes4 selector,
		address resolverAddress,
		bytes32 taskId,
		bytes resolverData
	);
	event TaskCancelled(bytes32 taskId, address taskCreator);
	event ExecSuccess(
		uint256 indexed txFee,
		address indexed feeToken,
		address indexed execAddress,
		bytes execData,
		bytes32 taskId
	);

	/// @notice Create a task that tells Gelato to monitor and execute transactions on specific contracts
	/// @param _execAddress On which contract should Gelato execute the transactions
	/// @param _execSelector Which function Gelato should eecute on the _execAddress
	/// @param _resolverAddress On which contract should Gelato check when to execute the tx
	/// @param _resolverData Which data should be used to check on the Resolver when to execute the tx
	function createTask(
		address _execAddress,
		bytes4 _execSelector,
		address _resolverAddress,
		bytes calldata _resolverData
	) external;

	/// @notice Execution API called by Gelato
	/// @param _txFee Fee paid to Gelato for execution, deducted on the TaskTreasury
	/// @param _feeToken Token used to pay for the execution. ETH = 0xeeeeee...
	/// @param _taskCreator On which contract should Gelato check when to execute the tx
	/// @param _execAddress On which contract should Gelato execute the tx
	/// @param _execData Data used to execute the tx, queried from the Resolver by Gelato
	function exec(
		uint256 _txFee,
		address _feeToken,
		address _taskCreator,
		address _execAddress,
		bytes calldata _execData
	) external;

	function cancelTask(bytes32 _taskId) external;

	function gelato() external view returns (address);

	function getTaskIdsByUser(address _taskCreator)
		external
		view
		returns (bytes32[] memory);
}
