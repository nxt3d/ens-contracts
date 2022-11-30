//SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {INameWrapper, SUBCONTROLLER_LOCKED, IS_DOT_ETH} from "./INameWrapper.sol";
import {ERC20Recoverable} from "../utils/ERC20Recoverable.sol";

interface ISubcontrollerService {
    
    event SubcontrollerChanged(bytes32 node, address sub);
    
    function subcontrollers(bytes32 node) external view returns (address);

    function isSubcontroller(bytes32 node, address subcontroller) external view returns (bool);

    function setSubcontroller(
        bytes32 parentNode, 
        string memory label, 
        address subcontroller
    ) external;

}
