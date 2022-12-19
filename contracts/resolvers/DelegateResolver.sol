//SPDX-License-Identifier: MIT
pragma solidity >=0.8.17 <0.9.0;

import "../registry/ENS.sol";
import "./profiles/ABIResolver.sol";
import "./profiles/AddrResolver.sol";
import "./profiles/ContentHashResolver.sol";
import "./profiles/DNSResolver.sol";
import "./profiles/InterfaceResolver.sol";
import "./profiles/NameResolver.sol";
import "./profiles/PubkeyResolver.sol";
import "./profiles/TextResolver.sol";
import "./profiles/PermaRecordResolver.sol";
import "./Multicallable.sol";

interface INameWrapper {
    function ownerOf(uint256 id) external view returns (address);
}

/**
 * A simple resolver anyone can use; only allows the owner of a node or an approved operator to set its
 * address. Also it includes delegation and aliases includign overrides and defaults. 
 */
contract DelegateResolver is
    Multicallable,
    ABIResolver,
    AddrResolver,
    ContentHashResolver,
    DNSResolver,
    InterfaceResolver,
    NameResolver,
    PubkeyResolver,
    TextResolver,
    PermaRecordResolver
{
    ENS immutable ens;
    INameWrapper immutable nameWrapper;
    address immutable trustedETHController;
    address immutable trustedReverseRegistrar;

    uint256 private constant COIN_TYPE_ETH = 60;

    /**
     * A mapping of operators. An address that is authorised for an address
     * may make any changes to the name that the owner could, but may not update
     * the set of authorisations.
     * (owner, operator) => approved
     */
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    /**
     * A mapping of delegates. A delegate that is authorised by an owner
     * for a name may make changes to the name's resolver, but may not update
     * the set of delegations.
     * (owner, name, delegate) => approved
     */
    mapping(address => mapping(bytes32 => mapping(address => bool))) private _nameDelegations;

    /**
     * A mapping of name overrides. A name that has an override set will check to see if the overide has
     * a value set before resolving.      
     * (owner, name) => override
     */
    mapping(address => mapping(bytes32 => bytes32)) private _overrides;

    /**
     * A mapping of name defaults. A name that has a default set, if its own record is not set, will
     * fetch the record from the default name.      
     * (owner, name) => defalut
     */
    mapping(address => mapping(bytes32 => bytes32)) private _defaults;


    // Logged when an operator is added or removed.
    event ApprovalForAll(
        address owner,
        address operator,
        bool approved
    );

    // Logged when a delegate is added or removed.
    event Delegated(
        address indexed owner,
        bytes32 indexed node,
        address indexed delegate
    );

    // Logged when a override is added or removed.
    event Overridden(
        address owner,
        bytes32 node,
        bytes32 overrideNode
    );

    // Logged when a default is added or removed.
    event DefaultSet(
        address owner,
        bytes32 node,
        bytes32 defaultNode
    );

    constructor(
        ENS _ens,
        INameWrapper wrapperAddress,
        address _trustedETHController,
        address _trustedReverseRegistrar
    ) {
        ens = _ens;
        nameWrapper = wrapperAddress;
        trustedETHController = _trustedETHController;
        trustedReverseRegistrar = _trustedReverseRegistrar;
    }

    /**
     * @dev See {IERC1155-setApprovalForAll}.
     */
    function setApprovalForAll(address operator, bool approved) external {
        require(
            msg.sender != operator,
            "ERC1155: setting approval status for self"
        );

        _operatorApprovals[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    /**
     * @dev See {IERC1155-isApprovedForAll}.
     */
    function isApprovedForAll(address account, address operator)
        public
        view
        returns (bool)
    {
        return _operatorApprovals[account][operator];
    }

    /**
     * @dev Set a delegation.
     */
    function SetDelegation(bytes32 node, address delegate) external {
        require(
            msg.sender != delegate,
            "Setting delegate status for self"
        );

        _nameDelegations[msg.sender][node][delegate] = true;
        emit Delegated(msg.sender, node, delegate);
    }

    /**
     * @dev Check to see if the delegate has been delegated to.
     */
    function isDelegatedTo(address owner, bytes32 node, address delegate)
        public
        view
        returns (bool)
    {
        return _nameDelegations[owner][node][delegate];
    }

    /**
     * @dev Set an override.
     */
    function SetOverride(bytes32 node, bytes32 overrideNode) external {

        _overrides[msg.sender][node] = overrideNode;
        emit Overridden(msg.sender, node, overrideNode);
    }

    /**
     * @dev Check to see if the name has been overridden.
     */
    function isOverridden(address owner, bytes32 node)
        public
        view
        returns (bool)
    {
        return _overrides[owner][node] > 0;
    }

    /**
     * @dev Set a defualt name.
     */
    function SetDefault(bytes32 node, bytes32 defaultNode) external {

        _defaults[msg.sender][node] = defaultNode;
        emit DefaultSet(msg.sender, node, defaultNode);
    }

    /**
     * @dev Check to see if the name has a default.
     */
    function isDefaultSet(address owner, bytes32 node)
        public
        view
        returns (bool)
    {
        return _defaults[owner][node] > 0;
    }

    function isAuthorised(bytes32 node) internal view override returns (bool) {
        if (
            msg.sender == trustedETHController ||
            msg.sender == trustedReverseRegistrar
        ) {
            return true;
        }
        address owner = ens.owner(node);
        if (owner == address(nameWrapper)) {
            owner = nameWrapper.ownerOf(uint256(node));
        }
        return owner == msg.sender || isApprovedForAll(owner, msg.sender) || 
            isDelegatedTo(owner, node, msg.sender);
    }
    
     /**
     * Returns the address associated with an ENS node.
     * @dev This is an override of addr in order to support aliases 
     *      incluing overrides and defaults.
     * @param node The ENS node to query.
     * @return The associated address.
     */
    function addr(bytes32 node)
        public
        view
        virtual
        override
        returns (address payable)
    {

        // Get the owner of the node.
        address owner = ens.owner(node);
        if (owner == address(nameWrapper)) {
            owner = nameWrapper.ownerOf(uint256(node));
        }

        // Get the ETH address from the node's resolver
        bytes memory addressEth = addr(node, COIN_TYPE_ETH);

        if (isOverridden(owner, node)){

            bytes memory addrOverridden = addr(_overrides[owner][node], COIN_TYPE_ETH);   

            // If there is a value other than zero in the override then return it.
            if (addrOverridden.length != 0) {
                return bytesToAddress(addrOverridden);
            }
        
        } else if ( addressEth.length == 0){
            //if the address is empty check the default address
            if (isDefaultSet(owner, node)){
                bytes memory addrDefault = addr(_defaults[owner][node], COIN_TYPE_ETH);

                // If the defualt address is also 0 then return the 0 address payable. 
                if (addrDefault.length == 0) {
                    return payable(0);
                }

                return bytesToAddress(addrDefault);
            } 
        } else {

                // If there is no override or default returned, return the ETH address.
                return bytesToAddress(addressEth);
        }
    }

    function supportsInterface(bytes4 interfaceID)
        public
        view
        override(
            Multicallable,
            ABIResolver,
            AddrResolver,
            ContentHashResolver,
            DNSResolver,
            InterfaceResolver,
            NameResolver,
            PubkeyResolver,
            TextResolver,
            PermaRecordResolver
        )
        returns (bool)
    {
        return super.supportsInterface(interfaceID);
    }
}
