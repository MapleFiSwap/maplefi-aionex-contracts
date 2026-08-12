// SPDX-License-Identifier: MIT
pragma solidity 0.8.35;

/**
 * @title MapleFi AIONEX Native Execution - No-viaIR Remix Build
 * @notice Self-contained source for fresh Base and BNB deployments.
 * @dev Designed for normal Solidity compilation in Remix: optimizer ON, viaIR OFF.
 *      No 0x API, no third-party aggregator router, no proxy, no external imports.
 */

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
}

library SafeERC20Lite {
    error SafeERC20Failed();

    function safeTransfer(IERC20 token, address to, uint256 amount) internal {
        _callOptionalReturn(address(token), abi.encodeWithSelector(token.transfer.selector, to, amount));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        _callOptionalReturn(address(token), abi.encodeWithSelector(token.transferFrom.selector, from, to, amount));
    }

    function forceApprove(IERC20 token, address spender, uint256 amount) internal {
        bytes memory callData = abi.encodeWithSelector(token.approve.selector, spender, amount);
        if (!_callOptionalReturnBool(address(token), callData)) {
            _callOptionalReturn(address(token), abi.encodeWithSelector(token.approve.selector, spender, 0));
            _callOptionalReturn(address(token), callData);
        }
    }

    function _callOptionalReturn(address token, bytes memory data) private {
        (bool ok, bytes memory ret) = token.call(data);
        if (!ok || (ret.length != 0 && !abi.decode(ret, (bool)))) revert SafeERC20Failed();
    }

    function _callOptionalReturnBool(address token, bytes memory data) private returns (bool) {
        (bool ok, bytes memory ret) = token.call(data);
        return ok && (ret.length == 0 || abi.decode(ret, (bool)));
    }
}

library ECDSALite {
    error InvalidSignatureLength();
    error InvalidSignatureS();
    error InvalidSignatureV();

    bytes32 private constant HALF_ORDER = 0x7fffffffffffffffffffffffffffffff5d576e7357a4501ddfe92f46681b20a0;

    function recover(bytes32 hash, bytes memory signature) internal pure returns (address) {
        if (signature.length != 65) revert InvalidSignatureLength();
        bytes32 r;
        bytes32 s;
        uint8 v;
        assembly {
            r := mload(add(signature, 0x20))
            s := mload(add(signature, 0x40))
            v := byte(0, mload(add(signature, 0x60)))
        }
        if (uint256(s) > uint256(HALF_ORDER)) revert InvalidSignatureS();
        if (v != 27 && v != 28) revert InvalidSignatureV();
        address signer = ecrecover(hash, v, r, s);
        if (signer == address(0)) revert InvalidSignatureV();
        return signer;
    }
}

contract Ownable2StepLite {
    address private _owner;
    address private _pendingOwner;

    event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    error OwnableUnauthorizedAccount(address account);
    error OwnableInvalidOwner(address owner);

    modifier onlyOwner() {
        if (msg.sender != _owner) revert OwnableUnauthorizedAccount(msg.sender);
        _;
    }

    constructor(address initialOwner) {
        if (initialOwner == address(0)) revert OwnableInvalidOwner(address(0));
        _owner = initialOwner;
        emit OwnershipTransferred(address(0), initialOwner);
    }

    function owner() public view returns (address) { return _owner; }
    function pendingOwner() public view returns (address) { return _pendingOwner; }

    function transferOwnership(address newOwner) public onlyOwner {
        if (newOwner == address(0)) revert OwnableInvalidOwner(address(0));
        _pendingOwner = newOwner;
        emit OwnershipTransferStarted(_owner, newOwner);
    }

    function acceptOwnership() public {
        address sender = msg.sender;
        if (sender != _pendingOwner) revert OwnableUnauthorizedAccount(sender);
        address oldOwner = _owner;
        _owner = sender;
        _pendingOwner = address(0);
        emit OwnershipTransferred(oldOwner, sender);
    }

    function renounceOwnership() public virtual onlyOwner { revert("RENOUNCE_DISABLED"); }
}

