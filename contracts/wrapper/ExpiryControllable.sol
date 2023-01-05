//SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {INameWrapper, CAN_EXTEND_EXPIRY, IS_DOT_ETH} from "./INameWrapper.sol";
import {ERC20Recoverable} from "../utils/ERC20Recoverable.sol";
import {IExpiryControllable} from "./IExpiryControllable.sol";

error Unauthorised(bytes32 node, address addr);
error ExpiryControllerLocked(bytes32 node, address controller);

contract ExpiryControllable is IExpiryControllable, ERC20Recoverable {
    
    INameWrapper public immutable nameWrapper;

    //A mapping of nodes to expiry controllers. 
    mapping(bytes32 => address) public expiryControllers;

    constructor(INameWrapper _nameWrapper){
        nameWrapper = _nameWrapper;
    }

   /**
     * @notice Checks if the expiry controller of the name matches the address.
     * @param node The Namehash of the name to check.
     * @param expiryController The expiry controller to check.
     * @return Whether or not the address matches the expiry controller. 
     */

    function isExpiryController(bytes32 node, address expiryController)
        public
        view
        returns (bool)
    {
        return expiryControllers[node] == expiryController;
    }

    /**
     * @notice Set the address of the expiry controller of the name. Only the owner of the parent name can do this.
     * @param parentNode Namehash of the parent name.
     * @param label Label as a string, e.g., 'vitalik' for vitalik.eth.
     * @param expiryController Address to use as the expiry controller of the name.
     */

    function setExpiryController(bytes32 parentNode, string memory label, address expiryController) 
        public 
    {

        bytes32 labelhash = keccak256(bytes(label));
        bytes32 node = _makeNode(parentNode, labelhash);

        // Get the data of the name from the NameWrapper contract 
        (, uint32 fuses,) = nameWrapper.getData(uint256(node));

        // Revert if the caller is not the owner of the parent or approved by the owner, or 
        // if the name is a .eth and is expired. 
        if( !nameWrapper.canModifyName(parentNode, msg.sender)){
           revert Unauthorised(node, msg.sender);
        }

        // If the CAN_EXTEND_EXPIRY fuse has been burned and there 
        // is no address set for the expiry controller of the node. 
        if (fuses & CAN_EXTEND_EXPIRY > 0 && expiryControllers[node] == address(0)) {
            expiryControllers[node] = expiryController;
            emit ExpiryControllerChanged(node, expiryController);
        } else {
            revert ExpiryControllerLocked(node, expiryControllers[node]);
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
