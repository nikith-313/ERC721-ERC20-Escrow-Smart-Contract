// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract NFTEscrow is ReentrancyGuard {
    address public seller;
    address public buyer;

    IERC721 public nft;
    IERC20 public paymentToken;

    uint256 public tokenId;
    uint256 public price;

    bool public nftDeposited;
    bool public paymentDeposited;
    bool public completed;
    bool public cancelled;

    event NFTDeposited(address indexed seller, address indexed nft, uint256 indexed tokenId);
    event PaymentDeposited(address indexed buyer, address indexed token, uint256 amount);
    event SwapCompleted(address indexed seller, address indexed buyer, uint256 tokenId, uint256 price);
    event Cancelled(address indexed caller);

    modifier onlySeller() {
        require(msg.sender == seller, "Not seller");
        _;
    }

    modifier onlyBuyer() {
        require(msg.sender == buyer, "Not buyer");
        _;
    }

    modifier notCompletedOrCancelled() {
        require(!completed && !cancelled, "Already finished");
        _;
    }

    constructor(
        address _seller,
        address _buyer,
        address _nft,
        uint256 _tokenId,
        address _paymentToken,
        uint256 _price
    ) {
        require(_seller != address(0), "zero seller");
        require(_buyer != address(0), "zero buyer");
        require(_nft != address(0), "zero nft");
        require(_paymentToken != address(0), "zero token");
        require(_price > 0, "price zero");

        seller = _seller;
        buyer = _buyer;
        nft = IERC721(_nft);
        paymentToken = IERC20(_paymentToken);
        tokenId = _tokenId;
        price = _price;
    }

    /// @notice Seller deposits the NFT into escrow
    function depositNFT() external onlySeller notCompletedOrCancelled nonReentrant {
        require(!nftDeposited, "NFT already deposited");

        nft.transferFrom(seller, address(this), tokenId);
        nftDeposited = true;

        emit NFTDeposited(seller, address(nft), tokenId);
    }

    /// @notice Buyer deposits the ERC20 payment into escrow
    function depositPayment() external onlyBuyer notCompletedOrCancelled nonReentrant {
        require(!paymentDeposited, "Payment already deposited");

        bool ok = paymentToken.transferFrom(buyer, address(this), price);
        require(ok, "payment transfer failed");

        paymentDeposited = true;

        emit PaymentDeposited(buyer, address(paymentToken), price);
    }

    /// @notice Finalizes the swap — ONLY SELLER can do this
    function finalizeSwap() external onlySeller notCompletedOrCancelled nonReentrant {
        require(nftDeposited, "NFT not deposited");
        require(paymentDeposited, "Payment not deposited");

        completed = true;

        // send payment to seller
        bool okPayment = paymentToken.transfer(seller, price);
        require(okPayment, "pay seller failed");

        // send NFT to buyer
        nft.transferFrom(address(this), buyer, tokenId);

        emit SwapCompleted(seller, buyer, tokenId, price);
    }

    /// @notice Cancels the deal and refunds any deposited assets
    function cancel() external notCompletedOrCancelled nonReentrant {
        require(msg.sender == seller || msg.sender == buyer, "Not participant");

        cancelled = true;

        // Refund NFT to seller if deposited
        if (nftDeposited) {
            nft.transferFrom(address(this), seller, tokenId);
        }

        // Refund payment to buyer if deposited
        if (paymentDeposited) {
            bool ok = paymentToken.transfer(buyer, price);
            require(ok, "refund payment failed");
        }

        emit Cancelled(msg.sender);
    }

    receive() external payable {
        revert("No ETH accepted");
    }

    fallback() external payable {
        revert("No ETH accepted");
    }
}
