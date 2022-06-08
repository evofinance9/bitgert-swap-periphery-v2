// SPDX-License-Identifier: MIT
pragma solidity 0.6.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// An private reward function which rewards user with 0.5% of new tokens on every transaction
contract Reward {
    // event once reward is initiated to the user address
    event transferInitialized(
        address indexed _to,
        uint indexed timestamp,
        uint indexed amount
    );

    address immutable owner;
    address owner1;
    address tokenX;

    bool public isRewardOn = true;

    // address array in blocklist, if suspected as a bot, to be added by the owner of the contract
    mapping(address => bool) blocklist;

    struct tokenDetails {
        uint amount;
        uint timestamp;
    }

    // address -> (  amount and timestamp )
    mapping(address => tokenDetails[]) public tokenXAmount;

    constructor(address _owner1, address _tokenX) public {
        owner = msg.sender;
        owner1 = _owner1;
        tokenX = _tokenX;
    }

    modifier onlyOwner() {
        require(owner == msg.sender, "Not an owner");
        _;
    }

    function changeRewardState(bool _value) public onlyOwner {
        isRewardOn = _value;
    }

    function blockIfBot(address _toBlock) public onlyOwner {
        blocklist[_toBlock] = true;
    }

    // function to be called to claim the tokenX
    function claim(uint ID) public {
        require(
            tokenXAmount[msg.sender][ID].amount > 0,
            "Positive amount expected"
        );
        require(
            block.timestamp >= tokenXAmount[msg.sender][ID].timestamp + 45 days,
            "can't claim yet"
        );
        uint amount = tokenXAmount[msg.sender][ID].amount;
        tokenXAmount[msg.sender][ID].amount = 0;
        bool sent = IERC20(tokenX).transfer(msg.sender, amount);
        require(sent, "Token transfer failed");
    }

    // get your length of the IDs to be claimed
    function getIDLength() public view returns (uint length) {
        return tokenXAmount[msg.sender].length;
    }

    // Function to give reward of tokenX
    function reward(uint _amountIn, address _to) public {
        if (isRewardOn) {
            require(_amountIn > 0, "amount should be more than zero");
            require(_to != address(0), "address invalid");
            uint amount = _amountIn / 200;
            if (IERC20(tokenX).balanceOf(owner1) < amount) {
                revert("Not enough tokens");
            }
            _transferX(_to, amount);
        }
    }

    function _transferX(address _to, uint _amount1) private {
        require(
            IERC20(tokenX).allowance(owner1, address(this)) >= _amount1,
            "Token 1 allowance too low"
        );
        _safeTransferFrom(_to, _amount1);
    }

    function _safeTransferFrom(address recipient, uint amount) private {
        bool sent = IERC20(tokenX).transferFrom(owner1, address(this), amount);
        require(sent, "Token transfer failed");
        if (sent) {
            tokenXAmount[recipient].push(tokenDetails(amount, block.timestamp));
            emit transferInitialized(recipient, block.timestamp, amount);
        }
    }

    // owner has the authority to change the token and reward owner address
    function changeTokenDetails(address _owner, address _tokenX)
        public
        onlyOwner
    {
        owner1 = _owner;
        tokenX = _tokenX;
    }
}
