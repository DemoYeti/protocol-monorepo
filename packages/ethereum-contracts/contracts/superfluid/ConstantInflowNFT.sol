// SPDX-License-Identifier: AGPLv3
pragma solidity 0.8.16;

import { ISuperToken } from "../interfaces/superfluid/ISuperToken.sol";
import {
    IConstantOutflowNFT
} from "../interfaces/superfluid/IConstantOutflowNFT.sol";
import {
    IConstantInflowNFT
} from "../interfaces/superfluid/IConstantInflowNFT.sol";
import { CFAv1NFTBase } from "./CFAv1NFTBase.sol";

/// @note TODO: clean up the inheritance with IConstantInflowNFT and CFAv1Base
// solhint-disable no-empty-blocks
// solhint-disable no-unused-vars

/// @title ConstantInflowNFT Contract (CIF NFT)
/// @author Superfluid
/// @notice The ConstantInflowNFT contract to be minted to the flow sender on flow creation.
/// @dev This contract does not hold any storage, but references the ConstantOutflowNFT contract storage.
contract ConstantInflowNFT is CFAv1NFTBase {
    function proxiableUUID() public pure override returns (bytes32) {
        return
            keccak256(
                "org.superfluid-finance.contracts.ConstantInflowNFT.implementation"
            );
    }

    /// @notice This returns the Uniform Resource Identifier (URI), where the metadata for the NFT lives.
    /// @dev Returns the Uniform Resource Identifier (URI) for `_tokenId` token.
    /// @return the token URI
    function tokenURI(
        uint256 // _tokenId
    ) external view virtual override returns (string memory) {
        return "";
    }

    /// @note Neither mint nor burn will work here because we need to forward these calls.

    /// @note mint/burn should also probably be access controlled to just outflow NFT calling it

    /// @notice The mint function emits the "mint" `Transfer` event.
    /// @dev We don't modify storage as this is handled in ConstantOutflowNFT.sol and this function's sole purpose
    /// is to inform clients that search for events.
    /// @param _to the receiver of the inflow nft and desired flow receiver
    /// @param _newTokenId the new token id
    function mint(address _to, uint256 _newTokenId) external {
        _mint(_to, _newTokenId);
    }

    /// @notice This burn function emits the "burn" `Transfer` event.
    /// @dev We don't modify storage as this is handled in ConstantOutflowNFT.sol and this function's sole purpose
    /// is to inform clients that search for events.
    /// @param _tokenId desired token id to burn
    function burn(uint256 _tokenId) external {
        _burn(_tokenId);
    }

    function _flowDataByTokenId(
        uint256 _tokenId
    ) internal view returns (FlowData memory flowData) {
        IConstantOutflowNFT constantOutflowNFT = superToken
            .constantOutflowNFT();
        flowData = constantOutflowNFT.flowDataBySenderReceiver(_tokenId);
    }

    function _safeTransfer(
        address _from,
        address _to,
        uint256 _tokenId,
        bytes memory // _data
    ) internal virtual override {
        _transfer(_from, _to, _tokenId);
        // TODO
        // require(_checkOnERC721Received(from, to, tokenId, data),
        // "ERC721: transfer to non ERC721Receiver implementer");
    }

    /// @inheritdoc CFAv1NFTBase
    function _ownerOf(
        uint256 _tokenId
    ) internal view virtual override returns (address) {
        FlowData memory flowData = _flowDataByTokenId(_tokenId);
        return flowData.flowReceiver;
    }

    /// @notice Transfers `_tokenId` from `_from` to `_to`
    /// @dev `_from` must own `_tokenId` and `_to` cannot be `address(0)`.
    ///
    /// We emit three Transfer events from this ConstantInflowNFT contract:
    /// `_from` is old InflowNFT owner | `_to` is new InflowNFT owner
    /// 1. Transfer of `_tokenId` (`_from` -> `_to`)
    /// 2. Transfer (burn) of `_tokenId` (`_to` -> `address(0)`)
    /// 3. Transfer (mint) of `newTokenId` (`address(0)` -> `_to`)
    ///
    /// We also emit two Transfer events from the ConstantOutflowNFT contract:
    /// 1. Transfer (burn) of `_tokenId` (`_from` -> `address(0)`) | `_from` is OutflowNFT owner
    /// 2. Transfer (mint) of `newTokenId` (`address(0)` -> `_to`)   | `_to` is OutflowNFT owner
    ///
    /// We also clear storage for `_tokenApprovals` and `_flowDataBySenderReceiver` with `_tokenId`
    /// and create new storage for `_flowDataBySenderReceiver` with `newTokenId`.
    /// NOTE: There are also interactions at the protocol level:
    /// - We delete the flow from oldFlowData.flowSender => oldFlowData.flowReceiver (_from)
    ///   - This will trigger super app before/afterAgreementTerminated hooks if a super app is part of the agreement
    /// - We create a new flow from oldFlowData.flowSender => _to
    ///   - This will trigger super app before/afterAgreementCreated hooks if a super app is part of the agreement
    /// @param _from the owner of _tokenId
    /// @param _to the receiver of the NFT
    /// @param _tokenId the token id to transfer
    function _transfer(
        address _from,
        address _to,
        uint256 _tokenId
    ) internal virtual override {
        if (CFAv1NFTBase.ownerOf(_tokenId) != _from) {
            revert CFA_NFT_TRANSFER_FROM_INCORRECT_OWNER();
        }

        if (_to == address(0)) {
            revert CFA_NFT_TRANSFER_TO_ZERO_ADDRESS();
        }

        FlowData memory oldFlowData = _flowDataByTokenId(_tokenId);
        // @note we are doing this external call twice, here and in the function above
        IConstantOutflowNFT constantOutflowNFT = superToken
            .constantOutflowNFT();

        uint256 newTokenId = uint256(
            keccak256(abi.encode(oldFlowData.flowSender, _to))
        );

        /// TODO: If we choose to use the _beforeTokenTransfer hook
        /// _beforeTokenTransfer(from, to, _tokenId, 1);

        // Check that _tokenId was not transferred by `_beforeTokenTransfer` hook
        // require(_ownerOf(_tokenId) == _from, "ERC721: transfer from incorrect owner");

        // emit initial transfer of inflow token with _tokenId (from -> to)
        emit Transfer(_from, _to, _tokenId);

        // burn the outflow nft with _tokenId
        constantOutflowNFT.inflowTransferBurn(_tokenId);

        // burn the inflow token with _tokenId
        _burn(_tokenId);

        // mint the outflow token with newTokenId
        constantOutflowNFT.inflowTransferMint(
            oldFlowData.flowSender,
            _to,
            newTokenId
        );

        // mint the inflow token to _to (inflow NFT receiver) with newTokenId
        _mint(_to, newTokenId);
    }

    function _mint(address _to, uint256 _newTokenId) internal {
        emit Transfer(address(0), _to, _newTokenId);
    }

    function _burn(uint256 _tokenId) internal {
        FlowData memory flowData = _flowDataByTokenId(_tokenId);
        emit Transfer(flowData.flowReceiver, address(0), _tokenId);
    }
}