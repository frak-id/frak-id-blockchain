// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.21;

import {ERC1967Proxy} from "openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";
import {PRBTest} from "@prb/test/PRBTest.sol";

/// Testing the frak l2 token
contract UUPSTestHelper is PRBTest {
    address internal deployer = vm.addr(100);

    /**
     * @dev Deploy the given contract in an uups proxy
     * @return The deployed proxy address
     */
    function deployContract(address logic, bytes memory init) internal returns (address) {
        vm.prank(deployer);
        ERC1967Proxy proxyTemp = new ERC1967Proxy(logic, init);
        return address(proxyTemp);
    }

    /**
     * @dev Modifier that prank all this execution as the deployer
     */
    modifier prankExecAsDeployer() {
        vm.startPrank(deployer);
        _;
        vm.stopPrank();
    }

    /**
     * @dev Prank the next call as the deployer address
     */
    function prankDeployer() internal {
        vm.prank(deployer);
    }
}
