//SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IExpiryControllable {
    
    event ExpiryControllerChanged(bytes32 node, address controller);
    
    function expiryControllers(bytes32 node) external view returns (address);

    function isExpiryController(bytes32 node, address controller) external view returns (bool);

    function setExpiryController(
        bytes32 parentNode, 
        string memory label, 
        address controller
    ) external;

}
