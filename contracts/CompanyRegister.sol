// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IAggregatorV3Interface {
  function latestRoundData()
    external
    view
    returns (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    );
}

contract CompanyRegister is Ownable {
    event CreateCompany(uint256 id, string name);
    event WithdrawRegistrationCharge(address to);
    event DistributeAward(uint256 companyId, uint256 userId, address wallet);
    event RegisterCompany(uint256 companyId, uint256 userId, string name, uint256 mail, address wallet);
    event UpdateUser(uint256 userId, string name, uint256 mail);
    event DeleteUser(uint256 companyId, uint256 userId);

    struct User {
        uint256 id;
        string name;
        uint256 mail;
        address wallet;
    }

    struct Company {
        uint256 id;
        string name;
    }

    address public ethPriceAggregator;

    Company[] private _companies;
    mapping(uint256 => User[]) private _companyUsers;
    mapping(uint256 => uint256) private _companyIdToIndex;
    mapping(uint256 => uint256) private _userIdToCompanyId;
    mapping(uint256 => uint256) private _userIdToIndex;
    uint256 private _companyUniqueId;
    uint256 private _userUniqueId;

    constructor(address _ethPriceAggregator) Ownable() {
        ethPriceAggregator = _ethPriceAggregator;
    }

    function createCompany(string memory name) external onlyOwner {
        _companyUniqueId ++;

        Company memory company;
        company.id = _companyUniqueId;
        company.name = name;
        _companies.push(company);
        _companyIdToIndex[_companyUniqueId] = _companies.length;

        emit CreateCompany(_companyUniqueId, name);
    }

    function withdrawRegistrationCharge(address payable to) external onlyOwner {
        require(address(this).balance != 0, "CR_NO_CHARGE");

        to.transfer(address(this).balance);

        emit WithdrawRegistrationCharge(to);
    }

    function distrbuteAward(uint256 companyId) payable external onlyOwner {
        require(msg.value != 0, "CR_NO_AWARD");
        require(_companyIdToIndex[companyId] != 0, "CR_INVALID_COMPANY_ID");

        User[] memory users = _companyUsers[companyId];
        require(users.length != 0, "CR_NO_COMPANY_USERS");

        uint256 random = _randomNumber();
        uint256 winnerIndex = random % users.length;

        payable(users[winnerIndex].wallet).transfer(msg.value);

        emit DistributeAward(companyId, users[winnerIndex].id, users[winnerIndex].wallet);
    }

    function registerCompany(uint256 companyId, string memory name, uint256 mail) payable external {
        require(_companyIdToIndex[companyId] != 0, "CR_INVALID_COMPANY_ID");
        require(msg.value >= 1 ether, "CR_NOT_ENOUGH_REGISTRATION_CHARGE");

        _userUniqueId ++;
        User[] storage users = _companyUsers[companyId];
        users.push(User(
            _userUniqueId,
            name,
            mail,
            msg.sender
        ));
        _userIdToCompanyId[_userUniqueId] = companyId;
        _userIdToIndex[_userUniqueId] = users.length;

        if (msg.value > 1 ether) {
            // pay back 1 eth
            payable(msg.sender).transfer(msg.value - 1 ether);
        }

        emit RegisterCompany(companyId, _userUniqueId, name, mail, msg.sender);
    }

    function updateUser(uint256 userId, string memory name, uint256 mail) external {
        require(_userIdToCompanyId[userId] != 0, "CR_INVALID_USER_ID");

        User storage user = _companyUsers[_userIdToCompanyId[userId]][_userIdToIndex[userId] - 1];
        require(user.wallet == msg.sender, "CR_INVALID_PERMISSION");

        user.name = name;
        user.mail = mail;

        emit UpdateUser(userId, name, mail);
    }

    function deleteUser(uint256 userId) external {
        require(_userIdToCompanyId[userId] != 0, "CR_INVALID_USER_ID");

        uint256 companyId = _userIdToCompanyId[userId];
        uint256 index = _userIdToIndex[userId];
        User memory user = _companyUsers[companyId][index - 1];
        require(user.wallet == msg.sender, "CR_INVALID_PERMISSION");

        uint256 length = _companyUsers[companyId].length;
        User memory lastUser = _companyUsers[companyId][length - 1];

        _companyUsers[companyId][index - 1] = lastUser;
        _userIdToIndex[lastUser.id] = index;
        _userIdToIndex[user.id] = 0;
        _userIdToCompanyId[user.id] = 0;

        _companyUsers[companyId].pop();

        emit DeleteUser(companyId, userId);
    }

    function getCompany(uint256 companyId) external view returns(uint256 id, string memory name, User[] memory users) {
        require(_companyIdToIndex[companyId] != 0, "CR_INVALID_COMPANY_ID");

        Company memory company = _companies[_companyIdToIndex[companyId]];

        id = company.id;
        name = company.name;
        users = _companyUsers[companyId];
    }

    function getUser(uint256 userId) external view returns (
        uint256 companyId,
        uint256 id,
        string memory name,
        uint256 mail,
        address wallet
    ) {
        require(_userIdToCompanyId[userId] != 0, "CR_INVALID_USER_ID");

        User memory user = _companyUsers[_userIdToCompanyId[userId]][_userIdToIndex[userId] - 1];

        companyId = _userIdToCompanyId[userId];

        id = user.id;
        name = user.name;
        mail = user.mail;
        wallet = user.wallet;
    }

    function getEthPrice() external view returns(uint256) {
        // returns eth price in usd (8 decimals)
        (, int256 price, , ,) = IAggregatorV3Interface(ethPriceAggregator).latestRoundData();

        return uint256(price);
    }

    function _randomNumber() internal view returns (uint256) {
        return uint256(keccak256(abi.encode(block.number, block.timestamp, block.difficulty)));
    }
}
