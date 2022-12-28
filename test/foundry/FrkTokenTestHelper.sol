// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.17;

import { FrakToken } from "@frak/tokens/FrakTokenL2.sol";
import { UUPSTestHelper } from "./UUPSTestHelper.sol";

/// Testing the frak l2 token
contract FrkTokenTestHelper is UUPSTestHelper {
    FrakToken frakToken;

    function _setupFrkToken() internal {
        // Deploy frak token
        bytes memory initData = abi.encodeCall(FrakToken.initialize, (address(this)));
        address frkProxyAddr = deployContract(address(new FrakToken()), initData);
        frakToken = FrakToken(frkProxyAddr);
    }

    /*
     * ===== UTILS=====
     */

    modifier withFrkToken(address target) {
        prankDeployer();
        frakToken.mint(address(target), 10);
        _;
    }

    modifier withLotFrkToken(address target) {
        prankDeployer();
        frakToken.mint(address(target), 500_000_000 ether);
        _;
    }
}
