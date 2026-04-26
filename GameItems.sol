// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract GameItems is ERC1155, Ownable {

    // Fungible tokens (ресурсы)
    uint256 public constant GOLD  = 0;
    uint256 public constant WOOD  = 1;
    uint256 public constant IRON  = 2;

    // Non-fungible items (предметы)
    uint256 public constant LEGENDARY_SWORD  = 3;
    uint256 public constant DRAGON_SHIELD    = 4;

    // Стоимость крафта
    uint256 public constant SWORD_GOLD_COST = 10;
    uint256 public constant SWORD_IRON_COST = 5;
    uint256 public constant SHIELD_GOLD_COST = 8;
    uint256 public constant SHIELD_WOOD_COST = 12;

    // Счётчик NFT (каждый уникален)
    mapping(uint256 => uint256) public nftSupply;

    constructor(address initialOwner)
        ERC1155("https://game.example.com/api/item/{id}.json")
        Ownable(initialOwner)
    {}

    // Минт одного токена
    function mint(
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) external onlyOwner {
        _mint(to, id, amount, data);
    }

    // Минт нескольких токенов сразу
    function mintBatch(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) external onlyOwner {
        _mintBatch(to, ids, amounts, data);
    }

    // Крафт Legendary Sword
    // Стоимость: 10 GOLD + 5 IRON
    function craftSword() external {
        require(balanceOf(msg.sender, GOLD) >= SWORD_GOLD_COST, "Not enough GOLD");
        require(balanceOf(msg.sender, IRON) >= SWORD_IRON_COST, "Not enough IRON");

        _burn(msg.sender, GOLD, SWORD_GOLD_COST);
        _burn(msg.sender, IRON, SWORD_IRON_COST);
        _mint(msg.sender, LEGENDARY_SWORD, 1, "");

        nftSupply[LEGENDARY_SWORD]++;
    }

    // Крафт Dragon Shield
    // Стоимость: 8 GOLD + 12 WOOD
    function craftShield() external {
        require(balanceOf(msg.sender, GOLD) >= SHIELD_GOLD_COST, "Not enough GOLD");
        require(balanceOf(msg.sender, WOOD) >= SHIELD_WOOD_COST, "Not enough WOOD");

        _burn(msg.sender, GOLD, SHIELD_GOLD_COST);
        _burn(msg.sender, WOOD, SHIELD_WOOD_COST);
        _mint(msg.sender, DRAGON_SHIELD, 1, "");

        nftSupply[DRAGON_SHIELD]++;
    }

    // URI с подстановкой token ID
    function uri(uint256 tokenId) public pure override returns (string memory) {
        return string(abi.encodePacked(
            "https://game.example.com/api/item/",
            _toString(tokenId),
            ".json"
        ));
    }

    function _toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) return "0";
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) { digits++; temp /= 10; }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits--;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }
}