// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

/**
 * @title KYCRegistry
 * @dev Contract to manage KYC-verified investors using a role-based system
 */
contract KYCRegistry is AccessControl {
    // Create roles
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant VERIFIER_ROLE = keccak256("VERIFIER_ROLE");
    
    // Mapping to track KYC status
    mapping(address => bool) private _kycVerified;
    
    // Events
    event InvestorVerified(address indexed investor, address indexed verifier);
    event InvestorRevoked(address indexed investor, address indexed verifier);
    
    constructor() {
        // Setup roles
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(VERIFIER_ROLE, msg.sender);
    }
    
    /**
     * @dev Check if an investor is KYC-verified
     * @param investor Address of the investor to check
     * @return True if the investor is KYC-verified, false otherwise
     */
    function isVerified(address investor) external view returns (bool) {
        return _kycVerified[investor];
    }
    
    /**
     * @dev Add an investor to the KYC-verified list
     * @param investor Address of the investor to add
     */
    function verifyInvestor(address investor) external onlyRole(VERIFIER_ROLE) {
        require(investor != address(0), "Invalid investor address");
        require(!_kycVerified[investor], "Investor already verified");
        
        _kycVerified[investor] = true;
        emit InvestorVerified(investor, msg.sender);
    }
    
    /**
     * @dev Add multiple investors to the KYC-verified list
     * @param investors Array of investor addresses to add
     */
    function batchVerifyInvestors(address[] calldata investors) external onlyRole(VERIFIER_ROLE) {
        for (uint256 i = 0; i < investors.length; i++) {
            address investor = investors[i];
            if (investor != address(0) && !_kycVerified[investor]) {
                _kycVerified[investor] = true;
                emit InvestorVerified(investor, msg.sender);
            }
        }
    }
    
    /**
     * @dev Remove an investor from the KYC-verified list
     * @param investor Address of the investor to remove
     */
    function revokeInvestor(address investor) external onlyRole(VERIFIER_ROLE) {
        require(_kycVerified[investor], "Investor not verified");
        
        _kycVerified[investor] = false;
        emit InvestorRevoked(investor, msg.sender);
    }
    
    /**
     * @dev Add a new verifier
     * @param verifier Address of the new verifier
     */
    function addVerifier(address verifier) external onlyRole(ADMIN_ROLE) {
        grantRole(VERIFIER_ROLE, verifier);
    }
    
    /**
     * @dev Remove a verifier
     * @param verifier Address of the verifier to remove
     */
    function removeVerifier(address verifier) external onlyRole(ADMIN_ROLE) {
        revokeRole(VERIFIER_ROLE, verifier);
    }
}

/**
 * @title RestrictedRealEstateToken
 * @dev ERC20 token representing fractional ownership of a real estate property
 * with transfer restrictions based on KYC verification
 */