abstract contract PausableLite is Ownable2StepLite {
    bool private _paused;
    event Paused(address account);
    event Unpaused(address account);
    error EnforcedPause();
    error ExpectedPause();

    constructor(address initialOwner) Ownable2StepLite(initialOwner) {}

    modifier whenNotPaused() {
        if (_paused) revert EnforcedPause();
        _;
    }

    function paused() public view returns (bool) { return _paused; }
    function _pause() internal { if (_paused) revert EnforcedPause(); _paused = true; emit Paused(msg.sender); }
    function _unpause() internal { if (!_paused) revert ExpectedPause(); _paused = false; emit Unpaused(msg.sender); }
}

abstract contract ReentrancyGuardLite {
    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;
    uint256 private _status = NOT_ENTERED;
    error ReentrancyGuardReentrantCall();

    modifier nonReentrant() {
        if (_status == ENTERED) revert ReentrancyGuardReentrantCall();
        _status = ENTERED;
        _;
        _status = NOT_ENTERED;
    }
}

interface IWrappedNative {
    function deposit() external payable;
    function withdraw(uint256 amount) external;
}

interface IAionexAdapter {
    struct SwapRequest {
        address tokenIn;
        address tokenOut;
        uint256 amountIn;
        uint256 minAmountOut;
        address recipient;
        uint256 deadline;
        bytes data;
    }
    function swap(SwapRequest calldata request) external returns (uint256 amountOut);
}

