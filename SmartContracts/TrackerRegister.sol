pragma solidity 0.4.21;
import "./ownable.sol";


contract TrackerRegister is Ownable {

    event NewTracker(uint trackerId, address trackerAddress);

    struct Tracker {
        string company;
    }

    Tracker[] public trackers;  
    mapping(uint => address) public trackerToAddress;

    modifier onlyTracker(uint _trackerId) {
        require(msg.sender == trackerToAddress[_trackerId]);
        _;
    }

    function addTracker(address _trackerAddress, string _company) public onlyOwner {
        uint trackerId = trackers.push(Tracker(_company))-1;
        trackerToAddress[trackerId] = _trackerAddress;
        emit NewTracker(trackerId, _trackerAddress);
    }

    function getTrackerAddress(uint _trackerId) public view returns(address) {
        return trackerToAddress[_trackerId];
    }
}