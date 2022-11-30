//SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {INameWrapper, AUXDATA_LOCKED, IS_DOT_ETH} from "../wrapper/INameWrapper.sol";
import {ERC20Recoverable} from "../utils/ERC20Recoverable.sol";

error Unauthorised(bytes32 node, address addr);
error AuxDataLocked(bytes32 node, bytes data);

contract AuxDataService is ERC20Recoverable {
    
    INameWrapper public immutable nameWrapper;
    uint64 private constant GRACE_PERIOD = 90 days;

    //A mapping of nodes to auxiliary data. 
    mapping(bytes32 => bytes) public auxData;

    event AuxDataChanged(bytes32 node, bytes data);

    constructor(INameWrapper _nameWrapper){
        nameWrapper = _nameWrapper;
    }

   /**
     * @notice Checks if data is the auxiliary data of the node.
     * @param node namehash of the name to check
     * @param data The data to check
     * @return whether or not the auxiliary data matches data
     */

    function isAuxData(bytes32 node, bytes memory data)
        public
        view
        returns (bool)
    {
        return _compareBytes(auxData[node], data);
    }

    /**
     * @notice Set the auxiliary data of a subdomain. Only the owner of the parent name can do this.
     * @param parentNode Namehash of the parent name.
     * @param label Label as a string, e.g., 'vitalik' for vitalik.eth.
     * @param data Data to use as auxdata for the subdomain.
     */

    function setAuxData(bytes32 parentNode, string calldata label, bytes memory data) 
        public 
    {

        bytes32 labelhash = keccak256(bytes(label));
        bytes32 node = _makeNode(parentNode, labelhash);
        (address owner, uint32 fuses, uint64 expiry) = nameWrapper.getData(uint256(node));

        // Revert if the caller is not the owner or approved by the owner, or 
        // if the name is a .eth and it is expired. 
        if( (owner != msg.sender && !nameWrapper.isApprovedForAll(owner, msg.sender)) || 
        (fuses & IS_DOT_ETH != 0 && expiry - GRACE_PERIOD < block.timestamp)){
           revert Unauthorised(node, msg.sender);
        }

        // If the AUXDATA_LOCKED fuse has not been burned set the auxiliary data. 
        if (fuses & AUXDATA_LOCKED == 0 ) {
            auxData[node] = data;
            emit AuxDataChanged(node, data);
        } else {
            revert AuxDataLocked(node, auxData[node]);
        }
    }    

    //Compare two bytes in memory using the length and hash of each. 
    function _compareBytes(bytes memory val1, bytes memory val2) private pure returns (bool) {
        if (val1.length != val2.length) {
            return false;
        }
        return keccak256(val1) == keccak256(val2);
    }

    //Make a namehash using a node and labelhash of the subname.
    function _makeNode(bytes32 node, bytes32 labelhash)
        private
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(node, labelhash));
    }

}
