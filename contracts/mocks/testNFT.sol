// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract TestNFT is ERC721 {
    uint256 public nextId = 1;

    constructor() ERC721("TestNFT", "TNFT") {}

    function mint(address to) external returns (uint256) {
        uint256 id = nextId++;
        _mint(to, id);
        return id;
    }
}