contract RestrictedRealEstateToken is ERC20, Ownable {
    // Property details
    struct PropertyDetails {
        string propertyId;          // Unique identifier for the property
        string location;            // Physical location of the property
        uint256 totalValuation;     // Total valuation of the property in wei
        string propertyType;        // Type of property (residential, commercial, etc.)
        string legalDocumentHash;   // IPFS hash of legal documents
        uint256 creationTimestamp;  // When the property was tokenized
    }
    
    PropertyDetails public propertyDetails;
    
    // KYC Registry contract reference
    KYCRegistry public kycRegistry;
    
    // Events
    event PropertyTokenized(string propertyId, uint256 totalSupply, uint256 totalValuation);
    event TokensBurned(address indexed account, uint256 amount);
    event KYCRegistryUpdated(address indexed oldRegistry, address indexed newRegistry);
    
    /**
     * @dev Constructor to create a new tokenized property
     * @param _propertyId Unique identifier for the property
     * @param _location Physical location of the property
     * @param _totalValuation Total valuation of the property in wei
     * @param _propertyType Type of property (residential, commercial, etc.)
     * @param _legalDocumentHash IPFS hash of legal documents
     * @param _tokenName Name of the token
     * @param _tokenSymbol Symbol of the token
     * @param _totalSupply Total number of tokens to be minted
     * @param _kycRegistry Address of the KYC registry contract
     */
    constructor(
        string memory _propertyId,
        string memory _location,
        uint256 _totalValuation,
        string memory _propertyType,
        string memory _legalDocumentHash,
        string memory _tokenName,
        string memory _tokenSymbol,
        uint256 _totalSupply,
        address _kycRegistry
    ) ERC20(_tokenName, _tokenSymbol) Ownable(msg.sender) {
        require(bytes(_propertyId).length > 0, "Property ID cannot be empty");
        require(_totalValuation > 0, "Property valuation must be greater than 0");
        require(_totalSupply > 0, "Total supply must be greater than 0");
        require(_kycRegistry != address(0), "KYC registry address cannot be zero");
        
        propertyDetails = PropertyDetails({
            propertyId: _propertyId,
            location: _location,
            totalValuation: _totalValuation,
            propertyType: _propertyType,
            legalDocumentHash: _legalDocumentHash,
            creationTimestamp: block.timestamp
        });
        
        kycRegistry = KYCRegistry(_kycRegistry);
        
        // Mint the total supply to the contract creator
        _mint(msg.sender, _totalSupply);
        
        emit PropertyTokenized(_propertyId, _totalSupply, _totalValuation);
    }
    
    /**
     * @dev Override the transfer function to add KYC check
     * @param to Recipient address
     * @param value Amount to transfer
     * @return True if the transfer was successful
     */
    function transfer(address to, uint256 value) public override returns (bool) {
        _checkKYC(msg.sender, to);
        return super.transfer(to, value);
    }
    
    /**
     * @dev Override the transferFrom function to add KYC check
     * @param from Sender address
     * @param to Recipient address
     * @param value Amount to transfer
     * @return True if the transfer was successful
     */
    function transferFrom(address from, address to, uint256 value) public override returns (bool) {
        _checkKYC(from, to);
        return super.transferFrom(from, to, value);
    }
    
    /**
     * @dev Internal function to check if both sender and recipient are KYC-verified
     * @param from Sender address
     * @param to Recipient address
     */
    function _checkKYC(address from, address to) internal view {
        require(kycRegistry.isVerified(from), "Sender is not KYC-verified");
        require(kycRegistry.isVerified(to), "Recipient is not KYC-verified");
    }
    
    /**
     * @dev Update the KYC registry contract address
     * @param _newKycRegistry Address of the new KYC registry contract
     */
    function updateKYCRegistry(address _newKycRegistry) external onlyOwner {
        require(_newKycRegistry != address(0), "New KYC registry address cannot be zero");
        
        address oldRegistry = address(kycRegistry);
        kycRegistry = KYCRegistry(_newKycRegistry);
        
        emit KYCRegistryUpdated(oldRegistry, _newKycRegistry);
    }
    
    /**
     * @dev Get token value based on current property valuation
     * @return Value of a single token in wei
     */
    function getTokenValue() public view returns (uint256) {
        return propertyDetails.totalValuation / totalSupply();
    }
    
    /**
     * @dev Update the property valuation
     * @param _newValuation New valuation of the property in wei
     */
    function updateValuation(uint256 _newValuation) external onlyOwner {
        require(_newValuation > 0, "New valuation must be greater than 0");
        propertyDetails.totalValuation = _newValuation;
    }
    
    /**
     * @dev Update the legal document hash
     * @param _newLegalDocumentHash New IPFS hash of legal documents
     */
    function updateLegalDocumentHash(string memory _newLegalDocumentHash) external onlyOwner {
        propertyDetails.legalDocumentHash = _newLegalDocumentHash;
    }
    
    /**
     * @dev Burns tokens from the specified account (can only be done by owner)
     * @param account Address from which tokens will be burned
     * @param amount Amount of tokens to burn
     */
    function burnFrom(address account, uint256 amount) external onlyOwner {
        _burn(account, amount);
        emit TokensBurned(account, amount);
    }
    
    /**
     * @dev Returns property information as a string
     * @return Property details as a formatted string
     */
    function getPropertyInfo() external view returns (string memory) {
        return string(abi.encodePacked(
            "Property ID: ", propertyDetails.propertyId, "\n",
            "Location: ", propertyDetails.location, "\n",
            "Type: ", propertyDetails.propertyType, "\n",
            "Valuation: ", Strings.toString(propertyDetails.totalValuation), "\n",
            "Token Value: ", Strings.toString(getTokenValue()), "\n",
            "Legal Document Hash: ", propertyDetails.legalDocumentHash, "\n",
            "Tokenized on: ", Strings.toString(propertyDetails.creationTimestamp)
        ));
    }
}