abstract contract AionexRouterCore is PausableLite, ReentrancyGuardLite {
    using SafeERC20Lite for IERC20;

    uint256 private constant BPS = 10_000;
    uint16 public constant MAX_FEE_BPS = 100;
    uint256 public constant MAX_DEADLINE_WINDOW = 30 minutes;
    uint256 public constant PROTOCOL_VERSION = 40;
    bytes32 public constant AIONEX_TAG = keccak256("MAPLEFI_AIONEX_NATIVE_EXECUTION_V4_NOVIAIR");

    address public immutable wrappedNative;
    address public quoteSigner;
    address public feeRecipient;
    uint16 public feeBps;

    uint256 public totalSwaps;
    uint256 public totalUniqueSwappers;
    uint256 public totalFeesEvents;

    struct AdapterConfig { bool allowed; bytes32 venueId; }
    struct SwapIntent {
        bytes32 quoteId;
        bytes32 intelligenceHash;
        bytes32 campaignTag;
        address adapter;
        address tokenIn;      // address(0) = native asset
        address tokenOut;     // address(0) = native asset
        address recipient;    // must equal msg.sender
        uint256 amountIn;     // gross input before AIONEX fee
        uint256 minAmountOut; // protected final output minimum
        uint256 deadline;
        uint16 expectedFeeBps;
        bytes data;           // adapter-specific route data
    }
    struct ExecData {
        bytes32 routeId;
        address effectiveIn;
        address effectiveOut;
        uint256 grossAmountIn;
        uint256 feeAmount;
        uint256 netAmountIn;
        uint256 amountOut;
    }

    mapping(address => AdapterConfig) public adapters;
    mapping(bytes32 => bool) public routeUsed;
    mapping(address => uint256) public userSwapCount;
    mapping(address => bool) public hasSwapped;
    mapping(address => uint256) public totalFeesCollected;

    error ZeroAddress();
    error WrongChain(uint256 expected, uint256 actual);
    error InvalidFee(uint256 supplied, uint256 maximum);
    error FeeChanged(uint16 expected, uint16 current);
    error InvalidSignature();
    error InvalidRouteId();
    error RouteAlreadyUsed(bytes32 routeId);
    error Expired();
    error DeadlineTooFar();
    error InvalidAmount();
    error InvalidMinimumOutput();
    error InvalidRecipient();
    error InvalidTokenPair();
    error InvalidMsgValue();
    error AdapterNotAllowed(address adapter);
    error TransferTaxInputUnsupported(uint256 requested, uint256 received);
    error TransferTaxOutputUnsupported(uint256 requested, uint256 received);
    error InsufficientOutput(uint256 received, uint256 minimum);
    error OwnershipRenunciationDisabled();
    error RescueOnlyWhilePaused();
    error NativeSendFailed();

    event AionexSwapExecuted(bytes32 indexed routeId, address indexed user, bytes32 indexed quoteId);
    event AionexSwapAssets(bytes32 indexed routeId, address indexed adapter, address tokenIn, address tokenOut);
    event AionexSwapAmounts(bytes32 indexed routeId, uint256 grossAmountIn, uint256 netAmountIn, uint256 amountOut);
    event AionexSwapFee(bytes32 indexed routeId, address indexed feeAsset, uint256 feeAmount, uint16 feeBpsApplied);
    event AionexSwapTag(bytes32 indexed routeId, bytes32 intelligenceHash, bytes32 campaignTag, bytes32 aionexTag);
    event AionexSwapContext(bytes32 indexed routeId, uint256 chainId, uint256 blockNumber, uint256 timestamp);
    event AdapterUpdated(address indexed adapter, bytes32 indexed venueId, bool allowed);
    event FeeBpsUpdated(uint16 previousFeeBps, uint16 newFeeBps);
    event FeeRecipientUpdated(address indexed previousRecipient, address indexed newRecipient);
    event QuoteSignerUpdated(address indexed previousSigner, address indexed newSigner);
    event AssetRescued(address indexed asset, address indexed recipient, uint256 amount);

    constructor(address initialOwner, address initialFeeRecipient, address initialQuoteSigner, address wrappedNative_)
        PausableLite(initialOwner)
    {
        if (initialFeeRecipient == address(0) || initialQuoteSigner == address(0) || wrappedNative_ == address(0)) revert ZeroAddress();
        feeRecipient = initialFeeRecipient;
        quoteSigner = initialQuoteSigner;
        wrappedNative = wrappedNative_;
    }

    receive() external payable { if (msg.sender != wrappedNative) revert InvalidMsgValue(); }

    function expectedChainId() public pure virtual returns (uint256);
    function venueIdForName(string calldata venueName) external pure returns (bytes32) { return keccak256(bytes(venueName)); }
    function computeRouteId(address user, bytes32 quoteId) public view returns (bytes32) { return keccak256(abi.encode(AIONEX_TAG, block.chainid, address(this), user, quoteId)); }

    function executeSwap(SwapIntent calldata intent, bytes calldata quoteSignature)
        external payable nonReentrant whenNotPaused returns (uint256 amountOut)
    {
        bytes32 routeId = _validateAndUse(intent, quoteSignature);
        ExecData memory ex;
        ex.routeId = routeId;
        _runExecution(intent, ex);
        return ex.amountOut;
    }

    function _validateAndUse(SwapIntent calldata intent, bytes calldata quoteSignature) private returns (bytes32 routeId) {
        routeId = computeRouteId(msg.sender, intent.quoteId);
        _validateBasics(intent, routeId);
        _validateSignature(intent, quoteSignature);
        routeUsed[routeId] = true;
    }

    function _validateBasics(SwapIntent calldata intent, bytes32 routeId) private view {
        uint256 chainId = expectedChainId();
        if (block.chainid != chainId) revert WrongChain(chainId, block.chainid);
        if (intent.quoteId == bytes32(0) || intent.intelligenceHash == bytes32(0)) revert InvalidRouteId();
        if (routeUsed[routeId]) revert RouteAlreadyUsed(routeId);
        if (intent.recipient != msg.sender) revert InvalidRecipient();
        if (intent.amountIn == 0) revert InvalidAmount();
        if (intent.minAmountOut == 0) revert InvalidMinimumOutput();
        if (intent.tokenIn == intent.tokenOut) revert InvalidTokenPair();
        if (intent.expectedFeeBps != feeBps) revert FeeChanged(intent.expectedFeeBps, feeBps);
        if (block.timestamp > intent.deadline) revert Expired();
        if (intent.deadline > block.timestamp + MAX_DEADLINE_WINDOW) revert DeadlineTooFar();
        if (!adapters[intent.adapter].allowed) revert AdapterNotAllowed(intent.adapter);
    }

    function quoteDigest(address user, SwapIntent calldata intent) public view returns (bytes32) {
        return _ethSignedHash(_rawQuoteDigest(user, intent));
    }

    function _validateSignature(SwapIntent calldata intent, bytes calldata sig) private view {
        if (ECDSALite.recover(quoteDigest(msg.sender, intent), sig) != quoteSigner) revert InvalidSignature();
    }

    function _rawQuoteDigest(address user, SwapIntent calldata intent) private view returns (bytes32) {
        bytes32 assetHash = keccak256(abi.encode(intent.adapter, intent.tokenIn, intent.tokenOut, intent.recipient));
        bytes32 amountHash = keccak256(abi.encode(intent.amountIn, intent.minAmountOut, intent.deadline, intent.expectedFeeBps));
        return keccak256(abi.encode(AIONEX_TAG, block.chainid, address(this), user, intent.quoteId, assetHash, amountHash, intent.intelligenceHash, intent.campaignTag, keccak256(intent.data)));
    }

    function _ethSignedHash(bytes32 rawHash) private pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", rawHash));
    }

    function _runExecution(SwapIntent calldata intent, ExecData memory ex) private {
        ex.effectiveIn = _effectiveAsset(intent.tokenIn);
        ex.effectiveOut = _effectiveAsset(intent.tokenOut);
        _collectInputAndFee(intent, ex);
        _executeAdapter(intent, ex);
        if (ex.amountOut < intent.minAmountOut) revert InsufficientOutput(ex.amountOut, intent.minAmountOut);
        _settleOutput(intent.recipient, intent.tokenOut, ex.effectiveOut, ex.amountOut);
        _recordStats(msg.sender, ex.effectiveIn, ex.feeAmount);
        _emitTelemetry(intent, ex);
    }

    function _effectiveAsset(address token) private view returns (address) {
        return token == address(0) ? wrappedNative : token;
    }

    function _collectInputAndFee(SwapIntent calldata intent, ExecData memory ex) private {
        if (intent.tokenIn == address(0)) {
            if (msg.value != intent.amountIn) revert InvalidMsgValue();
            IWrappedNative(wrappedNative).deposit{value: msg.value}();
            ex.grossAmountIn = intent.amountIn;
        } else {
            if (msg.value != 0) revert InvalidMsgValue();
            _pullERC20Input(intent.amountIn, ex);
        }
        ex.feeAmount = (ex.grossAmountIn * feeBps) / BPS;
        ex.netAmountIn = ex.grossAmountIn - ex.feeAmount;
        if (ex.netAmountIn == 0) revert InvalidAmount();
        if (ex.feeAmount != 0) IERC20(ex.effectiveIn).safeTransfer(feeRecipient, ex.feeAmount);
    }

    function _pullERC20Input(uint256 amountIn, ExecData memory ex) private {
        IERC20 input = IERC20(ex.effectiveIn);
        uint256 beforeBal = input.balanceOf(address(this));
        input.safeTransferFrom(msg.sender, address(this), amountIn);
        ex.grossAmountIn = input.balanceOf(address(this)) - beforeBal;
        if (ex.grossAmountIn != amountIn) revert TransferTaxInputUnsupported(amountIn, ex.grossAmountIn);
    }

    function _executeAdapter(SwapIntent calldata intent, ExecData memory ex) private {
        IERC20(ex.effectiveIn).forceApprove(intent.adapter, ex.netAmountIn);
        uint256 beforeOut = IERC20(ex.effectiveOut).balanceOf(address(this));
        _callAdapter(intent, ex);
        IERC20(ex.effectiveIn).forceApprove(intent.adapter, 0);
        ex.amountOut = IERC20(ex.effectiveOut).balanceOf(address(this)) - beforeOut;
    }

    function _callAdapter(SwapIntent calldata intent, ExecData memory ex) private {
        IAionexAdapter.SwapRequest memory request;
        request.tokenIn = ex.effectiveIn;
        request.tokenOut = ex.effectiveOut;
        request.amountIn = ex.netAmountIn;
        request.minAmountOut = intent.minAmountOut;
        request.recipient = address(this);
        request.deadline = intent.deadline;
        request.data = intent.data;
        IAionexAdapter(intent.adapter).swap(request);
    }

    function _settleOutput(address recipient, address tokenOut, address effectiveOut, uint256 amountOut) private {
        if (tokenOut == address(0)) {
            IWrappedNative(wrappedNative).withdraw(amountOut);
            (bool ok,) = payable(recipient).call{value: amountOut}("");
            if (!ok) revert NativeSendFailed();
        } else {
            IERC20 output = IERC20(effectiveOut);
            uint256 beforeRecipient = output.balanceOf(recipient);
            output.safeTransfer(recipient, amountOut);
            uint256 received = output.balanceOf(recipient) - beforeRecipient;
            if (received != amountOut) revert TransferTaxOutputUnsupported(amountOut, received);
        }
    }

    function _recordStats(address user, address feeAsset, uint256 feeAmount) private {
        totalSwaps += 1;
        userSwapCount[user] += 1;
        if (!hasSwapped[user]) { hasSwapped[user] = true; totalUniqueSwappers += 1; }
        if (feeAmount != 0) { totalFeesCollected[feeAsset] += feeAmount; totalFeesEvents += 1; }
    }

    function _emitTelemetry(SwapIntent calldata intent, ExecData memory ex) private {
        _emitCore(ex.routeId, msg.sender, intent.quoteId);
        _emitAssets(ex.routeId, intent.adapter, intent.tokenIn, intent.tokenOut);
        _emitAmounts(ex.routeId, ex.grossAmountIn, ex.netAmountIn, ex.amountOut);
        _emitFee(ex.routeId, ex.effectiveIn, ex.feeAmount);
        _emitTag(ex.routeId, intent.intelligenceHash, intent.campaignTag);
        emit AionexSwapContext(ex.routeId, block.chainid, block.number, block.timestamp);
    }

    function _emitCore(bytes32 routeId, address user, bytes32 quoteId) private { emit AionexSwapExecuted(routeId, user, quoteId); }
    function _emitAssets(bytes32 routeId, address adapter, address tokenIn, address tokenOut) private { emit AionexSwapAssets(routeId, adapter, tokenIn, tokenOut); }
    function _emitAmounts(bytes32 routeId, uint256 grossAmountIn, uint256 netAmountIn, uint256 amountOut) private { emit AionexSwapAmounts(routeId, grossAmountIn, netAmountIn, amountOut); }
    function _emitFee(bytes32 routeId, address feeAsset, uint256 feeAmount) private { emit AionexSwapFee(routeId, feeAsset, feeAmount, feeBps); }
    function _emitTag(bytes32 routeId, bytes32 intelligenceHash, bytes32 campaignTag) private { emit AionexSwapTag(routeId, intelligenceHash, campaignTag, AIONEX_TAG); }

    function setFeeBps(uint16 newFeeBps) external onlyOwner {
        if (newFeeBps > MAX_FEE_BPS) revert InvalidFee(newFeeBps, MAX_FEE_BPS);
        uint16 old = feeBps;
        feeBps = newFeeBps;
        emit FeeBpsUpdated(old, newFeeBps);
    }

    function setFeeRecipient(address newRecipient) external onlyOwner {
        if (newRecipient == address(0) || newRecipient == address(this)) revert ZeroAddress();
        address old = feeRecipient;
        feeRecipient = newRecipient;
        emit FeeRecipientUpdated(old, newRecipient);
    }

    function setQuoteSigner(address newSigner) external onlyOwner {
        if (newSigner == address(0)) revert ZeroAddress();
        address old = quoteSigner;
        quoteSigner = newSigner;
        emit QuoteSignerUpdated(old, newSigner);
    }

    function setAdapter(address adapter, bytes32 venueId, bool allowed) public onlyOwner {
        if (adapter == address(0) || venueId == bytes32(0)) revert ZeroAddress();
        if (allowed && adapter.code.length == 0) revert ZeroAddress();
        adapters[adapter] = AdapterConfig({allowed: allowed, venueId: venueId});
        emit AdapterUpdated(adapter, venueId, allowed);
    }

    function setAdapterByName(address adapter, string calldata venueName, bool allowed) external onlyOwner {
        setAdapter(adapter, keccak256(bytes(venueName)), allowed);
    }

    function pause() external onlyOwner { _pause(); }
    function unpause() external onlyOwner { _unpause(); }

    function rescueToken(address token, address recipient, uint256 amount) external onlyOwner {
        if (!paused()) revert RescueOnlyWhilePaused();
        if (token == address(0) || recipient == address(0)) revert ZeroAddress();
        IERC20(token).safeTransfer(recipient, amount);
        emit AssetRescued(token, recipient, amount);
    }

    function rescueNative(address recipient, uint256 amount) external onlyOwner {
        if (!paused()) revert RescueOnlyWhilePaused();
        if (recipient == address(0)) revert ZeroAddress();
        (bool ok,) = payable(recipient).call{value: amount}("");
        if (!ok) revert NativeSendFailed();
        emit AssetRescued(address(0), recipient, amount);
    }

    function renounceOwnership() public view override onlyOwner { revert OwnershipRenunciationDisabled(); }
}

