# NFT–ERC20 Escrow Smart Contract

A trustless smart contract that enables secure NFT (ERC721) to ERC20 token swaps without needing intermediaries. Both buyer and seller must fulfill their conditions or the deal is cancelled and refunded.

## Overview

Traditional NFT trades require trust: the seller may send the NFT and never receive payment, or the buyer may pay and never receive the NFT. Centralized marketplaces also create censorship and custody risks. This escrow contract enforces fairness on-chain:

Seller deposits NFT → Buyer deposits tokens → Seller finalizes → Swap happens atomically.  
If anything goes wrong, either party can cancel and assets return to their owners.

## Key Features

- Full on-chain escrow mechanism
- Atomic finalization (NFT → buyer, ERC20 → seller)
- Role enforcement: seller deposits NFT and finalizes, buyer deposits tokens
- Cancellation before completion (refund NFT to seller and tokens to buyer)
- Safe state transitions and reentrancy protection
- Rejects ETH transfers

## State Machine

Initial

- seller.depositNFT() → nftDeposited = true
- buyer.depositPayment() → paymentDeposited = true
- cancel() → refund assets
- seller.finalizeSwap() → atomic swap → completed forever

## Contract Interfaces

### depositNFT()
- Only seller
- Requires NFT approval
- Transfers NFT to escrow contract

### depositPayment()
- Only buyer
- Requires ERC20 allowance
- Transfers tokens to escrow contract

### finalizeSwap()
- Only seller
- Requires nftDeposited && paymentDeposited
- Transfers NFT to buyer and tokens to seller atomically

### cancel()
- Buyer or seller
- Only if not completed
- Refund rules:
  - NFT → seller (if deposited)
  - Tokens → buyer (if deposited)

## Events

event NFTDeposited(address seller, address nft, uint256 tokenId);
event PaymentDeposited(address buyer, address token, uint256 amount);
event SwapCompleted(address seller, address buyer, uint256 tokenId, uint256 price);
event Cancelled(address caller);

These events allow indexing, UI handlers, and analytics to track escrow lifecycle.


## Testing

Tests are written in Solidity using Hardhat VM helpers. They cover:

- Constructor value correctness
- Initial state flags
- Seller-only NFT deposit
- Buyer-only payment deposit
- Prevention of double deposits
- Finalization success path
- Token and NFT ownership after swap
- Refund scenarios:
  - Only NFT deposited
  - Only payment deposited
  - Both deposited
- Cancel behavior
- Restriction after cancel/finalize
- Event validation using expectEmit
- Edge cases

Example flow tested:

seller approves → seller.depositNFT()  
buyer approves → buyer.depositPayment()  
seller.finalizeSwap()


## Security Considerations

- Uses ReentrancyGuard
- Uses CEI pattern (checks → effects → interactions)
- Rejects ETH transfer to prevent loss
- Only seller/buyer can interact
- Refunds are deterministic and safe

This implementation is educational and should be audited before production.


## Skills Demonstrated

- Solidity contract architecture
- ERC20/721 interoperability
- State machine based design
- Role-based access control
- Reentrancy protection
- TDD with Hardhat
- Event-driven protocol design

## Author

**Nikith**  
Learning smart contracts and auditing , trustless protocols, and Web3 engineering. If you find this useful, star the repository.
