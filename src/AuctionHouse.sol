// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    /// @notice transferFrom - core operation
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
}

/// @title AuctionHouse
/// @notice Core contract for AuctionHouse on Arc Network
/// @dev Built with Foundry, deployed on Arc testnet (Chain ID: 5042002)
contract AuctionHouse {
    /// @notice Contract version
    string public constant VERSION = "1.1.0";

    IERC20 public immutable usdc;
    address public owner;

    struct Auction {
        address seller;
        string item;
        uint256 minBid;
        uint256 deadline;
        address highBidder;
        uint256 highBid;
        bool settled;
    }
    Auction[] public auctions;
    mapping(uint256 => mapping(address => uint256)) public bids;

    event AuctionCreated(uint256 indexed id, string item, uint256 minBid, uint256 deadline);
    event BidPlaced(uint256 indexed id, address bidder, uint256 amount);
    event Settled(uint256 indexed id, address winner, uint256 amount);

    constructor(address _usdc) {
        require(_usdc != address(0), "BAD_USDC");
        usdc = IERC20(_usdc);
        owner = msg.sender;
    }

    /// @notice createAuction - core operation
    function createAuction(string calldata item, uint256 minBid, uint256 duration) external returns (uint256) {
        auctions.push(Auction(msg.sender, item, minBid, block.timestamp + duration, address(0), 0, false));
        emit AuctionCreated(auctions.length - 1, item, minBid, block.timestamp + duration);
        return auctions.length - 1;
    }

    /// @notice bid - core operation
    function bid(uint256 id, uint256 amount) external {
        Auction storage a = auctions[id];
        require(block.timestamp < a.deadline && !a.settled, "CLOSED");
        require(amount > a.highBid && amount >= a.minBid, "LOW_BID");
        // refund previous bidder
        if (a.highBidder != address(0)) {
            require(usdc.transfer(a.highBidder, a.highBid), "REFUND_FAILED");
        }
        require(usdc.transferFrom(msg.sender, address(this), amount), "BID_FAILED");
        a.highBidder = msg.sender;
        a.highBid = amount;
        bids[id][msg.sender] = amount;
        emit BidPlaced(id, msg.sender, amount);
    }

    /// @notice settle - core operation
    function settle(uint256 id) external {
        Auction storage a = auctions[id];
        require(block.timestamp >= a.deadline && !a.settled, "CANNOT");
        a.settled = true;
        if (a.highBidder != address(0)) {
            require(usdc.transfer(a.seller, a.highBid), "PAY_FAILED");
        }
        emit Settled(id, a.highBidder, a.highBid);
    }
}