interface IAerodromeRouterLike {
    struct Route { address from; address to; bool stable; address factory; }
    function swapExactTokensForTokens(uint256 amountIn, uint256 amountOutMin, Route[] calldata routes, address to, uint256 deadline) external returns (uint256[] memory amounts);
}

contract AionexAerodromeAdapter is IAionexAdapter {
    using SafeERC20Lite for IERC20;
    address public immutable aionexRouter;
    address public immutable dexRouter;
    address public immutable poolFactory;
    error OnlyAionexRouter(); error InvalidPath(); error ZeroAddress(); error InsufficientOutput(uint256 received, uint256 minimum);

    constructor(address aionexRouter_, address dexRouter_, address poolFactory_) {
        if (aionexRouter_ == address(0) || dexRouter_ == address(0) || poolFactory_ == address(0)) revert ZeroAddress();
        aionexRouter = aionexRouter_; dexRouter = dexRouter_; poolFactory = poolFactory_;
    }

    function swap(SwapRequest calldata request) external returns (uint256 amountOut) {
        if (msg.sender != aionexRouter) revert OnlyAionexRouter();
        IAerodromeRouterLike.Route[] memory routes = abi.decode(request.data, (IAerodromeRouterLike.Route[]));
        _validateRoute(request, routes);
        IERC20(request.tokenIn).safeTransferFrom(msg.sender, address(this), request.amountIn);
        IERC20(request.tokenIn).forceApprove(dexRouter, request.amountIn);
        uint256 beforeOut = IERC20(request.tokenOut).balanceOf(request.recipient);
        IAerodromeRouterLike(dexRouter).swapExactTokensForTokens(request.amountIn, request.minAmountOut, routes, request.recipient, request.deadline);
        IERC20(request.tokenIn).forceApprove(dexRouter, 0);
        amountOut = IERC20(request.tokenOut).balanceOf(request.recipient) - beforeOut;
        if (amountOut < request.minAmountOut) revert InsufficientOutput(amountOut, request.minAmountOut);
    }

    function _validateRoute(SwapRequest calldata request, IAerodromeRouterLike.Route[] memory routes) private view {
        if (routes.length != 1) revert InvalidPath();
        IAerodromeRouterLike.Route memory route = routes[0];
        if (route.from != request.tokenIn || route.to != request.tokenOut || route.factory != poolFactory) revert InvalidPath();
    }
}

