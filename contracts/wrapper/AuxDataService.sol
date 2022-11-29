//SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

error AuxDataLocked(bytes32 node, uint256 addr);

abstract contract AuxDataService {

    //A mapping of nodes to auxiliary data. 
    mapping(bytes32 => uint256) public auxData;

    event AuxDataChanged(bytes32 node, uint256 data);

   /**
     * @notice Checks if data is the auxiliary data of the node.
     * @param node namehash of the name to check
     * @param data The data to check
     * @return whether or not the auxiliary data matches data
     */

    function isAuxData(bytes32 node, uint256 data)
        public
        view
        returns (bool)
    {
        return auxData[node] == data;
    }

    function setAuxData(bytes32 parentNode, string calldata label, uint256 data) external virtual; 
}
