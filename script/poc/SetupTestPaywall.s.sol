// SPDX-License-Identifier: GNU GPLv3
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import { UpgradeScript } from "../utils/UpgradeScript.s.sol";
import { ContentId } from "contracts/libs/ContentId.sol";
import { IMinter } from "contracts/minter/IMinter.sol";
import { Paywall } from "contracts/paywall/Paywall.sol";
import { IPaywall } from "contracts/paywall/IPaywall.sol";

contract SetupTestPaywall is UpgradeScript {
    function run() external {
        // Get the current treasury wallet address
        UpgradeScript.ContractProxyAddresses memory addresses = _currentProxyAddresses();

        // Mint a new test content
        address owner = 0x7caF754C934710D7C73bc453654552BEcA38223F;
        ContentId contentId = _mintContent(IMinter(addresses.minter), owner);
        console.log("Content id: %s", ContentId.unwrap(contentId));

        // Add a few prices
        Paywall paywall = Paywall(addresses.paywall);
        _addTestPrices(paywall, contentId);
    }

    /// @dev Mint a new test content
    function _mintContent(IMinter _minter, address _owner) internal deployerBroadcast returns (ContentId) {
        return _minter.addContentForCreator(_owner);
    }

    /// @dev Add test prices to the given content
    function _addTestPrices(Paywall _paywall, ContentId _contentId) internal deployerBroadcast {
        _paywall.addPrice(_contentId, IPaywall.UnlockPrice(50 ether, 1 days, true));
        _paywall.addPrice(_contentId, IPaywall.UnlockPrice(300 ether, 7 days, true));
        _paywall.addPrice(_contentId, IPaywall.UnlockPrice(1000 ether, 30 days, true));
    }
}
