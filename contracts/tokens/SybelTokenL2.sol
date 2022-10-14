// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "../utils/SybelRoles.sol";
import "../utils/MintingAccessControlUpgradeable.sol";
import "../utils/ContextMixin.sol";
import "../utils/NativeMetaTransaction.sol";

/**
 * Sybel token used on polygon L2
 */
/// @custom:security-contact crypto-support@sybel.co
contract SybelToken is ERC20Upgradeable, MintingAccessControlUpgradeable, NativeMetaTransaction, ContextMixin {
    bytes32 public constant DEPOSITOR_ROLE = keccak256("DEPOSITOR_ROLE");

    uint256 private _cap;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address childChainManager) external initializer {
        string memory name = "Sybel Token";
        __ERC20_init(name, "SYBL");
        __MintingAccessControlUpgradeable_init();
        _initializeEIP712(name);

        _grantRole(DEPOSITOR_ROLE, childChainManager);

        _cap = 3_000_000_000 ether; // 3 billion SYBL
    }

    // This is to support Native meta transactions
    // never use msg.sender directly, use _msgSender() instead
    function _msgSender() internal view override returns (address sender) {
        return ContextMixin.msgSender();
    }

    /**
     * @dev Mint some SYBL
     */
    function mint(address to, uint256 amount) external onlyRole(SybelRoles.MINTER) {
        require(totalSupply() + amount <= cap(), "ERC20Capped: cap exceeded");
        _mint(to, amount);
    }

    /**
     * @dev Burn some SYBL
     */
    function burn(uint256 amount) external {
        _burn(_msgSender(), amount);
    }

    /**
     * @dev Ensure the contract isn't paused before the transfer
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override whenNotPaused {
        super._beforeTokenTransfer(from, to, amount);
    }

    /**
     * @dev Returns the cap on the token's total supply.
     */
    function cap() public view virtual returns (uint256) {
        return _cap;
    }

    /**
     * @notice called when token is deposited on root chain
     * @dev Should be callable only by ChildChainManager
     * Should handle deposit by minting the required amount for user
     * Make sure minting is done only by this function
     * @param user user address for whom deposit is being done
     * @param depositData abi encoded amount
     */
    function deposit(address user, bytes calldata depositData) external whenNotPaused onlyRole(DEPOSITOR_ROLE) {
        uint256 amount = abi.decode(depositData, (uint256));
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
