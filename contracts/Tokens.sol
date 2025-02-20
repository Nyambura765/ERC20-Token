// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
interface ICreatorTokenManager {
    function getTokenAddress() external view returns (address);
}

/**
 * @title CreatorTokenManager
 * @dev Smart contract for creators to mint, burn, and manage tier-based fungible tokens.
 */
contract CreatorTokenManager is Ownable   (msg.sender) {
    struct Tier {
        string name;       // Name of the tier (e.g., Bronze, Silver, Gold)
        uint256 supply;    // Maximum supply for the tier
        uint256 minted;    // Number of tokens minted for the tier
        uint256 price;     // Price per token in the tier (in wei)
    }

    // Mapping from creator address to token contract
    mapping(address => address) public creatorTokens;

    // Mapping from token contract to tier metadata
    mapping(address => mapping(uint256 => Tier)) public tokenTiers;

    // Event for token contract creation
    event TokenCreated(address indexed creator, address tokenAddress);

    // Event for tier added
    event TierAdded(address indexed token, uint256 tierId, string name, uint256 supply, uint256 price);

    // Event for minting tokens
    event TokensMinted(address indexed token, address indexed recipient, uint256 tierId, uint256 amount);

    // Event for burning tokens
    event TokensBurned(address indexed token, address indexed creator, uint256 amount);

    /**
     * @dev Create a new token contract for a creator.
     * @param name Name of the token.
     * @param symbol Symbol of the token.
     */
    function createToken(string memory name, string memory symbol) external {
        require(creatorTokens[msg.sender] == address(0), "Token already created");
        address newToken = address(new CreatorToken(name, symbol, msg.sender));
        creatorTokens[msg.sender] = newToken;
        emit TokenCreated(msg.sender, newToken);
    }

    /**
     * @dev Add a new tier for a creator's token.
     * @param token Address of the creator's token.
     * @param tierId ID of the tier.
     * @param name Name of the tier.
     * @param supply Maximum supply for the tier.
     * @param price Price per token in the tier.
     */
    function addTier(address token, uint256 tierId, string memory name, uint256 supply, uint256 price) external {
        require(creatorTokens[msg.sender] == token, "Not your token");
        require(tokenTiers[token][tierId].supply == 0, "Tier already exists");

        tokenTiers[token][tierId] = Tier({
            name: name,
            supply: supply,
            minted: 0,
            price: price
        });

        emit TierAdded(token, tierId, name, supply, price);
    }

    /**
     * @dev Mint tokens for a specific tier.
     * @param token Address of the creator's token.
     * @param tierId ID of the tier.
     * @param amount Number of tokens to mint.
     * @param recipient Address to receive the tokens.
     */
    function mintTokens(address token, uint256 tierId, uint256 amount, address recipient) external payable {
        require(creatorTokens[msg.sender] == token, "Not your token");
        Tier storage tier = tokenTiers[token][tierId];
        require(tier.supply > 0, "Tier does not exist");
        require(tier.minted + amount <= tier.supply, "Exceeds tier supply");
        require(msg.value >= tier.price * amount, "Insufficient payment");

        tier.minted += amount;
        CreatorToken(token).mint(recipient, amount);

        emit TokensMinted(token, recipient, tierId, amount);
    }

    /**
     * @dev Burn tokens from the creator's token contract.
     * @param token Address of the creator's token.
     * @param amount Number of tokens to burn.
     */
    function burnTokens(address token, uint256 amount) external {
        require(creatorTokens[msg.sender] == token, "Not your token");
        CreatorToken(token).burn(msg.sender, amount);
        emit TokensBurned(token, msg.sender, amount);
    }
}

/**
 * @title CreatorToken
 * @dev ERC20 token contract for individual creators.
 */
contract CreatorToken is ERC20 {
    address public creator;

    modifier onlyCreator() {
        require(msg.sender == creator, "Not the creator");
        _;
    }

    constructor(string memory name, string memory symbol, address _creator) ERC20(name, symbol) {
        creator = _creator;
    }

    function mint(address to, uint256 amount) external onlyCreator {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external onlyCreator {
        _burn(from, amount);
    }
}
