pragma solidity =0.6.6;

import "@evofinance9/bitgert-swap-core/contracts/interfaces/IBitgertSwapFactory.sol";
import "@evofinance9/bitgert-swap-lib/contracts/utils/TransferHelper.sol";

import "./interfaces/IBitgertSwapRouter.sol";
import "./libraries/BitgertSwapLibrary.sol";
import "@evofinance9/bitgert-swap-lib/contracts/math/SafeMath.sol";
import "@evofinance9/bitgert-swap-lib/contracts/token/BEP20/IBEP20.sol";
import "./interfaces/IWBRISE.sol";
import "./interfaces/IBRC20.sol";
import "./Reward.sol";

contract BitgertSwapRouter is IBitgertSwapRouter {
    using SafeMath for uint256;
    address public immutable override factory;
    address public immutable override WBRISE;

    address[] tokenPair;
    address[] tokenPairReversed;

    // fee
    address public feeTo;
    address public feeToSetter;

    address public rewardToken;

    Reward public reward;

    modifier ensure(uint256 deadline) {
        require(deadline >= block.timestamp, "BitgertSwapRouter: EXPIRED");
        _;
    }

    constructor(
        address _factory,
        address _WBRISE,
        address _rewardToken
    ) public {
        factory = _factory;
        WBRISE = _WBRISE;

        feeToSetter = msg.sender;
        // default feeTo is feeToSetter
        feeTo = feeToSetter;

        // initialize reward
        rewardToken = _rewardToken;
        reward = new Reward(msg.sender, _rewardToken);

        tokenPair.push(0x0000000000000000000000000000000000000000);
        tokenPair.push(_WBRISE);

        tokenPairReversed.push(_WBRISE);
        tokenPairReversed.push(_rewardToken);
    }

    receive() external payable {
        assert(msg.sender == WBRISE); // only accept BRISE via fallback from the WBRISE contract
    }

    // **** ADD LIQUIDITY ****
    function _addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin
    ) internal virtual returns (uint256 amountA, uint256 amountB) {
        // create the pair if it doesn't exist yet
        if (
            IBitgertSwapFactory(factory).getPair(tokenA, tokenB) == address(0)
        ) {
            IBitgertSwapFactory(factory).createPair(tokenA, tokenB);
        }
        (uint256 reserveA, uint256 reserveB) = BitgertSwapLibrary.getReserves(
            factory,
            tokenA,
            tokenB
        );
        if (reserveA == 0 && reserveB == 0) {
            (amountA, amountB) = (amountADesired, amountBDesired);
        } else {
            uint256 amountBOptimal = BitgertSwapLibrary.quote(
                amountADesired,
                reserveA,
                reserveB
            );
            if (amountBOptimal <= amountBDesired) {
                require(
                    amountBOptimal >= amountBMin,
                    "BitgertSwapRouter: INSUFFICIENT_B_AMOUNT"
                );
                (amountA, amountB) = (amountADesired, amountBOptimal);
            } else {
                uint256 amountAOptimal = BitgertSwapLibrary.quote(
                    amountBDesired,
                    reserveB,
                    reserveA
                );
                assert(amountAOptimal <= amountADesired);
                require(
                    amountAOptimal >= amountAMin,
                    "BitgertSwapRouter: INSUFFICIENT_A_AMOUNT"
                );
                (amountA, amountB) = (amountAOptimal, amountBDesired);
            }
        }
    }

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    )
        external
        virtual
        override
        ensure(deadline)
        returns (
            uint256 amountA,
            uint256 amountB,
            uint256 liquidity
        )
    {
        (amountA, amountB) = _addLiquidity(
            tokenA,
            tokenB,
            amountADesired,
            amountBDesired,
            amountAMin,
            amountBMin
        );
        address pair = BitgertSwapLibrary.pairFor(factory, tokenA, tokenB);
        TransferHelper.safeTransferFrom(tokenA, msg.sender, pair, amountA);
        TransferHelper.safeTransferFrom(tokenB, msg.sender, pair, amountB);
        liquidity = IBitgertSwapPair(pair).mint(to);
    }

    function addLiquidityBRISE(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountBRISEMin,
        address to,
        uint256 deadline
    )
        external
        payable
        virtual
        override
        ensure(deadline)
        returns (
            uint256 amountToken,
            uint256 amountBRISE,
            uint256 liquidity
        )
    {
        (amountToken, amountBRISE) = _addLiquidity(
            token,
            WBRISE,
            amountTokenDesired,
            msg.value,
            amountTokenMin,
            amountBRISEMin
        );
        address pair = BitgertSwapLibrary.pairFor(factory, token, WBRISE);
        TransferHelper.safeTransferFrom(token, msg.sender, pair, amountToken);
        IWBRISE(WBRISE).deposit{value: amountBRISE}();
        assert(IWBRISE(WBRISE).transfer(pair, amountBRISE));
        liquidity = IBitgertSwapPair(pair).mint(to);
        // refund dust BRISE, if any
        if (msg.value > amountBRISE)
            TransferHelper.safeTransferBNB(msg.sender, msg.value - amountBRISE);
    }

    // **** REMOVE LIQUIDITY ****
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    )
        public
        virtual
        override
        ensure(deadline)
        returns (uint256 amountA, uint256 amountB)
    {
        address pair = BitgertSwapLibrary.pairFor(factory, tokenA, tokenB);
        IBitgertSwapPair(pair).transferFrom(msg.sender, pair, liquidity); // send liquidity to pair
        (uint256 amount0, uint256 amount1) = IBitgertSwapPair(pair).burn(to);
        (address token0, ) = BitgertSwapLibrary.sortTokens(tokenA, tokenB);
        (amountA, amountB) = tokenA == token0
            ? (amount0, amount1)
            : (amount1, amount0);
        require(
            amountA >= amountAMin,
            "BitgertSwapRouter: INSUFFICIENT_A_AMOUNT"
        );
        require(
            amountB >= amountBMin,
            "BitgertSwapRouter: INSUFFICIENT_B_AMOUNT"
        );
    }

    function removeLiquidityBRISE(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountBRISEMin,
        address to,
        uint256 deadline
    )
        public
        virtual
        override
        ensure(deadline)
        returns (uint256 amountToken, uint256 amountBRISE)
    {
        (amountToken, amountBRISE) = removeLiquidity(
            token,
            WBRISE,
            liquidity,
            amountTokenMin,
            amountBRISEMin,
            address(this),
            deadline
        );
        TransferHelper.safeTransfer(token, to, amountToken);
        IWBRISE(WBRISE).withdraw(amountBRISE);
        TransferHelper.safeTransferBNB(to, amountBRISE);
    }

    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external virtual override returns (uint256 amountA, uint256 amountB) {
        address pair = BitgertSwapLibrary.pairFor(factory, tokenA, tokenB);
        uint256 value = approveMax ? uint256(-1) : liquidity;
        IBitgertSwapPair(pair).permit(
            msg.sender,
            address(this),
            value,
            deadline,
            v,
            r,
            s
        );
        (amountA, amountB) = removeLiquidity(
            tokenA,
            tokenB,
            liquidity,
            amountAMin,
            amountBMin,
            to,
            deadline
        );
    }

    function removeLiquidityBRISEWithPermit(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountBRISEMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    )
        external
        virtual
        override
        returns (uint256 amountToken, uint256 amountBRISE)
    {
        address pair = BitgertSwapLibrary.pairFor(factory, token, WBRISE);
        uint256 value = approveMax ? uint256(-1) : liquidity;
        IBitgertSwapPair(pair).permit(
            msg.sender,
            address(this),
            value,
            deadline,
            v,
            r,
            s
        );
        (amountToken, amountBRISE) = removeLiquidityBRISE(
            token,
            liquidity,
            amountTokenMin,
            amountBRISEMin,
            to,
            deadline
        );
    }

    // **** REMOVE LIQUIDITY (supporting fee-on-transfer tokens) ****
    function removeLiquidityBRISESupportingFeeOnTransferTokens(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountBRISEMin,
        address to,
        uint256 deadline
    ) public virtual override ensure(deadline) returns (uint256 amountBRISE) {
        (, amountBRISE) = removeLiquidity(
            token,
            WBRISE,
            liquidity,
            amountTokenMin,
            amountBRISEMin,
            address(this),
            deadline
        );
        TransferHelper.safeTransfer(
            token,
            to,
            IBEP20(token).balanceOf(address(this))
        );
        IWBRISE(WBRISE).withdraw(amountBRISE);
        TransferHelper.safeTransferBNB(to, amountBRISE);
    }

    function removeLiquidityBRISEWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountBRISEMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external virtual override returns (uint256 amountBRISE) {
        address pair = BitgertSwapLibrary.pairFor(factory, token, WBRISE);
        uint256 value = approveMax ? uint256(-1) : liquidity;
        IBitgertSwapPair(pair).permit(
            msg.sender,
            address(this),
            value,
            deadline,
            v,
            r,
            s
        );
        amountBRISE = removeLiquidityBRISESupportingFeeOnTransferTokens(
            token,
            liquidity,
            amountTokenMin,
            amountBRISEMin,
            to,
            deadline
        );
    }

    // **** SWAP ****
    // requires the initial amount to have already been sent to the first pair
    function _swap(
        uint256 amountIn,
        uint256[] memory amounts,
        address[] memory path,
        address _to,
        address _trader
    ) internal virtual {
        for (uint256 i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0, ) = BitgertSwapLibrary.sortTokens(input, output);
            uint256 amountOut = amounts[i + 1];
            (uint256 amount0Out, uint256 amount1Out) = input == token0
                ? (uint256(0), amountOut)
                : (amountOut, uint256(0));
            address to = i < path.length - 2
                ? BitgertSwapLibrary.pairFor(factory, output, path[i + 2])
                : _to;
            IBitgertSwapPair(BitgertSwapLibrary.pairFor(factory, input, output))
                .swap(amount0Out, amount1Out, to);
        }

        if (path[0] != rewardToken) {
            // initiate reward
            uint256 output_WBRISE = amountIn;
            if (path[0] != WBRISE) {
                tokenPair[0] = path[0];
                uint256[] memory outputs = getAmountsOut(amountIn, tokenPair);
                output_WBRISE = outputs[1];
            }
            uint256 amountWBRISE = output_WBRISE / 200;
            uint256[] memory rewardAmounts = getAmountsOut(
                amountWBRISE,
                tokenPairReversed
            );
            reward.reward(rewardAmounts[1], _trader);
        }
    }

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    )
        external
        virtual
        override
        ensure(deadline)
        returns (uint256[] memory amounts)
    {
        amounts = BitgertSwapLibrary.getAmountsOut(factory, amountIn, path);
        amounts[0] = takeFee(amounts[0], path[0], to);
        require(
            amounts[amounts.length - 1] >= amountOutMin,
            "BitgertSwapRouter: INSUFFICIENT_OUTPUT_AMOUNT"
        );
        TransferHelper.safeTransferFrom(
            path[0],
            msg.sender,
            BitgertSwapLibrary.pairFor(factory, path[0], path[1]),
            amounts[0]
        );
        _swap(amountIn, amounts, path, to, to);
    }

    function swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    )
        external
        virtual
        override
        ensure(deadline)
        returns (uint256[] memory amounts)
    {
        amounts = BitgertSwapLibrary.getAmountsIn(factory, amountOut, path);
        amounts[0] = takeFee(amounts[0], path[0], to);
        require(
            amounts[0] <= amountInMax,
            "BitgertSwapRouter: EXCESSIVE_INPUT_AMOUNT"
        );
        TransferHelper.safeTransferFrom(
            path[0],
            msg.sender,
            BitgertSwapLibrary.pairFor(factory, path[0], path[1]),
            amounts[0]
        );
        _swap(amountInMax, amounts, path, to, to);
    }

    function swapExactBRISEForTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    )
        external
        payable
        virtual
        override
        ensure(deadline)
        returns (uint256[] memory amounts)
    {
        require(path[0] == WBRISE, "BitgertSwapRouter: INVALID_PATH");
        amounts = BitgertSwapLibrary.getAmountsOut(factory, msg.value, path);
        require(
            amounts[amounts.length - 1] >= amountOutMin,
            "BitgertSwapRouter: INSUFFICIENT_OUTPUT_AMOUNT"
        );
        IWBRISE(WBRISE).deposit{value: amounts[0]}();
        amounts[0] = takeFee(amounts[0], WBRISE, to);
        assert(
            IWBRISE(WBRISE).transfer(
                BitgertSwapLibrary.pairFor(factory, path[0], path[1]),
                amounts[0]
            )
        );
        _swap(msg.value, amounts, path, to, to);
    }

    function swapTokensForExactBRISE(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    )
        external
        virtual
        override
        ensure(deadline)
        returns (uint256[] memory amounts)
    {
        require(
            path[path.length - 1] == WBRISE,
            "BitgertSwapRouter: INVALID_PATH"
        );
        amounts = BitgertSwapLibrary.getAmountsIn(factory, amountOut, path);
        amounts[0] = takeFee(amounts[0], path[0], to);
        require(
            amounts[0] <= amountInMax,
            "BitgertSwapRouter: EXCESSIVE_INPUT_AMOUNT"
        );
        TransferHelper.safeTransferFrom(
            path[0],
            msg.sender,
            BitgertSwapLibrary.pairFor(factory, path[0], path[1]),
            amounts[0]
        );
        _swap(amountInMax, amounts, path, address(this), to);
        IWBRISE(WBRISE).withdraw(amounts[amounts.length - 1]);
        TransferHelper.safeTransferBNB(to, amounts[amounts.length - 1]);
    }

    function swapExactTokensForBRISE(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    )
        external
        virtual
        override
        ensure(deadline)
        returns (uint256[] memory amounts)
    {
        require(
            path[path.length - 1] == WBRISE,
            "BitgertSwapRouter: INVALID_PATH"
        );
        amounts = BitgertSwapLibrary.getAmountsOut(factory, amountIn, path);
        amounts[0] = takeFee(amounts[0], path[0], to);
        require(
            amounts[amounts.length - 1] >= amountOutMin,
            "BitgertSwapRouter: INSUFFICIENT_OUTPUT_AMOUNT"
        );
        TransferHelper.safeTransferFrom(
            path[0],
            msg.sender,
            BitgertSwapLibrary.pairFor(factory, path[0], path[1]),
            amounts[0]
        );
        _swap(amountIn, amounts, path, address(this), to);
        IWBRISE(WBRISE).withdraw(amounts[amounts.length - 1]);
        TransferHelper.safeTransferBNB(to, amounts[amounts.length - 1]);
    }

    function swapBRISEForExactTokens(
        uint256 amountOut,
        address[] calldata path,
        address to,
        uint256 deadline
    )
        external
        payable
        virtual
        override
        ensure(deadline)
        returns (uint256[] memory amounts)
    {
        require(path[0] == WBRISE, "BitgertSwapRouter: INVALID_PATH");
        amounts = BitgertSwapLibrary.getAmountsIn(factory, amountOut, path);
        amounts[0] = takeFee(amounts[0], WBRISE, to);
        require(
            amounts[0] <= msg.value,
            "BitgertSwapRouter: EXCESSIVE_INPUT_AMOUNT"
        );
        IWBRISE(WBRISE).deposit{value: amounts[0]}();
        assert(
            IWBRISE(WBRISE).transfer(
                BitgertSwapLibrary.pairFor(factory, path[0], path[1]),
                amounts[0]
            )
        );
        _swap(msg.value, amounts, path, to, to);
        // refund dust BRISE, if any
        if (msg.value > amounts[0])
            TransferHelper.safeTransferBNB(msg.sender, msg.value - amounts[0]);
    }

    // **** SWAP (supporting fee-on-transfer tokens) ****
    // requires the initial amount to have already been sent to the first pair
    function _swapSupportingFeeOnTransferTokens(
        uint256 amountIn,
        address[] memory path,
        address _to,
        address _trader
    ) internal virtual {
        for (uint256 i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0, ) = BitgertSwapLibrary.sortTokens(input, output);
            IBitgertSwapPair pair = IBitgertSwapPair(
                BitgertSwapLibrary.pairFor(factory, input, output)
            );
            uint256 amountInput;
            uint256 amountOutput;
            {
                // scope to avoid stack too deep errors
                (uint256 reserve0, uint256 reserve1, ) = pair.getReserves();
                (uint256 reserveInput, uint256 reserveOutput) = input == token0
                    ? (reserve0, reserve1)
                    : (reserve1, reserve0);
                amountInput = IBEP20(input).balanceOf(address(pair)).sub(
                    reserveInput
                );
                amountOutput = BitgertSwapLibrary.getAmountOut(
                    amountInput,
                    reserveInput,
                    reserveOutput
                );
            }
            (uint256 amount0Out, uint256 amount1Out) = input == token0
                ? (uint256(0), amountOutput)
                : (amountOutput, uint256(0));
            address to = i < path.length - 2
                ? BitgertSwapLibrary.pairFor(factory, output, path[i + 2])
                : _to;
            pair.swap(amount0Out, amount1Out, to);
        }

        if (path[0] != rewardToken) {
            // initiate reward
            uint256 output_WBRISE = amountIn;
            if (path[0] != WBRISE) {
                tokenPair[0] = path[0];
                uint256[] memory outputs = getAmountsOut(amountIn, tokenPair);
                output_WBRISE = outputs[1];
            }
            uint256 amountWBRISE = output_WBRISE / 200;
            uint256[] memory rewardAmounts = getAmountsOut(
                amountWBRISE,
                tokenPairReversed
            );
            reward.reward(rewardAmounts[1], _trader);
        }
    }

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external virtual override ensure(deadline) {
        amountIn = takeFee(amountIn, path[0], to);
        TransferHelper.safeTransferFrom(
            path[0],
            msg.sender,
            BitgertSwapLibrary.pairFor(factory, path[0], path[1]),
            amountIn
        );
        uint256 balanceBefore = IBEP20(path[path.length - 1]).balanceOf(to);
        _swapSupportingFeeOnTransferTokens(amountIn, path, to, to);
        require(
            IBEP20(path[path.length - 1]).balanceOf(to).sub(balanceBefore) >=
                amountOutMin,
            "BitgertSwapRouter: INSUFFICIENT_OUTPUT_AMOUNT"
        );
    }

    function swapExactBRISEForTokensSupportingFeeOnTransferTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable virtual override ensure(deadline) {
        require(path[0] == WBRISE, "BitgertSwapRouter: INVALID_PATH");
        uint256 amountIn = msg.value;
        IWBRISE(WBRISE).deposit{value: amountIn}();
        amountIn = takeFee(amountIn, WBRISE, to);
        assert(
            IWBRISE(WBRISE).transfer(
                BitgertSwapLibrary.pairFor(factory, path[0], path[1]),
                amountIn
            )
        );
        uint256 balanceBefore = IBEP20(path[path.length - 1]).balanceOf(to);
        _swapSupportingFeeOnTransferTokens(amountIn, path, to, to);
        require(
            IBEP20(path[path.length - 1]).balanceOf(to).sub(balanceBefore) >=
                amountOutMin,
            "BitgertSwapRouter: INSUFFICIENT_OUTPUT_AMOUNT"
        );
    }

    function swapExactTokensForBRISESupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external virtual override ensure(deadline) {
        require(
            path[path.length - 1] == WBRISE,
            "BitgertSwapRouter: INVALID_PATH"
        );
        amountIn = takeFee(amountIn, path[0], to);
        TransferHelper.safeTransferFrom(
            path[0],
            msg.sender,
            BitgertSwapLibrary.pairFor(factory, path[0], path[1]),
            amountIn
        );
        _swapSupportingFeeOnTransferTokens(amountIn, path, address(this), to);
        uint256 amountOut = IBEP20(WBRISE).balanceOf(address(this));
        require(
            amountOut >= amountOutMin,
            "BitgertSwapRouter: INSUFFICIENT_OUTPUT_AMOUNT"
        );
        IWBRISE(WBRISE).withdraw(amountOut);
        TransferHelper.safeTransferBNB(to, amountOut);
    }

    // **** LIBRARY FUNCTIONS ****
    function quote(
        uint256 amountA,
        uint256 reserveA,
        uint256 reserveB
    ) public pure virtual override returns (uint256 amountB) {
        return BitgertSwapLibrary.quote(amountA, reserveA, reserveB);
    }

    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) public pure virtual override returns (uint256 amountOut) {
        return BitgertSwapLibrary.getAmountOut(amountIn, reserveIn, reserveOut);
    }

    function getAmountIn(
        uint256 amountOut,
        uint256 reserveIn,
        uint256 reserveOut
    ) public pure virtual override returns (uint256 amountIn) {
        return BitgertSwapLibrary.getAmountIn(amountOut, reserveIn, reserveOut);
    }

    function getAmountsOut(uint256 amountIn, address[] memory path)
        public
        view
        virtual
        override
        returns (uint256[] memory amounts)
    {
        return BitgertSwapLibrary.getAmountsOut(factory, amountIn, path);
    }

    function getAmountsIn(uint256 amountOut, address[] memory path)
        public
        view
        virtual
        override
        returns (uint256[] memory amounts)
    {
        return BitgertSwapLibrary.getAmountsIn(factory, amountOut, path);
    }

    function takeFee(
        uint256 amount,
        address tokenAddress,
        address trader
    ) internal virtual returns (uint256) {
        uint256 feeAmount = amount / 500;

        if (tokenAddress == WBRISE) {
            assert(IWBRISE(WBRISE).transfer(feeTo, feeAmount));
        } else {
            assert(IBRC20(tokenAddress).transferFrom(trader, feeTo, feeAmount));
        }

        return amount - feeAmount;
    }

    function setFeeTo(address _feeTo) external {
        require(msg.sender == feeToSetter, "BitgertSwapRouter: FORBIDDEN");
        feeTo = _feeTo;
    }

    function updateRewardToken(address _rewardToken) external {
        require(msg.sender == feeToSetter, "BitgertSwapRouter: FORBIDDEN");
        rewardToken = _rewardToken;
    }

    function setFeeToSetter(address _feeToSetter) external {
        require(msg.sender == feeToSetter, "BitgertSwapRouter: FORBIDDEN");
        feeToSetter = _feeToSetter;
    }
}
