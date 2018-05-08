pragma solidity ^0.4.21;
import "./ownable.sol";


contract MedicosRegulator is Ownable {
    event NewDoctor(string doctorLicense, string name, string hospital, uint doctorId, bool isNew, string message);
    event NewOrder(string license, uint medId, uint quantity, string location, uint maxDeliveryDate);

    struct Doctor {
        string doctorLicense;
        string name;
        string hospital;
    }

    Doctor[] public doctors;
    mapping (uint => address) public doctorAddress;
    
    function registerDoctor(string _doctorLicense, string _name, string _hospital, address _doctorAddress) public onlyOwner {
        bool exists = false;
        uint doctorIdAux;
        Doctor[] memory doctorsAux = doctors;
        for (uint i = 0; i < doctors.length; i++) {
            if ((keccak256(doctorsAux[i].doctorLicense) == keccak256(_doctorLicense))||(keccak256(doctorsAux[i].name) == keccak256(_name))) {
                exists = exists || true;
                doctorIdAux = i;
            }
        }
        if (!exists) {
            uint doctorId = doctors.push(Doctor(_doctorLicense, _name, _hospital))-1;
            doctorAddress[doctorId] = _doctorAddress;
            emit NewDoctor(_doctorLicense, _name, _hospital, doctorId, true, "Nuevo doctor registrado");
        } else {
            emit NewDoctor(_doctorLicense, _name, _hospital, doctorIdAux, false, "Este doctor ya esta registrado");
        }
    }

    function getDoctorAddress(uint _doctorId) public view returns (address _doctorAddress) {
        return doctorAddress[_doctorId];
    }

}