interface IV2LikeRouter {
    function swapExactTokensForTokens(uint256 amountIn, uint256 amountOutMin, address[] calldata path, address to, uint256 deadline) external returns (uint256[] memory amounts);
}

contract AionexV2Adapter is IAionexAdapter {
    using SafeERC20Lite for IERC20;
    address public immutable aionexRouter;
    address public immutable dexRouter;
    error OnlyAionexRouter(); error InvalidPath(); error ZeroAddress(); error InsufficientOutput(uint256 received, uint256 minimum);

    constructor(address aionexRouter_, address dexRouter_) {
        if (aionexRouter_ == address(0) || dexRouter_ == address(0)) revert ZeroAddress();
        aionexRouter = aionexRouter_; dexRouter = dexRouter_;
    }

    function swap(SwapRequest calldata request) external returns (uint256 amountOut) {
        if (msg.sender != aionexRouter) revert OnlyAionexRouter();
        address[] memory path = abi.decode(request.data, (address[]));
        if (path.length != 2 || path[0] != request.tokenIn || path[1] != request.tokenOut) revert InvalidPath();
        IERC20(request.tokenIn).safeTransferFrom(msg.sender, address(this), request.amountIn);
        IERC20(request.tokenIn).forceApprove(dexRouter, request.amountIn);
        uint256 beforeOut = IERC20(request.tokenOut).balanceOf(request.recipient);
        IV2LikeRouter(dexRouter).swapExactTokensForTokens(request.amountIn, request.minAmountOut, path, request.recipient, request.deadline);
        IERC20(request.tokenIn).forceApprove(dexRouter, 0);
        amountOut = IERC20(request.tokenOut).balanceOf(request.recipient) - beforeOut;
        if (amountOut < request.minAmountOut) revert InsufficientOutput(amountOut, request.minAmountOut);
    }
}

