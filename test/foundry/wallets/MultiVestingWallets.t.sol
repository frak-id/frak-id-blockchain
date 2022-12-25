// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.17;

import "@frak/tokens/FrakTokenL2.sol";
import "@frak/utils/FrakMath.sol";
import "@frak/wallets/MultiVestingWallets.sol";
import "forge-std/console.sol";
import { ProxyTester } from "@foundry-upgrades/ProxyTester.sol";
import { PRBTest } from "@prb/test/PRBTest.sol";
import { UUPSTestHelper } from "../UUPSTestHelper.sol";

/// Testing the frak l2 token
contract MultiVestingWalletsTest is UUPSTestHelper {
    using FrakMath for address;
    using FrakMath for uint256;

    FrakToken frakToken;
    MultiVestingWallets vestingWallets;

    function setUp() public {
        // Deploy frak token
        address frkProxyAddr = deployContract(address(new FrakToken()));
        frakToken = FrakToken(frkProxyAddr);
        prankDeployer();
        frakToken.initialize(address(this));

        // Deploy our multi vesting wallets
        address multiVestingAddr = deployContract(address(new MultiVestingWallets()));
        vestingWallets = MultiVestingWallets(multiVestingAddr);
        prankDeployer();
        vestingWallets.initialize(address(frakToken));
    }

    /*
     * ===== TEST : initialize(address tokenAddr) =====
     */
    function testFailInitTwice() public {
        vestingWallets.initialize(address(0));
    }

    /*
     * ===== TEST : name() =====
     */
    function testName() public {
        assertEq(vestingWallets.name(), "Vested FRK Token");
    }

    /*
     * ===== TEST : decimals() =====
     */
    function testDecimals() public {
        assertEq(vestingWallets.decimals(), 18);
    }

    /*
     * ===== TEST : symbol() =====
     */
    function testSymbol() public {
        assertEq(vestingWallets.symbol(), "vFRK");
    }

    /*
     * ===== TEST : availableReserve() =====
     */
    function testAvailableReserve() public {
        assertEq(vestingWallets.availableReserve(), 0);
        prankDeployer();
        frakToken.mint(address(vestingWallets), 1);
        assertEq(vestingWallets.availableReserve(), 1);
        assertEq(vestingWallets.availableReserve(), frakToken.balanceOf(address(vestingWallets)));
    }

    /*
     * ===== TEST : transferAvailableReserve(address receiver) =====
     */
    function testTransferAvailableReserve() public withFrkToken {
        // Ask to transfer the available reserve
        prankDeployer();
        vestingWallets.transferAvailableReserve(address(1));
        assertEq(vestingWallets.availableReserve(), 0);
        assertEq(frakToken.balanceOf(address(1)), 10);
    }

    function testFailTransferAvailableReserveNotAdmin() public withFrkToken {
        // Ask to transfer the available reserve
        vestingWallets.transferAvailableReserve(address(1));
    }

    function testFailTransferAvailableReserveContractPaused() public withFrkToken {
        prankDeployer();
        vestingWallets.pause();

        // Ask to transfer the available reserve
        vestingWallets.transferAvailableReserve(address(1));
    }

    function testFailTransferAvailableReserveNoReserve() public {
        // Ask to transfer the available reserve
        prankDeployer();
        vestingWallets.transferAvailableReserve(address(1));
    }

    /*
     * ===== TEST : createVest(
        address beneficiary,
        uint256 amount,
        uint32 duration,
        uint48 startDate
    ) =====
     */
    function testCreateVest() public withFrkToken {
        // Ask to transfer the available reserve
        prankDeployer();
        vestingWallets.createVest(address(1), 10, 10, uint48(block.timestamp + 1));
        assertEq(vestingWallets.balanceOf(address(1)), 10);
    }

    function testFailCreateVestNotManager() public withFrkToken {
        vestingWallets.createVest(address(1), 10, 10, uint48(block.timestamp + 1));
    }

    function testFailCreateVestPaused() public withFrkToken prankExecAsDeployer {
        vestingWallets.pause();
        vestingWallets.createVest(address(1), 10, 10, uint48(block.timestamp + 1));
    }

    function testFailCreateVestInvalidDuration() public withFrkToken {
        vestingWallets.createVest(address(1), 10, 0, uint48(block.timestamp + 1));
    }

    function testFailCreateVestInvalidStartDate() public withFrkToken {
        vestingWallets.createVest(address(1), 10, 10, uint48(block.timestamp));
    }

    function testFailCreateVestNotEnoughReserve() public withFrkToken {
        vestingWallets.createVest(address(1), 11, 10, uint48(block.timestamp + 1));
    }

    function testFailCreateVestInvalidAddress() public withFrkToken {
        vestingWallets.createVest(address(0), 10, 10, uint48(block.timestamp + 1));
    }

    function testFailCreateVestInvalidReward() public withFrkToken {
        vestingWallets.createVest(address(10), 0, 10, uint48(block.timestamp + 1));
    }

    function testFailCreateVestTooLargeReward() public withLotFrkToken {
        vestingWallets.createVest(address(10), 200_000_001 ether, 10, uint48(block.timestamp + 1));
    }

    /*
     * ===== createVestBatch(
        address[] calldata beneficiaries,
        uint256[] calldata amounts,
        uint32 duration,
        uint48 startDate
    ) =====
     */
    function testCreateVestBatch() public withFrkToken {
        // Ask to transfer the available reserve
        prankDeployer();
        vestingWallets.createVestBatch(
            address(1).asSingletonArray(),
            uint256(10).asSingletonArray(),
            10,
            uint48(block.timestamp + 1)
        );
        assertEq(vestingWallets.balanceOf(address(1)), 10);
    }

    function testFailCreateVestBatchNotManager() public withFrkToken {
        vestingWallets.createVestBatch(
            address(1).asSingletonArray(),
            uint256(10).asSingletonArray(),
            10,
            uint48(block.timestamp + 1)
        );
    }

    function testFailCreateVestBatchPaused() public withFrkToken prankExecAsDeployer {
        vestingWallets.pause();
        vestingWallets.createVestBatch(
            address(1).asSingletonArray(),
            uint256(10).asSingletonArray(),
            10,
            uint48(block.timestamp + 1)
        );
    }

    function testFailCreateVestBatchNotEnoughReserve() public withFrkToken prankExecAsDeployer {
        vestingWallets.createVestBatch(
            address(1).asSingletonArray(),
            uint256(11).asSingletonArray(),
            10,
            uint48(block.timestamp + 1)
        );
    }

    function testFailCreateVestBatchEmptyArray() public withFrkToken {
        address[] memory addresses = new address[](0);
        uint256[] memory amounts = new uint256[](0);
        prankDeployer();
        vestingWallets.createVestBatch(
            addresses,
            amounts,
            10,
            uint48(block.timestamp + 1)
        );
    }

    function testFailCreateVestBatchArrayInvalidLength() public withFrkToken {
        address[] memory addresses = new address[](0);
        prankDeployer();
        vestingWallets.createVestBatch(
            addresses,
            uint256(10).asSingletonArray(),
            10,
            uint48(block.timestamp + 1)
        );
    }

    /*
     * ===== UTILS=====
     */

    modifier withFrkToken() {
        prankDeployer();
        frakToken.mint(address(vestingWallets), 10);
        _;
    }

    modifier withLotFrkToken() {
        prankDeployer();
        frakToken.mint(address(vestingWallets), 500_000_000 ether);
        _;
    }
}
