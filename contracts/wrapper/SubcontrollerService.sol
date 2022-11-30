//SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {INameWrapper, SUBCONTROLLER_LOCKED, IS_DOT_ETH} from "./INameWrapper.sol";
import {ERC20Recoverable} from "../utils/ERC20Recoverable.sol";
import {ISubcontrollerService} from "./ISubcontrollerService.sol";

error Unauthorised(bytes32 node, address addr);
error SubcontrollerLocked(bytes32 node, address sub);

contract SubcontrollerService is ISubcontrollerService, ERC20Recoverable {
    
    INameWrapper public immutable nameWrapper;
    uint64 private constant GRACE_PERIOD = 90 days;

    //A mapping of nodes to subcontrollers. 
    mapping(bytes32 => address) public subcontrollers;

    constructor(INameWrapper _nameWrapper){
        nameWrapper = _nameWrapper;
    }

   /**
     * @notice Checks if the subcontroller of the name matches the address.
     * @param node The Namehash of the name to check.
     * @param subcontroller The subcontroller to check.
     * @return Whether or not the address matches the subcontroller. 
     */

    function isSubcontroller(bytes32 node, address subcontroller)
        public
        view
        returns (bool)
    {
        return subcontrollers[node] == subcontroller;
    }

    /**
     * @notice Set the address of the subcontroller of the name. Only the owner of the parent name can do this.
     * @param parentNode Namehash of the parent name.
     * @param label Label as a string, e.g., 'vitalik' for vitalik.eth.
     * @param subcontroller Address to use as the subcontroller of the name.
     */

    function setSubcontroller(bytes32 parentNode, string memory label, address subcontroller) 
        public 
    {

        bytes32 labelhash = keccak256(bytes(label));
        bytes32 node = _makeNode(parentNode, labelhash);

        // Get the data of the name from the NameWrapper contract 
        (address owner, uint32 fuses, uint64 expiry) = nameWrapper.getData(uint256(node));

        // Revert if the caller is not the owner or approved by the owner, or 
        // if the name is a .eth and is expired. 
        if( (owner != msg.sender && !nameWrapper.isApprovedForAll(owner, msg.sender)) || 
        (fuses & IS_DOT_ETH != 0 && expiry - GRACE_PERIOD < block.timestamp)){
           revert Unauthorised(node, msg.sender);
        }

        // If the SUBCONTROLLER_LOCKED fuse has not been burned set the subcontroller address. 
        if (fuses & SUBCONTROLLER_LOCKED == 0 ) {
            subcontrollers[node] = subcontroller;
            emit SubcontrollerChanged(node, subcontroller);
        } else {
            revert SubcontrollerLocked(node, subcontrollers[node]);
        }
    }    

    // Make a namehash using a node and labelhash of the subname.
    function _makeNode(bytes32 node, bytes32 labelhash)
        private
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(node, labelhash));
    }

}
