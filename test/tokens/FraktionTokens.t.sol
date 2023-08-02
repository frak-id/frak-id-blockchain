// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.21;

import {PRBTest} from "@prb/test/PRBTest.sol";
import {StdUtils} from "@forge-std/StdUtils.sol";
import {FraktionTokens} from "@frak/tokens/FraktionTokens.sol";
import {UUPSTestHelper} from "../UUPSTestHelper.sol";
import {FrakMath} from "@frak/utils/FrakMath.sol";
import {
    NotAuthorized,
    InvalidAddress,
    ContractPaused,
    BadgeTooLarge,
    InvalidFraktionType
} from "@frak/utils/FrakErrors.sol";

/// Testing the frak l2 token
contract FraktionTokensTest is UUPSTestHelper, StdUtils {
    using FrakMath for uint256;

    FraktionTokens fraktionTokens;

    uint256[] internal sampleArray = uint256(3).asSingletonArray();

    function setUp() public {
        // Deploy our contract via proxy and set the proxy address
        bytes memory initData = abi.encodeCall(FraktionTokens.initialize, ("test"));
        address proxyAddress = deployContract(address(new FraktionTokens()), initData);
        fraktionTokens = FraktionTokens(proxyAddress);
    }

    /*
     * ===== TEST : initialize(address childChainManager) =====
     */
    function test_fail_initialize_CantInitTwice() public {
        vm.expectRevert("Initializable: contract is already initialized");
        fraktionTokens.initialize("test");
    }

    /*
     * ===== TEST : mintNewContent(address ownerAddress) =====
     */
    function test_mintNewContent() public prankExecAsDeployer {
        uint256 contentId = fraktionTokens.mintNewContent(address(1), sampleArray, sampleArray);
        uint256 nftId = contentId.buildNftId();
        assertEq(fraktionTokens.balanceOf(address(1), nftId), 1);
    }

    function test_fail_mintNewContent_ContractPaused() public prankExecAsDeployer {
        fraktionTokens.pause();
        vm.expectRevert(ContractPaused.selector);
        fraktionTokens.mintNewContent(address(1), sampleArray, sampleArray);
    }

    function test_fail_mintNewContent_NotAuthorized() public {
        vm.expectRevert(NotAuthorized.selector);
        fraktionTokens.mintNewContent(address(1), sampleArray, sampleArray);
    }

    function test_fail_mintNewContent_InvalidAddress() public prankExecAsDeployer {
        vm.expectRevert("ERC1155: mint to the zero address");
        fraktionTokens.mintNewContent(address(0), sampleArray, sampleArray);
    }

    /*
     * ===== TEST : mint(address to, uint256 id, uint256 amount) =====
     */
    function test_mint() public prankExecAsDeployer {
        fraktionTokens.mint(address(1), 1312, 1);
        assertEq(fraktionTokens.balanceOf(address(1), 1312), 1);
    }

    function test_fail_mint_ContractPaused() public prankExecAsDeployer {
        fraktionTokens.pause();
        vm.expectRevert(ContractPaused.selector);
        fraktionTokens.mint(address(1), 1312, 1);
    }

    function test_fail_mint_NotAuthorized() public {
        vm.expectRevert(NotAuthorized.selector);
        fraktionTokens.mint(address(1), 1312, 1);
    }

    function test_fail_mint_InvalidAddress() public prankExecAsDeployer {
        vm.expectRevert("ERC1155: mint to the zero address");
        fraktionTokens.mint(address(0), 1312, 1);
    }
}
