pragma solidity ^0.6.0;

import "./access/AccessControl.sol";
import "./access/Ownable.sol";


contract Roles is AccessControl {
    //keccak256("admin")
    bytes32 public constant ADMIN_ROLE = 0xf23ec0bb4210edd5cba85afd05127efcd2fc6a781bfed49188da1081670b22d8;
    //keccak256("coordinator")
    bytes32 public constant COORDINATOR_ROLE = 0xaf8c8b3d1b230c888f16d0aac400b28aa51e631d580aaa7cb46e571590ed44e7;
    //keccak256("courier")
    bytes32 public constant COURIER_ROLE = 0x7fc3771f539a03c47afbbf258702c19273ef5e735e24ee7978081dc07288c687;
    //keccak256("manufaturer")
    bytes32 public constant MANUFATURER_ROLE = 0xb528929ed79eb79a87ae6f578d3125509c91bfea9ac8b7fb9f69aa0bc28298dd;

    constructor(address _admin) public {
        _setupRole(ADMIN_ROLE, _admin);
        _setRoleAdmin(COORDINATOR_ROLE, ADMIN_ROLE);
        _setRoleAdmin(COURIER_ROLE, COORDINATOR_ROLE);
        _setRoleAdmin(MANUFATURER_ROLE, COORDINATOR_ROLE);
    }

    modifier onlyAdmin() {
        require(hasRole(ADMIN_ROLE, _msgSender()), "Only admin is allowed");
        _;
    }
    modifier onlyCoordinator() {
        require(
            hasRole(COORDINATOR_ROLE, _msgSender()),
            "Only coordinator is allowed"
        );
        _;
    }
    modifier onlyCourier() {
        require(hasRole(COURIER_ROLE, _msgSender()), "Only courier is allowed");
        _;
    }
    modifier onlyManufaturer() {
        require(
            hasRole(MANUFATURER_ROLE, _msgSender()),
            "Only manufaturer is allowed"
        );
        _;
    }
}