interface IV3SwapRouter02Like {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }
    function exactInputSingle(ExactInputSingleParams calldata params) external payable returns (uint256 amountOut);
}

contract AionexV3SwapRouter02Adapter is IAionexAdapter {
    using SafeERC20Lite for IERC20;
    address public immutable aionexRouter;
    address public immutable dexRouter;
    error OnlyAionexRouter(); error ZeroAddress(); error InvalidFeeTier(); error InsufficientOutput(uint256 received, uint256 minimum);

    constructor(address aionexRouter_, address dexRouter_) {
        if (aionexRouter_ == address(0) || dexRouter_ == address(0)) revert ZeroAddress();
        aionexRouter = aionexRouter_; dexRouter = dexRouter_;
    }

    function swap(SwapRequest calldata request) external returns (uint256 amountOut) {
        if (msg.sender != aionexRouter) revert OnlyAionexRouter();
        (uint24 fee, uint160 limit) = abi.decode(request.data, (uint24, uint160));
        if (fee == 0 || fee > 1_000_000) revert InvalidFeeTier();
        IERC20(request.tokenIn).safeTransferFrom(msg.sender, address(this), request.amountIn);
        IERC20(request.tokenIn).forceApprove(dexRouter, request.amountIn);
        IV3SwapRouter02Like.ExactInputSingleParams memory p;
        p.tokenIn = request.tokenIn;
        p.tokenOut = request.tokenOut;
        p.fee = fee;
        p.recipient = request.recipient;
        p.amountIn = request.amountIn;
        p.amountOutMinimum = request.minAmountOut;
        p.sqrtPriceLimitX96 = limit;
        amountOut = IV3SwapRouter02Like(dexRouter).exactInputSingle(p);
        IERC20(request.tokenIn).forceApprove(dexRouter, 0);
        if (amountOut < request.minAmountOut) revert InsufficientOutput(amountOut, request.minAmountOut);
    }
}

