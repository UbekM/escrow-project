// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/DecentralizedEscrow.sol";

contract DecentralizedEscrowTest is Test {
    DecentralizedEscrow escrow;

    address buyer = address(1);
    address seller = address(2);
    address arbiter = address(3);

    function setUp() public {
        escrow = new DecentralizedEscrow();
        vm.deal(buyer, 10 ether); // Give buyer funds
    }

    function testCreateAndFundEscrow() public {
        vm.prank(buyer);
        uint256 id = escrow.createEscrow(seller, arbiter, 1 ether, 1 days, "Buy item A");

        vm.prank(buyer);
        escrow.fundEscrow{value: 1 ether}(id);

        DecentralizedEscrow.EscrowDetails memory details = escrow.getEscrowDetails(id);
        address b = details.buyer;
        address s = details.seller;
        uint256 amt = details.amount;
        string memory desc = details.description;

        assertEq(b, buyer);
        assertEq(s, seller);
        assertEq(amt, 1 ether);
        assertEq(desc, "Buy item A");
    }

    function testReleaseFunds() public {
        vm.prank(buyer);
        uint256 id = escrow.createEscrow(seller, arbiter, 1 ether, 1 days, "Item B");
        vm.prank(buyer);
        escrow.fundEscrow{value: 1 ether}(id);

        vm.prank(seller);
        escrow.releaseFunds(id);
    }

    function testRequestRefundAfterDeadline() public {
        vm.prank(buyer);
        uint256 id = escrow.createEscrow(seller, arbiter, 1 ether, 1 days, "Item C");
        vm.prank(buyer);
        escrow.fundEscrow{value: 1 ether}(id);

        vm.warp(block.timestamp + 2 days);
        vm.prank(buyer);
        escrow.requestRefund(id);
    }

    function testResolveDisputeByArbiter() public {
        vm.prank(buyer);
        uint256 id = escrow.createEscrow(seller, arbiter, 1 ether, 1 days, "Item D");
        vm.prank(buyer);
        escrow.fundEscrow{value: 1 ether}(id);

        vm.prank(arbiter);
        escrow.resolveDispute(id, true); // Give to seller
    }
}
