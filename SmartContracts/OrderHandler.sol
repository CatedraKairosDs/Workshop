pragma solidity ^0.4.21;
import "./ownable.sol";
import "./MedRegulator.sol";
import "./PharRegulator.sol";
import "./TrackerRegister.sol";
import "./recetasHandler.sol";
//contract  PharRegulatorInterface {
//    function getPharmacyAddress(uint _pharId) public view returns (address pharAddress);
//}
//contract MedRegulatorInterface {
//    function getLabAddress(uint _labId) public view returns (address labAddress);
//    function getMedData(uint _medId) public view returns (bytes32 medData);
//    function getMedDocu(uint _medId) public view returns (bytes32 medDocu);
//    function getMedPrice(uint _medId) public view returns (bytes32 price);
//}

contract OrderHandler is MedRegulator, PharRegulator, TrackerRegister, PrescriptionHandler {

    //PharRegulatorInterface pharRegContract;
    //MedRegulatorInterface medRegContract;
    event NewOrder(uint medId, uint labId, uint pharmacyId, uint orderRequestId, uint orderDetailRequestId);
    event OrderStateChanged(uint orderId, uint state, string message);
    event QuantitySetted(uint orderId, uint pharmacyId, uint quantity);
    event MaxDateSetted(uint orderId, uint pharmacyId, string maxDate);
    event TempSetted(uint orderId, uint labId, uint maxTemp, uint minTemp);
    event TrackerSetted(uint orderId, uint trackerId);
    event TrackerDetails(uint orderId, uint trackerId, string lat, string long, uint actualTemp, uint trackingState);

    struct Order {
        uint medId;
        uint labId;
        uint pharmacyId;
        uint state;
    }
    //state = 0 --> Setting Details
    //state = 1 --> Pending
    //state = 2 --> Accepted
    //state = 3 --> Declined
    //state = 4 --> TempSetted
    //state = 5 --> TrackingSetted
    //state = 6 --> LabDetailsSetted
    //state = 7 --> Sent/Tracking
    //state = 8 --> Received
    
    struct OrderDetail {
        uint quantity;
        string maxDeliveryDate;
        uint trackerId;
    }

    struct OrderTrackingDetail {
        string latitud;
        string longitud;
        uint maxTemp;
        uint minTemp;
        uint actualTemp;
        uint trackerState;
    }
    //trackerState = 0 --> OK
    //trackerState >= 1 --> Defectuoso (Número de fallos)

    Order[] public orderRequests;
    OrderDetail[] public orderDetailRequests;
    OrderTrackingDetail[] public orderTrackingDetails;
 
    //Compruebo que quién quiere hacer un pedido es una farmacia registrada
    modifier onlyPharmacy(uint _pharmacyId) {
        //address pharmacyAddress = pharRegContract.getPharmacyAddress(_pharmacyId);
        address pharmacyAddress = getPharmacyAddress(_pharmacyId);
        require(msg.sender == pharmacyAddress);
        _;
    }

    modifier onlyLab(uint _labId) {
        address labAddress = getLabAddress(_labId);
        require(msg.sender == labAddress);
        _;
    }
    
    // Mirar el onlyOwner
    //function setPharRegulatorContractAddress(address _address) public onlyOwner {
    //    pharRegContract = new PharRegulatorInterface(_address);
    //}
    //function setMedRegulatorContractAddress(address _address) public onlyOwner {
    //    medRegContract = MedRegulatorInterface(_address);
    //}
    function createOrder(uint _medId, uint _pharmacyId, uint _labId) public onlyPharmacy(_pharmacyId) {
        //Accedemos a los labs
        string memory defaultAddress = "0x";
        //require((keccak256(medRegContract.getLabAddress(_labId)) != keccak256(defaultAddress)) && (keccak256(medRegContract.getMedData(_medId)) != keccak256("")));
        require((keccak256(getLabAddress(_labId)) != keccak256(defaultAddress)) && (keccak256(getMedData(_medId)) != keccak256("")));
        uint orderRequestId = orderRequests.push(Order(_medId, _labId, _pharmacyId, 0))-1;
        emit NewOrder(_medId, _labId, _pharmacyId, orderRequestId, _initOrderDetails(0, "", "", "", 0, 0, 0, 0, 0));
    }

    function setQuantity(uint _orderId, uint _pharmacyId, uint _quantity) public onlyPharmacy(_pharmacyId) {
        require(orderRequests[_orderId].pharmacyId == _pharmacyId);
        orderDetailRequests[_orderId].quantity = _quantity;
        if (keccak256(orderDetailRequests[_orderId].maxDeliveryDate) != keccak256("")) {
            orderRequests[_orderId].state = 1;
        } 
        emit QuantitySetted(_orderId, _pharmacyId, _quantity);
    }

    function setMaxDeliveryDate(uint _orderId, uint _pharmacyId, string _maxDelDate) public onlyPharmacy(_pharmacyId) {
        require(orderRequests[_orderId].pharmacyId == _pharmacyId);
        orderDetailRequests[_orderId].maxDeliveryDate = _maxDelDate;
        if (keccak256(orderDetailRequests[_orderId].quantity) != keccak256("")) {
            orderRequests[_orderId].state = 1;
        }
        emit MaxDateSetted(_orderId, _pharmacyId, _maxDelDate);
    }

    //Primero se tiene que aceptar el pedido, y luego se introducen los detalles
    function setTemps(uint _orderId, uint _labId, uint _maxTemp, uint _minTemp) public onlyLab(_labId) {
        require(orderRequests[_orderId].labId == _labId);
        if (orderRequests[_orderId].state == 2) {
            orderRequests[_orderId].state = 4;
            orderTrackingDetails[_orderId].maxTemp = _maxTemp;
            orderTrackingDetails[_orderId].minTemp = _minTemp;
        } else if (orderRequests[_orderId].state == 5) {
            orderRequests[_orderId].state = 6;
            orderTrackingDetails[_orderId].maxTemp = _maxTemp;
            orderTrackingDetails[_orderId].minTemp = _minTemp;
        }
        emit TempSetted(_orderId, _labId, _maxTemp, _minTemp);
    }

    //Lanzar bien el evento!!! DESDE DENTRO DE LOS IF!!!!
    function setTracker(uint _orderId, uint _trackerId) public onlyOwner {
        require(keccak256(getTrackerAddress(_trackerId)) != keccak256("0x"));
        if (orderRequests[_orderId].state == 2) {
            orderRequests[_orderId].state = 5;
            orderDetailRequests[_orderId].trackerId = _trackerId;
        } else if (orderRequests[_orderId].state == 4) {
            orderRequests[_orderId].state = 6;
            orderDetailRequests[_orderId].trackerId = _trackerId;
        }
        emit TrackerSetted(_orderId, _trackerId);
    } 

    function setTrackingDetails(uint _orderId, uint _trackerId, string _lat, string _long, uint _actualTemp) public onlyTracker(_trackerId) {
        require((orderDetailRequests[_orderId].trackerId == _trackerId) && (orderRequests[_orderId].state == 7));
        if ((orderTrackingDetails[_orderId].maxTemp < _actualTemp) || (orderTrackingDetails[_orderId].minTemp > _actualTemp)) {
            orderTrackingDetails[_orderId].trackerState += 1;
        }
        orderTrackingDetails[_orderId].latitud = _lat;
        orderTrackingDetails[_orderId].longitud = _long;
        orderTrackingDetails[_orderId].actualTemp = _actualTemp; 
        emit TrackerDetails(_orderId, _trackerId, _lat, _long, _actualTemp, orderTrackingDetails[_orderId].trackerState);
    }

    function changeOrderStateLab(uint _orderId, uint _labId, uint _state) public {
        //require(msg.sender == medRegContract.getLabAddress(_labId));
        require(msg.sender == getLabAddress(_labId));
        bool stateCorrect = false;
        if (_state == 2 || _state == 3) {
            if (orderRequests[_orderId].state == 1) {
                stateCorrect = true;
            }
        } else if (_state == 7) {
            if (orderRequests[_orderId].state == 6) {
                stateCorrect = true;
            }
        }
        require(orderRequests[_orderId].labId == _labId);
        if (stateCorrect) {
            orderRequests[_orderId].state = _state;
            emit OrderStateChanged(_orderId, orderRequests[_orderId].state, "Estado del pedido actualizado");
        } else {
            emit OrderStateChanged(_orderId, orderRequests[_orderId].state, "No se puede actualizar el pedido a ese estado");
        }
    }

    function registerOrderDelivery(uint _orderId, uint _pharId) public onlyPharmacy(_pharId) {
        require(orderRequests[_orderId].pharmacyId == _pharId);
        if (orderRequests[_orderId].state == 7) {
            orderRequests[_orderId].state = 8;
            emit OrderStateChanged(_orderId, orderRequests[_orderId].state, "Estado del pedido actualizado");
        } else {
            emit OrderStateChanged(_orderId, orderRequests[_orderId].state, "No se puede actualizar el pedido a ese estado");
        }
    }

    function _initOrderDetails(uint _quantity, string _maxDelDate, string _lat, string _long, uint _maxTemp, uint _minTemp, uint _actualTemp, uint _trackerId, uint _trackerState) private returns(uint) {
        orderTrackingDetails.push(OrderTrackingDetail(_lat, _long, _maxTemp, _minTemp, _actualTemp, _trackerState))-1;
        return orderDetailRequests.push(OrderDetail(_quantity, _maxDelDate, _trackerId))-1;
    }

}