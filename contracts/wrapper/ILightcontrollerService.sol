//SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {INameWrapper, LIGHTCONTROLLER_LOCKED, IS_DOT_ETH} from "./INameWrapper.sol";
import {ERC20Recoverable} from "../utils/ERC20Recoverable.sol";

interface ILightcontrollerService {
    
    event LightcontrollerChanged(bytes32 node, address sub);
    
    function lightcontrollers(bytes32 node) external view returns (address);

    function isLightcontroller(bytes32 node, address subcontroller) external view returns (bool);

    function setLightcontroller(
        bytes32 parentNode, 
        string memory label, 
        address subcontroller
    ) external;

}