interface IPancakeV3SwapRouterLike {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }
    function exactInputSingle(ExactInputSingleParams calldata params) external payable returns (uint256 amountOut);
}

contract AionexPancakeV3Adapter is IAionexAdapter {
    using SafeERC20Lite for IERC20;
    address public immutable aionexRouter;
    address public immutable dexRouter;
    error OnlyAionexRouter(); error ZeroAddress(); error InvalidFeeTier(); error InsufficientOutput(uint256 received, uint256 minimum);

    constructor(address aionexRouter_, address dexRouter_) {
        if (aionexRouter_ == address(0) || dexRouter_ == address(0)) revert ZeroAddress();
        aionexRouter = aionexRouter_; dexRouter = dexRouter_;
    }

    function swap(SwapRequest calldata request) external returns (uint256 amountOut) {
        if (msg.sender != aionexRouter) revert OnlyAionexRouter();
        (uint24 fee, uint160 limit) = abi.decode(request.data, (uint24, uint160));
        if (fee == 0 || fee > 1_000_000) revert InvalidFeeTier();
        IERC20(request.tokenIn).safeTransferFrom(msg.sender, address(this), request.amountIn);
        IERC20(request.tokenIn).forceApprove(dexRouter, request.amountIn);
        IPancakeV3SwapRouterLike.ExactInputSingleParams memory p;
        p.tokenIn = request.tokenIn;
        p.tokenOut = request.tokenOut;
        p.fee = fee;
        p.recipient = request.recipient;
        p.deadline = request.deadline;
        p.amountIn = request.amountIn;
        p.amountOutMinimum = request.minAmountOut;
        p.sqrtPriceLimitX96 = limit;
        amountOut = IPancakeV3SwapRouterLike(dexRouter).exactInputSingle(p);
        IERC20(request.tokenIn).forceApprove(dexRouter, 0);
        if (amountOut < request.minAmountOut) revert InsufficientOutput(amountOut, request.minAmountOut);
    }
}

