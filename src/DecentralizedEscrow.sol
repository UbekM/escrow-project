// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title Decentralized Escrow Contract
/// @author
/// @notice Enables buyers and sellers to transact securely with an arbiter for dispute resolution.
/// @dev Uses pause functionality for emergency stop.
contract DecentralizedEscrow {
    uint256 private escrowCounter;
    address public owner;
    bool public paused;

    /// @notice Details of an escrow agreement
    struct EscrowDetails {
        address buyer;
        address seller;
        address arbiter;
        uint256 amount;
        uint256 deadline;
        string description;
        bool funded;
        bool released;
        bool refunded;
    }

    mapping(uint256 => EscrowDetails) public escrows;

    // Events
    event EscrowCreated(
        uint256 indexed escrowId,
        address indexed buyer,
        address indexed seller,
        address arbiter,
        uint256 amount,
        uint256 deadline,
        string description
    );
    event EscrowFunded(uint256 indexed escrowId, address indexed buyer, uint256 amount);
    event FundsReleased(uint256 indexed escrowId, address indexed seller);
    event RefundRequested(uint256 indexed escrowId, address indexed buyer);
    event DisputeResolved(uint256 indexed escrowId, bool fundsReleased, address indexed byArbiter);
    event Paused();
    event Unpaused();

    // Modifiers
    modifier onlyBuyer(uint256 escrowId) {
        require(msg.sender == escrows[escrowId].buyer, "Only buyer allowed");
        _;
    }

    modifier onlySeller(uint256 escrowId) {
        require(msg.sender == escrows[escrowId].seller, "Only seller allowed");
        _;
    }

    modifier onlyArbiter(uint256 escrowId) {
        require(msg.sender == escrows[escrowId].arbiter, "Only arbiter allowed");
        _;
    }

    modifier notCompleted(uint256 escrowId) {
        require(!escrows[escrowId].released && !escrows[escrowId].refunded, "Escrow completed");
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    modifier whenNotPaused() {
        require(!paused, "Contract is paused");
        _;
    }

    /// @notice Sets deployer as owner.
    constructor() {
        owner = msg.sender;
    }

    /// @notice Pause the contract, disabling critical functions.
    function pause() external onlyOwner {
        paused = true;
        emit Paused();
    }

    /// @notice Unpause the contract, enabling critical functions.
    function unpause() external onlyOwner {
        paused = false;
        emit Unpaused();
    }

    /// @notice Creates a new escrow agreement between buyer and seller.
    /// @param seller Address of the seller.
    /// @param arbiter Address of the arbiter.
    /// @param amount Amount to be escrowed in wei.
    /// @param deadline Time window (in seconds) after which buyer can request refund.
    /// @param description Text describing the escrow purpose.
    /// @return escrowId The ID of the created escrow.
    function createEscrow(
        address seller,
        address arbiter,
        uint256 amount,
        uint256 deadline,
        string memory description
    ) external whenNotPaused returns (uint256 escrowId) {
        escrowId = ++escrowCounter;
        escrows[escrowId] = EscrowDetails({
            buyer: msg.sender,
            seller: seller,
            arbiter: arbiter,
            amount: amount,
            deadline: block.timestamp + deadline,
            description: description,
            funded: false,
            released: false,
            refunded: false
        });

        emit EscrowCreated(escrowId, msg.sender, seller, arbiter, amount, block.timestamp + deadline, description);
    }

    /// @notice Fund the escrow by sending the agreed amount.
    /// @param escrowId The ID of the escrow to fund.
    function fundEscrow(uint256 escrowId) external payable onlyBuyer(escrowId) notCompleted(escrowId) whenNotPaused {
        EscrowDetails storage esc = escrows[escrowId];
        require(!esc.funded, "Already funded");
        require(msg.value == esc.amount, "Incorrect amount");

        esc.funded = true;

        emit EscrowFunded(escrowId, msg.sender, msg.value);
    }

    /// @notice Allows the seller to release funds once transaction conditions are met.
    /// @param escrowId The ID of the escrow to release funds from.
    function releaseFunds(uint256 escrowId) external onlySeller(escrowId) notCompleted(escrowId) whenNotPaused {
        EscrowDetails storage esc = escrows[escrowId];
        require(esc.funded, "Not funded");

        esc.released = true;
        payable(esc.seller).transfer(esc.amount);

        emit FundsReleased(escrowId, esc.seller);
    }

    /// @notice Buyer can request refund after deadline if conditions are not met.
    /// @param escrowId The ID of the escrow to request refund from.
    function requestRefund(uint256 escrowId) external onlyBuyer(escrowId) notCompleted(escrowId) whenNotPaused {
        EscrowDetails storage esc = escrows[escrowId];
        require(esc.funded, "Not funded");
        require(block.timestamp > esc.deadline, "Deadline not passed");

        esc.refunded = true;

        (bool success,) = payable(esc.buyer).call{value: esc.amount}("");
        require(success, "Transfer failed");

        emit RefundRequested(escrowId, esc.buyer);
    }

    /// @notice Arbiter resolves disputes by deciding to release funds to seller or refund buyer.
    /// @param escrowId The ID of the escrow dispute to resolve.
    /// @param releaseFundsToSeller True to release funds to seller, false to refund buyer.
    function resolveDispute(uint256 escrowId, bool releaseFundsToSeller)
        external
        onlyArbiter(escrowId)
        notCompleted(escrowId)
        whenNotPaused
    {
        EscrowDetails storage esc = escrows[escrowId];
        require(esc.funded, "Not funded");

        if (releaseFundsToSeller) {
            esc.released = true;
            payable(esc.seller).transfer(esc.amount);
        } else {
            esc.refunded = true;
            payable(esc.buyer).transfer(esc.amount);
        }

        emit DisputeResolved(escrowId, releaseFundsToSeller, msg.sender);
    }

    /// @notice Retrieves the details of a given escrow.
    /// @param escrowId The ID of the escrow to query.
    /// @return EscrowDetails struct with full escrow information.
    function getEscrowDetails(uint256 escrowId) external view returns (EscrowDetails memory) {
        return escrows[escrowId];
    }
}
