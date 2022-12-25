// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.17;

import "@frak/tokens/FrakTokenL2.sol";
import "forge-std/console.sol";
import { ProxyTester } from "@foundry-upgrades/ProxyTester.sol";
import { PRBTest } from "@prb/test/PRBTest.sol";

/// Testing the frak l2 token
contract UUPSTestHelper is PRBTest {

    ProxyTester internal proxy;
    address internal proxyAdmin;
    address internal deployer;

    /**
     * @dev Setup our proxy if needed
     */
    function _setupProxy() private {
        if(address(proxy) == address(0)) {
            proxy = new ProxyTester();
            proxy.setType("uups");

            proxyAdmin = vm.addr(100);
            deployer = vm.addr(101);
        }
    }

    /**
     * @dev Modifier that setup the proxy if needed
     */
    modifier withProxy() {
        _setupProxy();
        _;
    }

    /**
     * @dev Deploy the given contract in an uups proxy
     * @return The deployed proxy address
     */
    function deployContract(address initialContract) internal withProxy returns(address) {
        vm.prank(deployer);
        return proxy.deploy(initialContract, proxyAdmin);
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
