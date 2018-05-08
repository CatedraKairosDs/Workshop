pragma solidity ^0.4.21;
import "./ownable.sol";
import "./MedicosRegulator.sol";
import "./MedRegulator.sol";
import "./PharRegulator.sol";


contract PrescriptionHandler is MedicosRegulator, MedRegulator, PharRegulator {
    
    event NewPrescription(uint medId, uint prescriptionRequestId, uint prescriptionDetailRequestId, uint startTime);
    event PrescriptionAnswered(uint prescriptionId, string state, uint difTime, uint time);

    struct Prescription {
        uint medId;
        string state;
    }
    
    struct PrescriptionDetail {
        uint prescriptionId;
        uint quantity;
        string hospital;
        uint maxDeliveryDays;
    }

    Prescription[] public prescriptions;
    PrescriptionDetail[] public prescriptionDetails;

    mapping (uint => uint) public starts;

    //Compruebo que quién quiere hacer un pedido es un doctor registrado
    modifier onlyDoctors(uint _doctorId) {
        address doctorAddress = getDoctorAddress(_doctorId);
        require(msg.sender == doctorAddress);
        _;
    }

    modifier onlyPharmacies(uint _pharmacyId) {
        address pharmacyAddress = getPharmacyAddress(_pharmacyId);
        require(msg.sender == pharmacyAddress);
        _;
    }

    function createPrescription(uint _medId, uint _quantity, uint _doctorId, string _hospital, uint _maxDeliveryDays) public onlyDoctors(_doctorId) {
        //Accedemos a los labs
        //start();
        string memory defaultAddress = "0x";
        require((keccak256(getDoctorAddress(_doctorId)) != keccak256(defaultAddress)) && (keccak256(getMedData(_medId)) != keccak256("")));
       
        uint prescriptionRequestId = prescriptions.push(Prescription(_medId, "Pending"))-1;
        starts[prescriptionRequestId] = now;
        emit NewPrescription(_medId, prescriptionRequestId, _setPrescriptionDetails(prescriptionRequestId, _quantity, _hospital, _maxDeliveryDays), starts[prescriptionRequestId]);
    }

   //event PrescriptionAnswered(uint prescriptionId, string state);
    function boughtPrescription(uint _prescriptionId, uint _pharmacyId) public onlyPharmacies(_pharmacyId) {
        //Prescription memory prescription = prescriptions[_prescriptionId];
        //Prueba con minutes en vez de con days
        if (now <= starts[_prescriptionId] + prescriptionDetails[_prescriptionId].maxDeliveryDays * 1 weeks) {
            prescriptions[_prescriptionId].state = "Comprada";
            emit PrescriptionAnswered(_prescriptionId, prescriptions[_prescriptionId].state, starts[_prescriptionId] + prescriptionDetails[_prescriptionId].maxDeliveryDays * 1 weeks, now);
        } else {
            prescriptions[_prescriptionId].state = "Expirada";
            emit PrescriptionAnswered(_prescriptionId, prescriptions[_prescriptionId].state, starts[_prescriptionId] + prescriptionDetails[_prescriptionId].maxDeliveryDays * 1 weeks, now); 
        }
        //if (_getTimeDif(starts[_prescriptionId], now) < prescriptionDetails[_prescriptionId].maxDeliveryDays*3600*24) {
            //prescription.state = "Comprada";
        //    prescriptions[_prescriptionId].state = "Comprada";
        //    PrescriptionAnswered(_prescriptionId, prescriptions[_prescriptionId].state, _getTimeDif(starts[_prescriptionId], now), prescriptionDetails[_prescriptionId].maxDeliveryDays*3600*24);
        //} else {
        //    prescriptions[_prescriptionId].state = "Expirada";
        //    PrescriptionAnswered(_prescriptionId, prescriptions[_prescriptionId].state, _getTimeDif(starts[_prescriptionId], now), prescriptionDetails[_prescriptionId].maxDeliveryDays*3600*24);
            //prescription.state = "Expirado";
        //}
    }

    function _setPrescriptionDetails(uint _prescriptionId, uint _quantity, string _hospital, uint _maxDeliveryDate) private returns(uint) {
        uint prescriptionDetailsRequestId = prescriptionDetails.push(PrescriptionDetail(_prescriptionId, _quantity, _hospital, _maxDeliveryDate))-1;
        return prescriptionDetailsRequestId;
    }

    //Esto da algo raro... Habría que sacar por un evento el resultado de los tiempos...
    function _getTimeDif(uint _start, uint _end) private pure returns(uint) {
        return (_end - _start);
    }     
}

