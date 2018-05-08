pragma solidity ^0.4.21;
import "./ownable.sol";


contract PharRegulator is Ownable {
    event NewPharmacy(string license, string name, string location, uint pharmacyId, bool isNew, string message);
    event NewOrder(string license, uint medId, uint quantity, string location, uint labId, uint maxDeliveryDate);

    struct Pharmacy {
        string license;
        string name;
        string location;
    }

    Pharmacy[] public pharmacies;
    mapping (uint => address) public pharmacyAddress;
    
    function registerPharmacy(string _license, string _name, string _location, address _pharmacyAddress) public onlyOwner {
        bool exists = false;
        uint pharmacyIdAux;
        Pharmacy[] memory pharmaciesAux = pharmacies;
        for (uint i = 0; i < pharmacies.length; i++) {
            if ((keccak256(pharmaciesAux[i].license) == keccak256(_license))||(keccak256(pharmaciesAux[i].name) == keccak256(_name))) {
                exists = exists || true;
                pharmacyIdAux = i;
            }
        }
        if (!exists) {
            uint pharmacyId = pharmacies.push(Pharmacy(_license, _name, _location))-1;
            pharmacyAddress[pharmacyId] = _pharmacyAddress;
            emit NewPharmacy(_license, _name, _location, pharmacyId, true, "Nueva farmacia registrada");
        } else {
            emit NewPharmacy(_license, _name, _location, pharmacyIdAux, false, "Esta farmacia ya esta registrada");
        }
    }

    function getPharmacyAddress(uint _pharId) public view returns (address) {
        return pharmacyAddress[_pharId];
    }

}

