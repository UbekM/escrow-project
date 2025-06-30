// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract DecentralizedEscrow {
    uint256 private escrowCounter;

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

    function createEscrow(address seller, address arbiter, uint256 amount, uint256 deadline, string memory description)
        external
        returns (uint256 escrowId)
    {
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

    function fundEscrow(uint256 escrowId) external payable onlyBuyer(escrowId) notCompleted(escrowId) {
        EscrowDetails storage esc = escrows[escrowId];
        require(!esc.funded, "Already funded");
        require(msg.value == esc.amount, "Incorrect amount");

        esc.funded = true;

        emit EscrowFunded(escrowId, msg.sender, msg.value);
    }

    function releaseFunds(uint256 escrowId) external onlySeller(escrowId) notCompleted(escrowId) {
        EscrowDetails storage esc = escrows[escrowId];
        require(esc.funded, "Not funded");

        esc.released = true;
        payable(esc.seller).transfer(esc.amount);

        emit FundsReleased(escrowId, esc.seller);
    }

    function requestRefund(uint256 escrowId) external onlyBuyer(escrowId) notCompleted(escrowId) {
        EscrowDetails storage esc = escrows[escrowId];
        require(esc.funded, "Not funded");
        require(block.timestamp > esc.deadline, "Deadline not passed");

        esc.refunded = true;

        (bool success,) = payable(esc.buyer).call{value: esc.amount}("");
        require(success, "Transfer failed");

        emit RefundRequested(escrowId, esc.buyer);
    }

    function resolveDispute(uint256 escrowId, bool releaseFundsToSeller)
        external
        onlyArbiter(escrowId)
        notCompleted(escrowId)
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

    function getEscrowDetails(uint256 escrowId) external view returns (EscrowDetails memory) {
        return escrows[escrowId];
    }
}
