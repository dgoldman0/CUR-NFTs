// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../Governor.sol";
import "../../token/TRC20/extensions/TRC20VotesComp.sol";

/**
 * @dev Extension of {Governor} for voting weight extraction from a Comp token.
 *
 * _Available since v4.3._
 */
abstract contract GovernorVotesComp is Governor {
    TRC20VotesComp public immutable token;

    constructor(TRC20VotesComp token_) {
        token = token_;
    }

    /**
     * Read the voting weight from the token's built in snapshot mechanism (see {IGovernor-getVotes}).
     */
    function getVotes(address account, uint256 blockNumber) public view virtual override returns (uint256) {
        return token.getPriorVotes(account, blockNumber);
    }
}