contract AionexBaseRouter is AionexRouterCore {
    address public constant BASE_WETH = address(0x4200000000000000000000000000000000000006);
    constructor(address initialOwner, address initialFeeRecipient, address initialQuoteSigner)
        AionexRouterCore(initialOwner, initialFeeRecipient, initialQuoteSigner, BASE_WETH) {}
    function expectedChainId() public pure override returns (uint256) { return 8453; }
}

contract AionexBnbRouter is AionexRouterCore {
    address public constant WBNB = address(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
    constructor(address initialOwner, address initialFeeRecipient, address initialQuoteSigner)
        AionexRouterCore(initialOwner, initialFeeRecipient, initialQuoteSigner, WBNB) {}
    function expectedChainId() public pure override returns (uint256) { return 56; }
}

contract AionexBaseAerodromeAdapter is AionexAerodromeAdapter {
    address public constant AERODROME_ROUTER = address(0xcF77a3Ba9A5CA399B7c97c74d54e5b1Beb874E43);
    address public constant AERODROME_FACTORY = address(0x420DD381b31aEf6683db6B902084cB0FFECe40Da);
    constructor(address aionexRouter_) AionexAerodromeAdapter(aionexRouter_, AERODROME_ROUTER, AERODROME_FACTORY) {}
}

contract AionexBaseUniswapV3Adapter is AionexV3SwapRouter02Adapter {
    address public constant UNISWAP_V3_SWAP_ROUTER_02 = address(0x2626664c2603336E57B271c5C0b26F421741e481);
    constructor(address aionexRouter_) AionexV3SwapRouter02Adapter(aionexRouter_, UNISWAP_V3_SWAP_ROUTER_02) {}
}

contract AionexBnbPancakeV2Adapter is AionexV2Adapter {
    address public constant PANCAKE_V2_ROUTER = address(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    constructor(address aionexRouter_) AionexV2Adapter(aionexRouter_, PANCAKE_V2_ROUTER) {}
}

contract AionexBnbPancakeV3Adapter is AionexPancakeV3Adapter {
    address public constant PANCAKE_V3_SWAP_ROUTER = address(0x1b81D678ffb9C0263b24A97847620C99d213eB14);
    constructor(address aionexRouter_) AionexPancakeV3Adapter(aionexRouter_, PANCAKE_V3_SWAP_ROUTER) {}
}

contract AionexBnbUniswapV3Adapter is AionexV3SwapRouter02Adapter {
    address public constant UNISWAP_V3_SWAP_ROUTER_02 = address(0xB971eF87ede563556b2ED4b1C0b0019111Dd85d2);
    constructor(address aionexRouter_) AionexV3SwapRouter02Adapter(aionexRouter_, UNISWAP_V3_SWAP_ROUTER_02) {}
}
