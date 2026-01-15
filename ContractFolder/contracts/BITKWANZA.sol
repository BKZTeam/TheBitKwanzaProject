// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/* ---------------- OPENZEPPELIN DEPENDENCIES ---------------- */

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

/**
 * @dev Provides information about the current execution context.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }
    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

/**
 * @dev Implementation of the {IERC20} interface.
 */
contract ERC20 is Context, IERC20 {
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalSupply;
    string private _name;
    string private _symbol;

    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    function name() public view virtual returns (string memory) {
        return _name;
    }

    function symbol() public view virtual returns (string memory) {
        return _symbol;
    }

    function decimals() public view virtual returns (uint8) {
        return 18;
    }

    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }

    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        _transfer(_msgSender(), to, amount);
        return true;
    }

    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual override returns (bool) {
        _spendAllowance(from, _msgSender(), amount);
        _transfer(from, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal virtual {
        _beforeTokenTransfer(from, to, amount);

        uint256 fromBalance = _balances[from];
        require(fromBalance >= amount, "ERC20: transfer amount exceeds balance");
        unchecked {
            _balances[from] = fromBalance - amount;
            _balances[to] += amount;
        }

        emit Transfer(from, to, amount);

        _afterTokenTransfer(from, to, amount);
    }

    function _mint(address account, uint256 amount) internal virtual {
        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply += amount;
        _balances[account] += amount;
        emit Transfer(address(0), account, amount);

        _afterTokenTransfer(address(0), account, amount);
    }

    function _burn(address account, uint256 amount) internal virtual {
        _beforeTokenTransfer(account, address(0), amount);

        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        unchecked {
            _balances[account] = accountBalance - amount;
            _totalSupply -= amount;
        }

        emit Transfer(account, address(0), amount);

        _afterTokenTransfer(account, address(0), amount);
    }

    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        require(owner != address(0), "ERC20: approve from zero address");
        require(spender != address(0), "ERC20: approve to zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _spendAllowance(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "ERC20: insufficient allowance");
            unchecked {
                _approve(owner, spender, currentAllowance - amount);
            }
        }
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual {}
    function _afterTokenTransfer(address from, address to, uint256 amount) internal virtual {}
}

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 */
abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor(address initialOwner) {
        _transferOwnership(initialOwner);
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is zero address");
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

/* ---------------- INTERFACES -------------------- */
interface IERC20Extended {
    function transfer(address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

/* ---------------- BITKWANZA --------------------- */
contract BITKWANZA is ERC20, Ownable {
    uint256 public constant MAX_SUPPLY = 1_000_000_000 * 10**18;
    uint256 public constant MAX_FEE_BP = 250; // 2.5%
    uint256 public foundingFeeBP = 5;        // 0.005%
    uint256 public rewardFeeBP = 1;          // 0.00005%
    uint256 public treasuryFeeBP = 100;      // 1%
    bool public feesEnabled = true;

    address public foundingWallet;
    address public treasuryWallet;
    DividendVault public vault;
    mapping(address => bool) public isFeeExempt;

    constructor(
        address _foundingWallet,
        address _treasuryWallet
    ) ERC20("BITKWANZA", "BKZ") Ownable(msg.sender) {
        foundingWallet = _foundingWallet;
        treasuryWallet = _treasuryWallet;
        vault = new DividendVault(address(this), _treasuryWallet);
        _mint(msg.sender, MAX_SUPPLY);
        isFeeExempt[msg.sender] = true;
        isFeeExempt[address(this)] = true;
    }

    /* ---------------- ADMIN ---------------- */
    function setFeesEnabled(bool enabled) external onlyOwner {
        feesEnabled = enabled;
    }

    function setFeeExempt(address account, bool exempt) external onlyOwner {
        isFeeExempt[account] = exempt;
    }

    function setFoundingWallet(address wallet) external onlyOwner {
        foundingWallet = wallet;
    }

    function setTreasuryWallet(address wallet) external onlyOwner {
        treasuryWallet = wallet;
    }

    /* ---------------- TRANSFER LOGIC ---------------- */
    function _update(
        address from,
        address to,
        uint256 amount
    ) internal virtual {
        // mint / burn bypass
        if (from == address(0) || to == address(0)) {
            _transfer(from, to, amount);
            return;
        }

        if (!feesEnabled || isFeeExempt[from] || isFeeExempt[to]) {
            _transfer(from, to, amount);
            return;
        }

        uint256 totalFeeBP = foundingFeeBP + rewardFeeBP + treasuryFeeBP;
        require(totalFeeBP <= MAX_FEE_BP, "Fee cap exceeded");

        uint256 feeFounding = (amount * foundingFeeBP) / 10_000;
        uint256 feeReward = (amount * rewardFeeBP) / 10_000;
        uint256 feeTreasury = (amount * treasuryFeeBP) / 10_000;
        uint256 netAmount = amount - feeFounding - feeReward - feeTreasury;

        _transfer(from, to, netAmount);
        _transfer(from, foundingWallet, feeFounding);
        _transfer(from, treasuryWallet, feeTreasury);
        _transfer(from, address(vault), feeReward);

        vault.updateHolderShare(from, to);
    }
}

/* ---------------- DIVIDEND VAULT ---------------- */
contract DividendVault is Ownable {
    ERC20 public immutable token;
    address public treasury;

    struct Holder {
        uint256 lastClaim;
        uint256 totalClaimed;
    }

    mapping(address => Holder) public holders;
    address[] public holderList;
    uint256 public rewardPool;
    IERC20Extended public payoutToken;

    event Claim(address indexed user, uint256 amount);

    constructor(
        address tokenAddress,
        address treasuryAddress
    ) Ownable(msg.sender) {
        token = ERC20(tokenAddress);
        treasury = treasuryAddress;
        payoutToken = IERC20Extended(tokenAddress);
    }

    /* ---------------- HOLDER TRACKING ---------------- */
    function updateHolderShare(address from, address to) external {
        require(msg.sender == address(token), "Only token");

        if (from != address(0) && holders[from].lastClaim == 0) {
            holderList.push(from);
        }
        if (to != address(0) && holders[to].lastClaim == 0) {
            holderList.push(to);
        }

        rewardPool = token.balanceOf(address(this));
    }

    /* ---------------- CLAIM LOGIC ---------------- */
    function claim() external {
        _claim(msg.sender);
    }

    function autoClaimAll(uint256 batchSize) external {
        uint256 len = holderList.length;
        uint256 processed;
        for (uint256 i; i < len && processed < batchSize; i++) {
            _claim(holderList[i]);
            processed++;
        }
    }

    function _claim(address user) internal {
        uint256 balance = token.balanceOf(user);
        if (balance == 0 || rewardPool == 0) return;

        uint256 share = (rewardPool * balance) / token.totalSupply();
        if (share == 0) return;

        holders[user].totalClaimed += share;
        holders[user].lastClaim = block.timestamp;
        rewardPool -= share;

        payoutToken.transfer(user, share);
        emit Claim(user, share);
    }

    /* ---------------- TREASURY STRATEGY ---------------- */
    function executeBuyback(uint256 amount) external onlyOwner {
        require(amount <= token.balanceOf(treasury), "Insufficient treasury");
        token.transferFrom(treasury, address(this), amount);
        token.transfer(address(0), amount); // burn
    }

    function setPayoutToken(address tokenAddress) external onlyOwner {
        payoutToken = IERC20Extended(tokenAddress);
    }

    /* ---------------- VIEW ---------------- */
    function holdersCount() external view returns (uint256) {
        return holderList.length;
    }
}
