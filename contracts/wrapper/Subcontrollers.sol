//SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

error SubcontrollerAlreadyBurnt(bytes32 node, address addr);

contract Subcontrollers {

    //Mapping of nodes to addresses of subcontrollers 
    mapping(bytes32 => address) public subcontrollers;

    event SubcontrollerChanged(bytes32 node, address subcontroller);

   /**
     * @notice Checks if address is the subcontroller of the node.
     * @param node namehash of the name to check
     * @param addr which address to check permissions for
     * @return whether or not is set as the subcontroller
     */

    function isSubcontroller(bytes32 node, address addr)
        public
        view
        returns (bool)
    {
        return subcontrollers[node] == addr;
    }
}
