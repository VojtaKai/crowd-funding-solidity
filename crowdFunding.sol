// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.5.0 <0.9.0;

contract Campaign {
    uint public monetaryGoal;
    uint public deadLine;
    uint public totalAssets;
    address payable public admin;
    mapping(address => uint) public contributors;
    address[] public uniqueContributors;
    mapping (string => SpendingRequest) public requests;
    mapping(string => uint) public requestUpvotes;

    event ContributeEvent(address _sender, uint _value);
    event CreateSpendingRequestEvent(string _name, uint _moneyRequested);
    event SpendMoneyEvent(address recipient, string _spendingRequestName, uint _moneyRequested);

    constructor(uint _monetaryGoal, uint _deadLine) {
        monetaryGoal = _monetaryGoal;
        deadLine = block.timestamp + _deadLine;
        admin = payable(msg.sender);
    }

    modifier onlyAdmin() {
        require(msg.sender == admin);
        _;
    }

    modifier exceptAdmin() {
        require(msg.sender != admin);
        _;
    }

    modifier beforeDeadline() {
        require(block.timestamp < deadLine, 'Times up. Deadline has passed.');
        _;
    }

    modifier goalNotMet() {
        require(totalAssets < monetaryGoal, 'Crowdfundign goal has been reached.');
        _;
    }

    modifier timesUp() {
        require(block.timestamp >= deadLine, 'Crowdfunding still active. Deadline hasnt passed yet.');
        _;
    }

    function getContributorLength() public view returns(uint) {
        return uniqueContributors.length;
    }

    function hasMajority(string memory spendingRequestName) public view returns(bool) {
        return getVotes(spendingRequestName) >= (getContributorLength() / 2);
    }

    function getVotes(string memory spendingRequestName) public view returns(uint) {
        return requestUpvotes[spendingRequestName];
    }

    function spendMoney(string memory spendingRequestName) public onlyAdmin {
        require(totalAssets >= monetaryGoal, 'Goal hasnt been reached.');
        require(hasMajority(spendingRequestName) == true, 'spending request hasnt been permitted by contributors');
        require(totalAssets >= requests[spendingRequestName].getMoneyRequested(), 'Total raised assets are not enough to make this payment');
        require(requests[spendingRequestName].complete() == false, 'Money has already been paid out');

        totalAssets -= requests[spendingRequestName].getMoneyRequested();
        requests[spendingRequestName].setComplete();
        requests[spendingRequestName].getRecipient().transfer(requests[spendingRequestName].getMoneyRequested());

        emit SpendMoneyEvent(requests[spendingRequestName].getRecipient(), spendingRequestName, requests[spendingRequestName].getMoneyRequested());
    }

    function contribute() public payable exceptAdmin beforeDeadline {
        if (contributors[msg.sender] == 0) {
            uniqueContributors.push(msg.sender);
        }
        contributors[msg.sender] += msg.value;
        totalAssets += msg.value;

        emit ContributeEvent(msg.sender, msg.value);
    }

    receive() payable external {
        contribute();
    }

    function createSpendingRequest(address recipient, string memory requestName, uint _moneyRequested) public onlyAdmin {
        SpendingRequest newRequest = new SpendingRequest(recipient, requestName, _moneyRequested);
        requests[requestName] = newRequest;

        emit CreateSpendingRequestEvent(requestName, _moneyRequested);
    }

    function voteForSpendingRequest(string memory requestName) public exceptAdmin {
        requestUpvotes[requestName] += 1;
    }

    function retrieveFunds() public timesUp goalNotMet {
        require(contributors[msg.sender] > 0, 'You are not a contributer or you already withdrew your funds.');

        address payable recipient = payable(msg.sender);
        uint moneyContribution = contributors[recipient];
        contributors[msg.sender] = 0;
        recipient.transfer(moneyContribution);
        totalAssets -= moneyContribution;
    }
}

contract SpendingRequest {
    string public name;
    address payable public recipient;
    uint public moneyRequested;
    bool public complete;

    constructor(address _recipient, string memory _name, uint _moneyRequested) {
        recipient = payable(_recipient);
        name = _name;
        moneyRequested = _moneyRequested;
        complete = false;
    }

    function getMoneyRequested() public view returns(uint) {
        return moneyRequested;
    }

    function resetMoneyRequested() public {
        moneyRequested = 0;
    }

    function setComplete() public {
        complete = true;
    }

    function getComplete() public view returns(bool) {
        return complete;
    }

    function getRecipient() public view returns(address payable) {
        return recipient;
    }
}