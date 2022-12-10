// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17;

import "../ResolverBase.sol";
import "./IPermaRecordResolver.sol";

abstract contract PermaRecordResolver is IPermaRecordResolver, ResolverBase {
    mapping(uint64 => mapping(bytes32 => mapping(string => string))) versionable_permaRecord;

    /**
     * Sets the perma record data associated with an ENS node and key.
     * May only be called by the owner of that node in the ENS registry.
     * @param node The node to update.
     * @param key The key to set.
     * @param value The text data value to set.
     */
    function setPermaRecord(
        bytes32 node,
        string calldata key,
        string calldata value
    ) external virtual authorised(node) {

        // If the record has not been set yet, set the perma record. 
        if (bytes(versionable_permaRecord[recordVersions[node]][node][key]).length == 0) {
            versionable_permaRecord[recordVersions[node]][node][key] = value;
        }
        emit PermaRecordChanged(node, key, key, value);
    }

    /**
     * Returns the permaRecord data associated with an ENS node and key.
     * @param node The ENS node to query.
     * @param key The text data key to query.
     * @return The associated text data.
     */
    function permaRecord(bytes32 node, string calldata key)
        external
        view
        virtual
        override
        returns (string memory)
    {
        return versionable_permaRecord[recordVersions[node]][node][key];
    }

    function supportsInterface(bytes4 interfaceID)
        public
        view
        virtual
        override
        returns (bool)
    {
        return
            interfaceID == type(IPermaRecordResolver).interfaceId ||
            super.supportsInterface(interfaceID);
    }
}