/**
 * @title RestrictedPropertyTokenFactory
 * @dev Factory contract to create new tokenized properties with KYC restrictions
 */
contract RestrictedPropertyTokenFactory is Ownable, AccessControl {
    // Role for multisig administrators
    bytes32 public constant MULTISIG_ADMIN_ROLE = keccak256("MULTISIG_ADMIN_ROLE");
    
    // Array to keep track of all tokenized properties
    address[] public tokenizedProperties;
    
    // Mapping from property ID to token address
    mapping(string => address) public propertyTokens;
    
    // KYC Registry contract
    KYCRegistry public kycRegistry;
    
    // Threshold for multisig operations
    uint256 public requiredSignatures;
    
    // Counter for operation IDs
    uint256 private _operationCounter;
    
    // Mapping from operation ID to signatures
    mapping(uint256 => mapping(address => bool)) private _signatures;
    
    // Mapping from operation ID to signature count
    mapping(uint256 => uint256) private _signatureCount;
    
    // Mapping from operation ID to operation details
    mapping(uint256 => bytes32) private _operationDetails;
    
    // Array to track admin addresses
    address[] private _admins;
    
    // Events
    event PropertyTokenCreated(string propertyId, address tokenAddress);
    event MultisigOperationCreated(uint256 operationId, bytes32 operationDetails);
    event MultisigOperationSigned(uint256 operationId, address signer);
    event MultisigOperationExecuted(uint256 operationId, bytes32 operationDetails);
    event RequiredSignaturesUpdated(uint256 oldValue, uint256 newValue);
    event KYCRegistryUpdated(address indexed oldRegistry, address indexed newRegistry);
    event AdminAdded(address indexed admin);
    event AdminRemoved(address indexed admin);
    
    /**
     * @dev Constructor to create the factory with a new KYC registry
     * @param _initialAdmins Array of initial multisig administrators
     * @param _requiredSignatures Number of signatures required for multisig operations
     */
    constructor(address[] memory _initialAdmins, uint256 _requiredSignatures) Ownable(msg.sender) {
        require(_initialAdmins.length > 0, "Initial admins required");
        require(_requiredSignatures > 0 && _requiredSignatures <= _initialAdmins.length, 
                "Invalid number of required signatures");
        
        // Setup roles
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        
        // Create new KYC registry
        kycRegistry = new KYCRegistry();
        
        requiredSignatures = _requiredSignatures;
        
        // Grant admin and verifier roles to all initial admins
        for (uint256 i = 0; i < _initialAdmins.length; i++) {
            _grantRole(MULTISIG_ADMIN_ROLE, _initialAdmins[i]);
            _admins.push(_initialAdmins[i]);
            emit AdminAdded(_initialAdmins[i]);
        }
    }
    
    /**
     * @dev Create a new tokenized property with KYC restrictions
     * @param _propertyId Unique identifier for the property
     * @param _location Physical location of the property
     * @param _totalValuation Total valuation of the property in wei
     * @param _propertyType Type of property (residential, commercial, etc.)
     * @param _legalDocumentHash IPFS hash of legal documents
     * @param _tokenName Name of the token
     * @param _tokenSymbol Symbol of the token
     * @param _totalSupply Total number of tokens to be minted
     * @return Address of the newly created token contract
     */
    function createPropertyToken(
        string memory _propertyId,
        string memory _location,
        uint256 _totalValuation,
        string memory _propertyType,
        string memory _legalDocumentHash,
        string memory _tokenName,
        string memory _tokenSymbol,
        uint256 _totalSupply
    ) external onlyOwner returns (address) {
        require(propertyTokens[_propertyId] == address(0), "Property already tokenized");
        
        RestrictedRealEstateToken newToken = new RestrictedRealEstateToken(
            _propertyId,
            _location,
            _totalValuation,
            _propertyType,
            _legalDocumentHash,
            _tokenName,
            _tokenSymbol,
            _totalSupply,
            address(kycRegistry)
        );
        
        address tokenAddress = address(newToken);
        
        // Transfer ownership to the msg.sender
        newToken.transferOwnership(msg.sender);
        
        // Store the token address
        tokenizedProperties.push(tokenAddress);
        propertyTokens[_propertyId] = tokenAddress;
        
        emit PropertyTokenCreated(_propertyId, tokenAddress);
        
        return tokenAddress;
    }
    
    /**
     * @dev Get the number of admins
     * @return Count of admins with MULTISIG_ADMIN_ROLE
     */
    function getAdminCount() public view returns (uint256) {
        return _admins.length;
    }
    
    /**
     * @dev Get admin at specific index
     * @param index Index in the admins array
     * @return Admin address
     */
    function getAdminAtIndex(uint256 index) external view returns (address) {
        require(index < _admins.length, "Index out of bounds");
        return _admins[index];
    }
    
    /**
     * @dev Check if an address is an admin
     * @param admin Address to check
     * @return True if the address is an admin
     */
    function isAdmin(address admin) public view returns (bool) {
        return hasRole(MULTISIG_ADMIN_ROLE, admin);
    }
    
    /**
     * @dev Propose adding an investor to the KYC-verified list (multisig)
     * @param investor Address of the investor to add
     * @return Operation ID
     */
    function proposeVerifyInvestor(address investor) external onlyRole(MULTISIG_ADMIN_ROLE) returns (uint256) {
        require(investor != address(0), "Invalid investor address");
        
        bytes32 operationDetails = keccak256(abi.encodePacked("verifyInvestor", investor));
        uint256 operationId = _createOperation(operationDetails);
        
        return operationId;
    }
    
    /**
     * @dev Propose removing an investor from the KYC-verified list (multisig)
     * @param investor Address of the investor to remove
     * @return Operation ID
     */
    function proposeRevokeInvestor(address investor) external onlyRole(MULTISIG_ADMIN_ROLE) returns (uint256) {
        require(investor != address(0), "Invalid investor address");
        
        bytes32 operationDetails = keccak256(abi.encodePacked("revokeInvestor", investor));
        uint256 operationId = _createOperation(operationDetails);
        
        return operationId;
    }
    
    /**
     * @dev Sign an operation (multisig)
     * @param operationId ID of the operation to sign
     */
    function signOperation(uint256 operationId) external onlyRole(MULTISIG_ADMIN_ROLE) {
        require(_operationDetails[operationId] != bytes32(0), "Invalid operation ID");
        require(!_signatures[operationId][msg.sender], "Already signed");
        
        _signatures[operationId][msg.sender] = true;
        _signatureCount[operationId]++;
        
        emit MultisigOperationSigned(operationId, msg.sender);
        
        // Execute operation if enough signatures
        if (_signatureCount[operationId] >= requiredSignatures) {
            _executeOperation(operationId);
        }
    }
    
    /**
     * @dev Create a new operation (internal)
     * @param operationDetails Details of the operation (hashed)
     * @return Operation ID
     */
    function _createOperation(bytes32 operationDetails) internal returns (uint256) {
        uint256 operationId = _operationCounter++;
        _operationDetails[operationId] = operationDetails;
        
        // Auto-sign by creator
        _signatures[operationId][msg.sender] = true;
        _signatureCount[operationId] = 1;
        
        emit MultisigOperationCreated(operationId, operationDetails);
        emit MultisigOperationSigned(operationId, msg.sender);
        
        return operationId;
    }
    
    /**
     * @dev Execute an operation (internal)
     * @param operationId ID of the operation to execute
     */
    function _executeOperation(uint256 operationId) internal {
        bytes32 operationDetails = _operationDetails[operationId];
        
        // Extract operation type and parameters
        bytes32 operationType = bytes32(uint256(operationDetails) & 0xFFFFFFFF00000000000000000000000000000000000000000000000000000000);
        address param = address(uint160(uint256(operationDetails) & 0x00000000FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF));
        
        // Execute operation based on type
        if (operationType == keccak256(abi.encodePacked("verifyInvestor"))) {
            kycRegistry.verifyInvestor(param);
        } else if (operationType == keccak256(abi.encodePacked("revokeInvestor"))) {
            kycRegistry.revokeInvestor(param);
        }
        
        emit MultisigOperationExecuted(operationId, operationDetails);
    }
    
    /**
     * @dev Update the required number of signatures for multisig operations
     * @param _newRequiredSignatures New required number of signatures
     */
    function updateRequiredSignatures(uint256 _newRequiredSignatures) external onlyOwner {
        require(_newRequiredSignatures > 0, "Required signatures must be greater than 0");
        
        // Get admin count using our custom function
        uint256 adminCount = getAdminCount();
        require(_newRequiredSignatures <= adminCount, "Required signatures exceed admin count");
        
        uint256 oldValue = requiredSignatures;
        requiredSignatures = _newRequiredSignatures;
        
        emit RequiredSignaturesUpdated(oldValue, _newRequiredSignatures);
    }
    
    /**
     * @dev Add a new multisig admin
     * @param admin Address of the new admin
     */
    function addMultisigAdmin(address admin) external onlyOwner {
        require(!isAdmin(admin), "Address is already an admin");
        
        grantRole(MULTISIG_ADMIN_ROLE, admin);
        _admins.push(admin);
        
        emit AdminAdded(admin);
    }
    
    /**
     * @dev Remove a multisig admin
     * @param admin Address of the admin to remove
     */
    function removeMultisigAdmin(address admin) external onlyOwner {
        require(isAdmin(admin), "Address is not an admin");
        
        // Remove from role
        revokeRole(MULTISIG_ADMIN_ROLE, admin);
        
        // Remove from array
        for (uint256 i = 0; i < _admins.length; i++) {
            if (_admins[i] == admin) {
                // Replace with the last element and pop
                _admins[i] = _admins[_admins.length - 1];
                _admins.pop();
                break;
            }
        }
        
        emit AdminRemoved(admin);
        
        // Ensure requiredSignatures is not greater than admin count
        uint256 adminCount = getAdminCount();
        if (requiredSignatures > adminCount && adminCount > 0) {
            uint256 oldValue = requiredSignatures;
            requiredSignatures = adminCount;
            emit RequiredSignaturesUpdated(oldValue, adminCount);
        }
    }
    
    /**
     * @dev Update the KYC registry contract
     * @param _newKycRegistry Address of the new KYC registry contract
     */
    function updateKYCRegistry(address _newKycRegistry) external onlyOwner {
        require(_newKycRegistry != address(0), "New KYC registry address cannot be zero");
        
        address oldRegistry = address(kycRegistry);
        kycRegistry = KYCRegistry(_newKycRegistry);
        
        emit KYCRegistryUpdated(oldRegistry, _newKycRegistry);
    }
    
    /**
     * @dev Get the number of tokenized properties
     * @return Number of tokenized properties
     */
    function getTokenizedPropertiesCount() external view returns (uint256) {
        return tokenizedProperties.length;
    }
    
    /**
     * @dev Get token address by property ID
     * @param _propertyId Unique identifier for the property
     * @return Address of the token contract
     */
    function getTokenAddressByPropertyId(string memory _propertyId) external view returns (address) {
        return propertyTokens[_propertyId];
    }
    
    /**
     * @dev Get operation signature count
     * @param operationId Operation ID
     * @return Number of signatures for the operation
     */
    function getOperationSignatureCount(uint256 operationId) external view returns (uint256) {
        return _signatureCount[operationId];
    }
    
    /**
     * @dev Check if an admin has signed an operation
     * @param operationId Operation ID
     * @param admin Admin address
     * @return True if the admin has signed the operation
     */
    function hasSignedOperation(uint256 operationId, address admin) external view returns (bool) {
        return _signatures[operationId][admin];
    }
}
