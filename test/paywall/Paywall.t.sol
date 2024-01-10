// SPDX-License-Identifier: GNU GPLv3
pragma solidity ^0.8.0;

import { FrakTest } from "../FrakTest.sol";
import { InvalidFraktionType, NotAuthorized } from "contracts/utils/FrakErrors.sol";
import { ContentId, ContentIdLib } from "contracts/libs/ContentId.sol";
import { FraktionId } from "contracts/libs/FraktionId.sol";
import { Paywall } from "contracts/paywall/Paywall.sol";
import { IPaywall } from "contracts/paywall/IPaywall.sol";

/// @dev Testing methods on the Paywall contract
contract PaywallTest is FrakTest {
    /// The paywall we will test
    Paywall private _paywall;

    function setUp() public {
        _setupTests();

        // Deploy the paywall contract
        Paywall implementation = new Paywall();
        bytes memory initData =
            abi.encodeCall(Paywall.initialize, (address(frakToken), address(fraktionTokens), foundation));
        address proxy = _deployProxy(address(implementation), initData, "Paywall");
        _paywall = Paywall(proxy);
    }

    /* -------------------------------------------------------------------------- */
    /*                         Testing content price setup                        */
    /* -------------------------------------------------------------------------- */

    function test_addPrice() public {
        // Add two price
        vm.startPrank(contentOwner);
        _paywall.addPrice(contentId, IPaywall.UnlockPrice(100 ether, 1 days, true));
        _paywall.addPrice(contentId, IPaywall.UnlockPrice(600 ether, 7 days, false));
        vm.stopPrank();

        // Get all the prices for the given content
        IPaywall.UnlockPrice[] memory prices = _paywall.getContentPrices(contentId);
        assertEq(prices.length, 2, "Should have two prices");
        assertEq(prices[0].price, 100 ether, "Should have the correct price");
        assertEq(prices[0].allowanceTime, 1 days, "Should have the correct allowance time");
        assertEq(prices[0].isPriceEnabled, true, "Should have the correct price enabled");
        assertEq(prices[1].price, 600 ether, "Should have the correct price");
        assertEq(prices[1].allowanceTime, 7 days, "Should have the correct allowance time");
        assertEq(prices[1].isPriceEnabled, false, "Should have the correct price enabled");

        // Update a price
        vm.prank(contentOwner);
        _paywall.updatePrice(contentId, 1, IPaywall.UnlockPrice(600 ether, 7 days, true));

        // Get all the prices for the given content
        prices = _paywall.getContentPrices(contentId);
        assertEq(prices.length, 2, "Should have two prices");
        assertEq(prices[1].price, 600 ether, "Should have the correct price");
        assertEq(prices[1].allowanceTime, 7 days, "Should have the correct allowance time");
        assertEq(prices[1].isPriceEnabled, true, "Should have the correct price enabled");

        // Ensure we can't set a price to 0
        vm.prank(contentOwner);
        vm.expectRevert(IPaywall.PriceCannotBeZero.selector);
        _paywall.addPrice(contentId, IPaywall.UnlockPrice(0, 1 days, true));

        // Ensure we can't update a price to 0
        vm.prank(contentOwner);
        vm.expectRevert(IPaywall.PriceCannotBeZero.selector);
        _paywall.updatePrice(contentId, 1, IPaywall.UnlockPrice(0, 1 days, true));

        // Ensure we can't update a price that doesn't exist
        vm.prank(contentOwner);
        vm.expectRevert(abi.encodeWithSelector(IPaywall.PriceIndexOutOfBound.selector, 2));
        _paywall.updatePrice(contentId, 2, IPaywall.UnlockPrice(1 ether, 1 days, true));

        // Ensure we can disable price for a given content
        vm.prank(contentOwner);
        _paywall.disablePaywall(contentId);

        // And ensure that hte content doesn't have any prices after that
        prices = _paywall.getContentPrices(contentId);
        assertEq(prices.length, 0, "Should have no prices");
    }

    /* -------------------------------------------------------------------------- */
    /*                           Test article unlocking                           */
    /* -------------------------------------------------------------------------- */

    function test_unlockArticle() public withPrices withFrk(user, 1500 ether) {
        bytes32 articleId = 0;

        // Ensure that the user can't unlock an article with a price that doesn't exist
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(IPaywall.PriceIndexOutOfBound.selector, 4));
        _paywall.unlockAccess(contentId, articleId, 4);

        // Ensure that a user can't unlock with a disabled price
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(IPaywall.ArticlePriceDisabled.selector, contentId, articleId, 3));
        _paywall.unlockAccess(contentId, articleId, 3);

        // Ensure the user hasn't access to the article
        (bool isAllowed, uint256 allowedUntil) = _paywall.isReadAllowed(contentId, articleId, user);
        assertEq(isAllowed, false, "Shouldn't have access to the article");
        assertEq(allowedUntil, 0, "Shouldn't have access to the article");

        // Allow the paywall to transfer frk on the behalf of the user
        vm.prank(user);
        frakToken.increaseAllowance(address(_paywall), 1500 ether);

        // Ensure that the user can unlock an article with a price that exists
        vm.prank(user);
        _paywall.unlockAccess(contentId, articleId, 1);

        // Ensure the user has access to the article
        (isAllowed, allowedUntil) = _paywall.isReadAllowed(contentId, articleId, user);
        assertEq(isAllowed, true, "Should have access to the article");
        assertEq(allowedUntil, block.timestamp + 7 days, "Should have access to the article");

        // Ensure the content owner have some reward pending
        assertEq(_paywall.getAvailableFounds(contentOwner), 50 ether, "Should have some reward pending for the creator");

        // Ensure a user can't re unlock access to an article
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(IPaywall.ArticleAlreadyUnlocked.selector, contentId, articleId));
        _paywall.unlockAccess(contentId, articleId, 1);
    }

    modifier withPrices() {
        // Set a few prices
        vm.startPrank(contentOwner);
        _paywall.addPrice(contentId, IPaywall.UnlockPrice(10 ether, 1 days, true));
        _paywall.addPrice(contentId, IPaywall.UnlockPrice(50 ether, 7 days, true));
        _paywall.addPrice(contentId, IPaywall.UnlockPrice(300 ether, 30 days, true));
        _paywall.addPrice(contentId, IPaywall.UnlockPrice(900 ether, 90 days, false));
        vm.stopPrank();

        _;
    }
}
