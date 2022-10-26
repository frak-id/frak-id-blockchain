// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "../utils/SybelRoles.sol";
import "../utils/MintingAccessControlUpgradeable.sol";
import "../utils/ContextMixin.sol";
import "../utils/NativeMetaTransaction.sol";

// Error
/// @dev error throwned when the contract cap is exceeded
error CapExceed();

/**
 * Sybel token used on polygon L2
 */
/// @custom:security-contact crypto-support@sybel.co
contract SybelToken is ERC20Upgradeable, MintingAccessControlUpgradeable, NativeMetaTransaction, ContextMixin {
    bytes32 internal constant DEPOSITOR_ROLE = keccak256("DEPOSITOR_ROLE");

    uint256 private constant _cap = 3_000_000_000 ether; // 3 billion SYBL

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

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

    /**
     * @dev Mint some SYBL
     */
    function mint(address to, uint256 amount) external onlyRole(SybelRoles.MINTER) whenNotPaused {
        if (totalSupply() + amount > _cap) revert CapExceed();
        _mint(to, amount);
    }

    /**
     * @dev Mint some SYBL in a batch manner
     */
    function mintBatch(address[3] calldata tos, uint256[3] calldata amounts)
        external
        onlyRole(SybelRoles.MINTER)
        whenNotPaused
    {
        for (uint256 i; i < tos.length; ) {
            // Ensure we don't exceed the cap
            if (totalSupply() + amounts[i] > _cap) revert CapExceed();

            // Mint
            _mint(tos[i], amounts[i]);

            // Increment counter
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @dev Burn some SYBL
     */
    function burn(uint256 amount) external whenNotPaused {
        _burn(_msgSender(), amount);
    }

    /**
     * @dev Returns the cap on the token's total supply.
     */
    function cap() external view virtual returns (uint256) {
        return _cap;
    }

    /**
     * @notice called when token is deposited on root chain
     * @dev Should be callable only by ChildChainManager
     * Should handle deposit by minting the required amount for user
     * @param user user address for whom deposit is being done
     * @param depositData abi encoded amount (required for polygon bridge)
     */
    function deposit(address user, bytes calldata depositData) external onlyRole(DEPOSITOR_ROLE) whenNotPaused {
        uint256 amount = abi.decode(depositData, (uint256));
        if (totalSupply() + amount > _cap) revert CapExceed();
        _mint(user, amount);
    }

    /**
     * @notice called when user wants to withdraw tokens back to root chain
     * @dev Should burn user's tokens. This transaction will be verified when exiting on root chain
     * @param amount amount of tokens to withdraw
     */
    function withdraw(uint256 amount) external whenNotPaused {
        _burn(_msgSender(), amount);
    }
}
