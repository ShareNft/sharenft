// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./ERC721A.sol";

contract ShareNFT is Ownable, Initializable, ERC721A {
    using SafeMath for uint256;
    using Address for address;
    using Strings for uint256;

    enum Status {
        Waiting,
        Started,
        Finished
    }

    string public baseURI;
    uint256 public constant PRICE = 0.2 * 10 ** 18;
    uint256 public constant SECOND_PHASE_PRICE = 10000 * 1e18;

    Status public _phase1Status;
    Status public _phase2Status;
    uint256 public _phase1Supply = 3000;
    uint256 public _phase2Supply = 2000;
    uint256 constant public PHASE_1_MAX_MINT_PER_WALLET = 20;

    IERC20 public _paymentToken;

    mapping(uint256 => uint256) private _tokenIdLevel;

    mapping(address => bool) public _minters;

    event Minted(address minter, uint256 amount);
    event Phase1StatusChanged(Status status);
    event Phase2StatusChanged(Status status);
    event BaseURIChanged(string newBaseURI);

    constructor(string memory initBaseURI) ERC721A("ShareNFT", "ShareNFT") {
        baseURI = initBaseURI;
        _minters[msg.sender] = true;
    }
    //
    //    function initialize(string memory initBaseURI) initializer public {
    //        __ERC721_init("ShareNFT", "ShareNFT");
    //        baseURI = initBaseURI;
    //        _minters[msg.sender] = true;
    //    }

    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        if (!_exists(tokenId)) revert URIQueryForNonexistentToken();
        uint256 nftLevel = tokenLevel(tokenId);
        if (nftLevel <= 0) {
            nftLevel = 1;
        }
        return bytes(baseURI).length != 0 ? string(abi.encodePacked(_baseURI(), nftLevel.toString())) : '';
    }

    function tokenLevel(uint256 tokenId) public view returns (uint256) {
        uint256 nftLevel = _tokenIdLevel[tokenId];
        if (nftLevel <= 0) {
            nftLevel = 1;
        }
        return nftLevel;
    }

    function mint(uint256 _level, address _to) public {
        require(_minters[msg.sender], "ShareNFT: no minter");
        _safeMint(_to, 1);
        _tokenIdLevel[totalSupply().sub(1)] = _level;
        emit Minted(_to, 1);
    }

    function mint1(uint256 quantity) external payable {
        require(_phase1Status == Status.Started, "ShareNFT: Phase1 no start");
        require(tx.origin == msg.sender, "ShareNFT: Not allow contract");
        require(_phase1Supply.sub(quantity) >= 0, "ShareNFT: Insufficient quantity left");
        require(
            numberMinted(msg.sender).add(quantity) <= PHASE_1_MAX_MINT_PER_WALLET,
            string(abi.encodePacked("ShareNFT: numberMinted must less than ", PHASE_1_MAX_MINT_PER_WALLET.toString()))
        );

        _safeMint(msg.sender, quantity);
        refundIfOver(PRICE * quantity);

        _phase1Supply = _phase1Supply.sub(quantity);
        emit Minted(msg.sender, quantity);
    }

    function mint2(uint256 quantity) external payable {
        require(_phase2Status == Status.Started, "ShareNFT: phase2 no start");
        require(tx.origin == msg.sender, "ShareNFT: Not allow contract");
        require(_phase2Supply.sub(quantity) >= 0, "ShareNFT: Insufficient quantity left");

        _paymentToken.transferFrom(msg.sender, address(this), SECOND_PHASE_PRICE.mul(quantity));

        _safeMint(msg.sender, quantity);

        _phase2Supply = _phase2Supply.sub(quantity);
        emit Minted(msg.sender, quantity);
    }

    function numberMinted(address owner) public view returns (uint256) {
        return _numberMinted(owner);
    }

    function refundIfOver(uint256 price) private {
        require(msg.value >= price, "ShareNFT: BNB no enough");
        if (msg.value > price) {
            payable(msg.sender).transfer(msg.value - price);
        }
    }

    function setPhase1Status(Status _status) external onlyOwner {
        _phase1Status = _status;
        emit Phase1StatusChanged(_phase1Status);
    }

    function setPhase2Status(Status _status) external onlyOwner {
        _phase2Status = _status;
        emit Phase2StatusChanged(_phase2Status);
    }

    function setBaseURI(string calldata newBaseURI) external onlyOwner {
        baseURI = newBaseURI;
        emit BaseURIChanged(newBaseURI);
    }

    function withdraw(address payable recipient) external onlyOwner {
        uint256 balance = address(this).balance;
        (bool success,) = recipient.call{value : balance}("");
        require(success, "ShareNFT: withdraw failed.");
    }

    function setPaymentToken(address _tokenAddr) external onlyOwner {
        _paymentToken = IERC20(_tokenAddr);
    }

    function updateMinter(address _minter, bool _bool) public onlyOwner {
        _minters[_minter] = _bool;
    }
}
