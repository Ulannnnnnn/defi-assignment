// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/GameItems.sol";

contract GameItemsTest is Test {
    GameItems public game;
    address public alice = address(2);
    address public bob = address(3);

    function setUp() public {
        game = new GameItems(address(this));
    }

    function test_MintFungible() public {
        game.mint(alice, game.GOLD(), 100, "");
        assertEq(game.balanceOf(alice, game.GOLD()), 100);
    }

    function test_MintBatch() public {
        uint256[] memory ids = new uint256[](3);
        ids[0] = game.GOLD();
        ids[1] = game.WOOD();
        ids[2] = game.IRON();

        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 100;
        amounts[1] = 50;
        amounts[2] = 30;

        game.mintBatch(alice, ids, amounts, "");

        assertEq(game.balanceOf(alice, game.GOLD()), 100);
        assertEq(game.balanceOf(alice, game.WOOD()), 50);
        assertEq(game.balanceOf(alice, game.IRON()), 30);
    }

   function test_RevertMint_NotOwner() public {
    uint256 goldId = game.GOLD();
    vm.prank(alice);
    vm.expectRevert();
    game.mint(alice, goldId, 100, "");
}

function test_SafeTransferFrom() public {
    game.mint(alice, game.GOLD(), 100, "");
    vm.startPrank(alice);
    game.setApprovalForAll(alice, true);
    game.safeTransferFrom(alice, bob, game.GOLD(), 40, "");
    vm.stopPrank();
    assertEq(game.balanceOf(alice, game.GOLD()), 60);
    assertEq(game.balanceOf(bob, game.GOLD()), 40);
}
    function test_SafeBatchTransferFrom() public {
        uint256[] memory ids = new uint256[](2);
        ids[0] = game.GOLD();
        ids[1] = game.WOOD();

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 100;
        amounts[1] = 50;

        game.mintBatch(alice, ids, amounts, "");

        uint256[] memory transferAmounts = new uint256[](2);
        transferAmounts[0] = 30;
        transferAmounts[1] = 20;

        vm.prank(alice);
        game.safeBatchTransferFrom(alice, bob, ids, transferAmounts, "");

        assertEq(game.balanceOf(alice, game.GOLD()), 70);
        assertEq(game.balanceOf(bob, game.WOOD()), 20);
    }

    function test_CraftSword() public {
        game.mint(alice, game.GOLD(), 100, "");
        game.mint(alice, game.IRON(), 50, "");

        vm.prank(alice);
        game.craftSword();

        assertEq(game.balanceOf(alice, game.LEGENDARY_SWORD()), 1);
        assertEq(game.balanceOf(alice, game.GOLD()), 90);
        assertEq(game.balanceOf(alice, game.IRON()), 45);
        assertEq(game.nftSupply(game.LEGENDARY_SWORD()), 1);
    }

    function test_CraftShield() public {
        game.mint(alice, game.GOLD(), 100, "");
        game.mint(alice, game.WOOD(), 50, "");

        vm.prank(alice);
        game.craftShield();

        assertEq(game.balanceOf(alice, game.DRAGON_SHIELD()), 1);
        assertEq(game.balanceOf(alice, game.GOLD()), 92);
        assertEq(game.balanceOf(alice, game.WOOD()), 38);
    }

    function test_RevertCraftSword_NotEnoughGold() public {
        game.mint(alice, game.GOLD(), 5, "");
        game.mint(alice, game.IRON(), 50, "");

        vm.prank(alice);
        vm.expectRevert("Not enough GOLD");
        game.craftSword();
    }

    function test_RevertCraftShield_NotEnoughWood() public {
        game.mint(alice, game.GOLD(), 100, "");
        game.mint(alice, game.WOOD(), 5, "");

        vm.prank(alice);
        vm.expectRevert("Not enough WOOD");
        game.craftShield();
    }

    function test_Uri() public view {
        string memory uri = game.uri(0);
        assertEq(uri, "https://game.example.com/api/item/0.json");
    }
}