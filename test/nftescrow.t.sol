// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.28;
import "forge-std/Test.sol";
import "../contracts/nftescrow.sol";
import "../contracts/mocks/testNFT.sol";
import "../contracts/mocks/testToken.sol";

contract NFTEscrowTest is Test {
    NFTEscrow nftescrow;
    TestNFT _nft;
    TestToken _token;
    event NFTDeposited(
        address indexed seller,
        address indexed nft,
        uint256 indexed tokenId
    );
    event PaymentDeposited(
        address indexed buyer,
        address indexed token,
        uint256 amount
    );
    event SwapCompleted(
        address indexed seller,
        address indexed buyer,
        uint256 tokenId,
        uint256 price
    );
    event Cancelled(address indexed caller);
    address public seller = address(0x1);
    address public buyer = address(0x2);
    uint256 tokenId;
    uint256 price;

    function setUp() public {
        _nft = new TestNFT();
        _token = new TestToken();
        uint256 id = _nft.mint(seller);
        _token.mint(buyer, 100 ether);
        price = 50 ether;
        tokenId = id;
        nftescrow = new NFTEscrow(
            seller,
            buyer,
            address(_nft),
            tokenId,
            address(_token),
            price
        );
    }

    //constructor test
    function testConstructor() public view {
        assertEq(nftescrow.seller(), seller);
        assertEq(nftescrow.buyer(), buyer);
        assertEq(address(nftescrow.nft()), address(_nft));
        assertEq(nftescrow.tokenId(), tokenId);
        assertEq(address(nftescrow.paymentToken()), address(_token));
        assertEq(nftescrow.price(), price);
    }

    // initial flags test
    function testInitialFlags() public view {
        assertFalse(nftescrow.nftDeposited());
        assertFalse(nftescrow.paymentDeposited());
        assertFalse(nftescrow.completed());
        assertFalse(nftescrow.cancelled());
    }

    // nft deposit test and make sure important flags doesn't change
    function testNftDeposit() public {
        vm.prank(seller);
        _nft.approve(address(nftescrow), tokenId);
        vm.prank(seller);
        nftescrow.depositNFT();
        assertTrue(nftescrow.nftDeposited());
        assertEq(_nft.ownerOf(tokenId), address(nftescrow));
        assertTrue(_nft.ownerOf(tokenId) != seller);
        assertFalse(nftescrow.paymentDeposited());
        assertFalse(nftescrow.completed());
        assertFalse(nftescrow.cancelled());
    }

    //should not transfer nft without approval
    function testNftWithoutApproval() public {
        vm.prank(seller);
        vm.expectRevert();
        nftescrow.depositNFT();
    }

    //should revert if depositNft() caller is not seller
    function testDepositNftOnlySeller() public {
        vm.prank(buyer);
        vm.expectRevert();
        nftescrow.depositNFT();
    }

    //escrow shouldn't accept nft twice
    function testDepositNftTwice() public {
        vm.prank(seller);
        _nft.approve(address(nftescrow), tokenId);
        vm.prank(seller);
        nftescrow.depositNFT();
        vm.prank(seller);
        vm.expectRevert();
        nftescrow.depositNFT();
    }

    //payment token deposit tests
    function testDepositPaymentToken() public {
        vm.prank(buyer);
        _token.approve(address(nftescrow), price);
        vm.prank(buyer);
        nftescrow.depositPayment();
        assertEq(_token.balanceOf(address(nftescrow)), price);
        assertTrue(nftescrow.paymentDeposited());
        assertFalse(nftescrow.completed());
        assertFalse(nftescrow.cancelled());
    }

    // only Buyer should deposit payment token
    function testDepositpaymentTokenOnlyBuyer() public {
        vm.prank(seller);
        vm.expectRevert();
        nftescrow.depositPayment();
    }

    //escrow shouldn't accept payment token twice
    function testDepositPaymentTokenTwice() public {
        vm.prank(buyer);
        _token.approve(address(nftescrow), price);
        vm.prank(buyer);
        nftescrow.depositPayment();
        vm.prank(buyer);
        vm.expectRevert();
        nftescrow.depositPayment();
    }

    //should revert if buyer has insuffiect token funds
    function testInsufficientPaymentTokens() public {
        TestToken weakToken = new TestToken();
        weakToken.mint(buyer, 10 ether);
        // Deploy escrow using weakToken
        NFTEscrow esc = new NFTEscrow(
            seller,
            buyer,
            address(_nft),
            tokenId,
            address(weakToken),
            price
        );
        vm.prank(buyer);
        weakToken.approve(address(esc), price);
        vm.prank(buyer);
        vm.expectRevert();
        esc.depositPayment();
    }

    function _depositsBeforeFinalizaSwap() internal {
        vm.prank(seller);
        _nft.approve(address(nftescrow), tokenId);
        vm.prank(seller);
        nftescrow.depositNFT();
        assertTrue(nftescrow.nftDeposited());
        assertEq(_nft.ownerOf(tokenId), address(nftescrow));
        assertTrue(_nft.ownerOf(tokenId) != seller);
        vm.prank(buyer);
        _token.approve(address(nftescrow), price);
        vm.prank(buyer);
        nftescrow.depositPayment();
        assertEq(_token.balanceOf(address(nftescrow)), price);
        assertTrue(nftescrow.paymentDeposited());
        assertFalse(nftescrow.completed());
        assertFalse(nftescrow.cancelled());
    }

    function testFinalizeSwap() public {
        uint256 balanceOfSellerBefore = _token.balanceOf(seller);
        _depositsBeforeFinalizaSwap();
        vm.prank(seller);
        nftescrow.finalizeSwap();
        assertEq(_nft.ownerOf(tokenId), buyer);
        assertEq(_token.balanceOf(seller), balanceOfSellerBefore + price);
        assertTrue(nftescrow.completed());
        assertFalse(nftescrow.cancelled());
    }

    function testBuyerCannotFinalizeSwap() public {
        _depositsBeforeFinalizaSwap();
        vm.prank(buyer);
        vm.expectRevert();
        nftescrow.finalizeSwap();
    }

    function testStrangerCannotFinalizeSwap() public {
        _depositsBeforeFinalizaSwap();
        address stranger = address(0x123);
        vm.prank(stranger);
        vm.expectRevert();
        nftescrow.finalizeSwap();
    }

    function testFinalizeWithoutNFT() public {
        vm.prank(buyer);
        _token.approve(address(nftescrow), price);
        vm.prank(buyer);
        nftescrow.depositPayment();
        vm.prank(seller);
        vm.expectRevert();
        nftescrow.finalizeSwap();
    }

    function testFinalizeWithoutPayment() public {
        vm.prank(seller);
        _nft.approve(address(nftescrow), tokenId);
        vm.prank(seller);
        nftescrow.depositNFT();
        vm.prank(seller);
        vm.expectRevert();
        nftescrow.finalizeSwap();
    }

    function testFinalizeTwice() public {
        _depositsBeforeFinalizaSwap();
        vm.prank(seller);
        nftescrow.finalizeSwap();
        vm.prank(seller);
        vm.expectRevert();
        nftescrow.finalizeSwap();
    }

    function testCancelOnlyNFTDeposited() public {
        // Seller deposits NFT
        vm.prank(seller);
        _nft.approve(address(nftescrow), tokenId);
        vm.prank(seller);
        nftescrow.depositNFT();
        vm.prank(seller);
        nftescrow.cancel();
        // NFT returned to seller
        assertEq(_nft.ownerOf(tokenId), seller);
        assertEq(_token.balanceOf(address(nftescrow)), 0);
        assertTrue(nftescrow.cancelled());
        assertFalse(nftescrow.completed());
    }

    function testCancelOnlyPaymentDeposited() public {
        // Buyer deposits token
        vm.prank(buyer);
        _token.approve(address(nftescrow), price);
        vm.prank(buyer);
        nftescrow.depositPayment();
        uint256 buyerBalanceBefore = _token.balanceOf(buyer);
        vm.prank(buyer);
        nftescrow.cancel();
        // refund to buyer
        assertEq(_token.balanceOf(buyer), buyerBalanceBefore + price);
        // NFT untouched
        assertEq(_nft.ownerOf(tokenId), seller);
        assertTrue(nftescrow.cancelled());
        assertFalse(nftescrow.completed());
    }

    function testCancelAfterBothDeposited() public {
        _depositsBeforeFinalizaSwap();
        uint256 buyerBalanceBefore = _token.balanceOf(buyer);
        vm.prank(buyer);
        nftescrow.cancel();
        // NFT refunded to seller
        assertEq(_nft.ownerOf(tokenId), seller);
        // Tokens refunded to buyer
        assertEq(_token.balanceOf(buyer), buyerBalanceBefore + price);
        assertTrue(nftescrow.cancelled());
        assertFalse(nftescrow.completed());
    }

    function testCannotCancelAfterFinalize() public {
        _depositsBeforeFinalizaSwap();
        vm.prank(seller);
        nftescrow.finalizeSwap();
        vm.prank(seller);
        vm.expectRevert();
        nftescrow.cancel();
    }

    function testCannotCancelTwice() public {
        _depositsBeforeFinalizaSwap();
        vm.prank(seller);
        nftescrow.cancel();
        vm.prank(buyer);
        vm.expectRevert();
        nftescrow.cancel();
    }

    function testCannotDepositNFTAfterCancel() public {
        vm.prank(buyer);
        nftescrow.cancel();
        vm.prank(seller);
        vm.expectRevert();
        nftescrow.depositNFT();
    }

    function testCannotDepositPaymentAfterCancel() public {
        vm.prank(buyer);
        nftescrow.cancel();
        vm.prank(buyer);
        vm.expectRevert();
        nftescrow.depositPayment();
    }

    function testCannotFinalizeAfterCancel() public {
        _depositsBeforeFinalizaSwap();
        vm.prank(buyer);
        nftescrow.cancel();
        vm.prank(seller);
        vm.expectRevert();
        nftescrow.finalizeSwap();
    }

    function testEventNFTDeposited() public {
        vm.prank(seller);
        _nft.approve(address(nftescrow), tokenId);
        vm.expectEmit(true, true, true, false, address(nftescrow));
        emit NFTDeposited(seller, address(_nft), tokenId);
        vm.prank(seller);
        nftescrow.depositNFT();
    }

    function testEventPaymentDeposited() public {
        vm.prank(buyer);
        _token.approve(address(nftescrow), price);
        vm.expectEmit(true, true, false, true, address(nftescrow));
        emit PaymentDeposited(buyer, address(_token), price);
        vm.prank(buyer);
        nftescrow.depositPayment();
    }

    function testEventSwapCompleted() public {
        _depositsBeforeFinalizaSwap();
        vm.expectEmit(true, true, true, true);
        emit SwapCompleted(seller, buyer, tokenId, price);
        vm.prank(seller);
        nftescrow.finalizeSwap();
    }

    function testEventCancelled() public {
        vm.expectEmit(true, false, false, false, address(nftescrow));
        emit Cancelled(seller);
        vm.prank(seller);
        nftescrow.cancel();
    }
}
