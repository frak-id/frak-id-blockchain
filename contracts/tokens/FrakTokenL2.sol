// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.17;

import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {FrakRoles} from "../utils/FrakRoles.sol";
import {MintingAccessControlUpgradeable} from "../utils/MintingAccessControlUpgradeable.sol";
import {ContextMixin} from "../utils/ContextMixin.sol";
import {NativeMetaTransaction} from "../utils/NativeMetaTransaction.sol";

/**
 * @author  @KONFeature
 * @title   FrakToken
 * @dev  ERC20 Contract for the FRAK token
 * @notice Compliant with ERC20 - EIP712 - EIP2612
 * @custom:security-contact contact@frak.id
 */
contract FrakToken is ERC20Upgradeable, MintingAccessControlUpgradeable, NativeMetaTransaction, ContextMixin {
    /* -------------------------------------------------------------------------- */
    /*                                 Constant's                                 */
    /* -------------------------------------------------------------------------- */

    /// @dev Role used by the polygon bridge to bridge token between L1 <-> L2
    bytes32 internal constant DEPOSITOR_ROLE = keccak256("DEPOSITOR_ROLE");

    /// @dev Maximum cap of token, at 3 billion FRK
    uint256 private constant _cap = 3_000_000_000 ether;

    /* -------------------------------------------------------------------------- */
    /*                               Custom error's                               */
    /* -------------------------------------------------------------------------- */

    /// @dev error throwned when the contract cap is exceeded
    error CapExceed();

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /* -------------------------------------------------------------------------- */
    /*                          External write function's                         */
    /* -------------------------------------------------------------------------- */

    function initialize(address childChainManager) external initializer {
        string memory name = "Frak";
        __ERC20_init(name, "FRK");
        __MintingAccessControlUpgradeable_init();
        _initializeEIP712(name);

        _grantRole(DEPOSITOR_ROLE, childChainManager);
    }

    // This is to support Native meta transactions
    // never use msg.sender directly, use _msgSender() instead
    function _msgSender() internal view override returns (address sender) {
        return ContextMixin.msgSender();
    }

    /// @dev Mint some FRK
    function mint(address to, uint256 amount) external onlyRole(FrakRoles.MINTER) whenNotPaused {
        if (totalSupply() + amount > _cap) revert CapExceed();
        _mint(to, amount);
    }

    /// @dev Burn some FRK
    function burn(uint256 amount) external whenNotPaused {
        _burn(_msgSender(), amount);
    }

    /// @dev Returns the cap on the token's total supply.
    function cap() external view virtual returns (uint256) {
        return _cap;
    }

    /* -------------------------------------------------------------------------- */
    /*                External write function's for Polygon bridge                */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice called when token is deposited on root chain
     * @dev Should be callable only by ChildChainManager
     * Should handle deposit by minting the required amount for user
     * @param user user address for whom deposit is being done
     * @param depositData abi encoded amount (required for polygon bridge)
     */
    function deposit(address user, bytes calldata depositData) external onlyRole(DEPOSITOR_ROLE) {
        uint256 amount = abi.decode(depositData, (uint256));
        if (totalSupply() + amount > _cap) revert CapExceed();
        _mint(user, amount);
    }

    /**
     * @notice called when user wants to withdraw tokens back to root chain
     * @dev Should burn user's tokens. This transaction will be verified when exiting on root chain
     * @param amount amount of tokens to withdraw
     */
    function withdraw(uint256 amount) external {
        _burn(_msgSender(), amount);
    }
}
