// SPDX-License-Identifier: AGPLv3
pragma solidity 0.8.19;

import {GeneralDistributionAgreementV1} from "../agreements/GeneralDistributionAgreementV1.sol";
import {SuperfluidPool} from "../superfluid/SuperfluidPool.sol";
import {IStorageLayoutBase} from "./IStorageLayoutBase.sol";
/// @title SuperfluidPoolStorageLayoutMock
/// @notice A mock SuperfluidPool contract for testing storage layout.
/// @dev This contract *MUST* have the same storage layout as SuperfluidPool.
contract SuperfluidPoolStorageLayoutMock is SuperfluidPool, IStorageLayoutBase {
    constructor(GeneralDistributionAgreementV1 gda_) SuperfluidPool(gda_) {}

    function validateStorageLayout() public pure {
        uint256 slot;
        uint256 offset;

        // offset of 2 is taken by the following variables:
        // Initializable._initialized (uint8) 1byte
        // Initializable._initializing (bool) 1byte

        assembly { slot := superToken.slot offset := superToken.offset }
        if (slot != 0 || offset != 2) revert STORAGE_LOCATION_CHANGED("superToken");

        assembly { slot := admin.slot offset := admin.offset }
        if (slot != 1 || offset != 0) revert STORAGE_LOCATION_CHANGED("admin");

        assembly { slot := _index.slot offset := _index.offset }
        if (slot != 2 || offset != 0) revert STORAGE_LOCATION_CHANGED("_index");

        assembly { slot := _membersData.slot offset := _membersData.offset }
        if (slot != 4 || offset != 0) revert STORAGE_LOCATION_CHANGED("_membersData");

        assembly { slot := _disconnectedMembers.slot offset := _disconnectedMembers.offset }
        if (slot != 5 || offset != 0) revert STORAGE_LOCATION_CHANGED("_disconnectedMembers");
    }
}