pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import "./utils/EnumerableSet.sol";
import "./access/AccessControl.sol";
import "./access/Ownable.sol";
import "./math/SafeMath.sol";

import "./Roles.sol";


contract Storage {
    enum BatchStages {
        PLAPacked,
        PLAPickedUpByCourier1, //states chages to this with sig of coordinator and courier both
        PLARecivedByManufaturer, //states chages to this with sig of courier and manufaturer both
        MasksReady,
        MasksPickedUpByCourier2, //states chages to this with sig of manufature and courier both
        MasksRceivedByReceiver, //states chages to this with sig of courier and reciver both
        MasksVerifiedForQuality
    }
    struct AddressSet {
        address[] addresses;
        mapping(address => uint256) addressIndex;
    }
    // //what else?
    // enum CampaignStages{
    //     campaignStarted,
    //     campaignFinished
    // }
    struct Batch {
        BatchStages stage;
        bool isPLAPickedUpCourier1;
        bool isPLAPickedUpCoordinator;
        bool isPLARecivedCourier1;
        bool isPLAReceivedManufacturer;
        bool isMasksPickedUpCourier2;
        bool isMasksPickedUpManufacturer;
        bool isMasksaReceviedCourier2;
        bool isMasksReceviedReceviver;
        uint256 amountOfPLA;
        uint256 amountOfExpectedMasks;
        uint256 amountOfMasksMade;
        uint256 tfForDeliveryToManufacturer;
        uint256 tfForMakingMasks;
        uint256 tfForDeliveryToReciver;
        address courier1;
        address courier2;
        address manufacturer;
    }

    struct Campaign {
        // CampaignStages stage,
        uint256 totalPLA;
        uint256 batchCounter;
        address coordinator;
        address receiver;
        AddressSet manufacturers;
        AddressSet couriers;
        mapping(uint256 => Batch) batches;

        // uint256 batchSize;
    }

    mapping(uint256 => Campaign) campaigns; //campaign's Index in the campaigns array + 1 (becuse 0 means it is not in the array)
    uint256 public campaignCounter = 1;
}


contract CampaignGenerator is Ownable, Roles, Storage {
    using SafeMath for uint256;

    event CampaignStarted(uint256 campaignId);
    event PLAPacked(uint256 campaignId, uint256 branchId);
    event PLAPickedUpByCourier1(uint256 campaignId, uint256 branchId); //emits with sig of coordinator and courier both
    event PLARecivedByManufacturer(uint256 campaignId, uint256 branchId); //emits with sig of courier and manufaturer both
    event MasksReady(
        uint256 campaignId,
        uint256 branchId,
        uint256 amountOfMasksMade
    );
    event MasksPickedUpByCourier2(uint256 campaignId, uint256 branchId); //emits with sig of manufature and courier both
    event MasksRceivedByReceiver(uint256 campaignId, uint256 branchId); //emitswith sig of courier and reciver both
    event MasksVerifiedForQuality(uint256 campaignId, uint256 branchId);

    constructor(address _admin) public Roles(_admin) {}

    function makeCoordinator(address _who) public onlyAdmin() {
        grantRole(COORDINATOR_ROLE, _who);
    }

    function startCampaign(
        address[] memory _manufacturers,
        address[] memory _couriers,
        address _receiver,
        uint256 _totalPLA
    ) public onlyCoordinator() returns (uint256 campaignId) {
        campaignId = campaignCounter;
        Campaign storage campaign = campaigns[campaignId];
        campaignCounter = campaignCounter.add(1);

        //In future iteration campaign id can be deterministically generated form title and description of the campaign i.e. keccak(title+description)

        campaign.coordinator = _msgSender();

        for (uint256 i = 0; i < _manufacturers.length; i = i.add(1)) {
            grantRole(MANUFATURER_ROLE, _manufacturers[i]);
            campaign.manufacturers.addressIndex[_manufacturers[i]] = i.add(1);
        }
        for (uint256 i = 0; i < _couriers.length; i = i.add(1)) {
            grantRole(COURIER_ROLE, _couriers[i]);
            campaign.couriers.addressIndex[_couriers[i]] = i.add(1);
        }

        campaign.manufacturers.addresses = _manufacturers;
        campaign.couriers.addresses = _couriers;
        campaign.receiver = _receiver;
        campaign.batchCounter = 0;

        campaign.totalPLA = _totalPLA;
        emit CampaignStarted(campaignId);
    }

    function addManufacturers(
        uint256 _campaignId,
        address[] memory _manufacturers
    ) public onlyCoordinator() {
        require(
            campaigns[_campaignId].coordinator == _msgSender(),
            "Only coordinator of camapignId is allowed"
        );
        Campaign storage campaign = campaigns[_campaignId];
        uint256 arrayLength = campaign.manufacturers.addresses.length;

        for (uint256 i = 0; i < _manufacturers.length; i = i.add(1)) {
            grantRole(MANUFATURER_ROLE, _manufacturers[i]);

            campaign.manufacturers.addresses.push(_manufacturers[i]);
            campaign.manufacturers.addressIndex[_manufacturers[i]] = arrayLength
                .add(i.add(1));
        }
    }

    function addCouriers(uint256 _campaignId, address[] memory _couriers)
        public
        onlyCoordinator()
    {
        require(
            campaigns[_campaignId].coordinator == _msgSender(),
            "Only coordinator of camapignId is allowed"
        );
        Campaign storage campaign = campaigns[_campaignId];
        uint256 arrayLength = campaign.couriers.addresses.length;

        for (uint256 i = 0; i < _couriers.length; i = i.add(1)) {
            grantRole(MANUFATURER_ROLE, _couriers[i]);

            campaign.couriers.addresses.push(_couriers[i]);
            campaign.couriers.addressIndex[_couriers[i]] = arrayLength.add(
                i.add(1)
            );
        }
    }

    function createNewBatch(
        uint256 _campaignId,
        uint256 _amountOfPLA,
        uint256 _amountOfMasksMade,
        uint256 _tfForDeliveryToManufacturer,
        uint256 _tfForMakingMasks,
        uint256 _tfForDeliveryToReciver,
        address _courier1,
        address _courier2,
        address _manufacturer
    ) public onlyCoordinator() {
        require(
            campaigns[_campaignId].coordinator == _msgSender(),
            "Only coordinator of camapignId is allowed"
        );
        require(
            campaigns[_campaignId].couriers.addressIndex[_courier1] != 0,
            "add courier to campaign first"
        );
        require(
            campaigns[_campaignId].couriers.addressIndex[_courier2] != 0,
            "add courier to campaign first"
        );
        require(
            campaigns[_campaignId].couriers.addressIndex[_manufacturer] != 0,
            "add manufaturer to campaign first"
        );
        campaigns[_campaignId].batchCounter = campaigns[_campaignId]
            .batchCounter
            .add(1);

        uint256 batchId = campaigns[_campaignId].batchCounter;
        Batch storage batch = campaigns[_campaignId].batches[batchId];
        batch.stage = BatchStages.PLAPacked;

        batch.amountOfPLA = _amountOfPLA;
        batch.amountOfMasksMade = _amountOfMasksMade;

        batch.tfForDeliveryToManufacturer = _tfForDeliveryToManufacturer;

        batch.tfForMakingMasks = _tfForMakingMasks;

        batch.tfForDeliveryToReciver = _tfForDeliveryToReciver;

        batch.courier1 = _courier1;

        batch.courier2 = _courier2;

        batch.manufacturer = _manufacturer;
        emit PLAPacked(_campaignId, batchId);
    }

    //the chain Starts
    function confirmPLAPickedUpByCourier1(uint256 _campaignId, uint256 _batchId)
        public
        returns (bool stageChange)
    {
        require(
            campaigns[_campaignId].coordinator == _msgSender() ||
                campaigns[_campaignId].batches[_batchId].courier1 ==
                _msgSender(),
            "Only coordinator of camapignId or courier is allowed"
        );
        stageChange = false;
        if (campaigns[_campaignId].coordinator == _msgSender()) {
            campaigns[_campaignId].batches[_batchId]
                .isPLAPickedUpCoordinator = true;
        }
        if (campaigns[_campaignId].batches[_batchId].courier1 == _msgSender()) {
            campaigns[_campaignId].batches[_batchId]
                .isPLAPickedUpCourier1 = true;
        }
        if (
            campaigns[_campaignId].batches[_batchId].isPLAPickedUpCoordinator ==
            true &&
            campaigns[_campaignId].batches[_batchId].isPLAPickedUpCourier1 ==
            true
        ) {
            campaigns[_campaignId].batches[_batchId].stage = BatchStages
                .PLAPickedUpByCourier1;

            emit PLAPickedUpByCourier1(_campaignId, _batchId);
            stageChange = true;
        }
    }

    function confirmPLARecivedByManufacturer(
        uint256 _campaignId,
        uint256 _batchId
    ) public returns (bool stageChange) {
        require(
            campaigns[_campaignId].batches[_batchId].manufacturer ==
                _msgSender() ||
                campaigns[_campaignId].batches[_batchId].courier1 ==
                _msgSender(),
            "Only manufacturer or courier of batch is allowed"
        );
        stageChange = false;
        if (
            campaigns[_campaignId].batches[_batchId].manufacturer ==
            _msgSender()
        ) {
            campaigns[_campaignId].batches[_batchId]
                .isPLAReceivedManufacturer = true;
        }
        if (campaigns[_campaignId].batches[_batchId].courier1 == _msgSender()) {
            campaigns[_campaignId].batches[_batchId]
                .isPLARecivedCourier1 = true;
        }
        if (
            campaigns[_campaignId].batches[_batchId]
                .isPLAReceivedManufacturer ==
            true &&
            campaigns[_campaignId].batches[_batchId].isPLARecivedCourier1 ==
            true
        ) {
            campaigns[_campaignId].batches[_batchId].stage = BatchStages
                .PLARecivedByManufaturer;

            emit PLARecivedByManufacturer(_campaignId, _batchId);
            stageChange = true;
        }
    }

    function confirmMasksMade(
        uint256 _campaignId,
        uint256 _batchId,
        uint256 _amountOfMasksMade
    ) public {
        require(
            campaigns[_campaignId].batches[_batchId].manufacturer ==
                _msgSender(),
            "Only manufacturer of batch is allowed"
        );
        campaigns[_campaignId].batches[_batchId]
            .amountOfMasksMade = _amountOfMasksMade;
        campaigns[_campaignId].batches[_batchId].stage = BatchStages.MasksReady;
        emit MasksReady(_campaignId, _batchId, _amountOfMasksMade);
    }

    function confirmMasksPickedUpByCourier2(
        uint256 _campaignId,
        uint256 _batchId
    ) public returns (bool stageChange) {
        require(
            campaigns[_campaignId].batches[_batchId].manufacturer ==
                _msgSender() ||
                campaigns[_campaignId].batches[_batchId].courier2 ==
                _msgSender(),
            "Only manufacturer or courier of batch is allowed"
        );
        stageChange = false;
        if (
            campaigns[_campaignId].batches[_batchId].manufacturer ==
            _msgSender()
        ) {
            campaigns[_campaignId].batches[_batchId]
                .isMasksPickedUpManufacturer = true;
        }
        if (campaigns[_campaignId].batches[_batchId].courier2 == _msgSender()) {
            campaigns[_campaignId].batches[_batchId]
                .isMasksPickedUpCourier2 = true;
        }
        if (
            campaigns[_campaignId].batches[_batchId]
                .isMasksPickedUpManufacturer ==
            true &&
            campaigns[_campaignId].batches[_batchId].isMasksPickedUpCourier2 ==
            true
        ) {
            campaigns[_campaignId].batches[_batchId].stage = BatchStages
                .MasksPickedUpByCourier2;

            emit MasksPickedUpByCourier2(_campaignId, _batchId);
            stageChange = true;
        }
    }

    function confirmMasksRceivedByReceiver(
        uint256 _campaignId,
        uint256 _batchId
    ) public returns (bool stageChange) {
        require(
            campaigns[_campaignId].receiver == _msgSender() ||
                campaigns[_campaignId].batches[_batchId].courier2 ==
                _msgSender(),
            "Only reciver of camapignId or courier is allowed"
        );
        stageChange = false;
        if (campaigns[_campaignId].receiver == _msgSender()) {
            campaigns[_campaignId].batches[_batchId]
                .isMasksReceviedReceviver = true;
        }
        if (campaigns[_campaignId].batches[_batchId].courier2 == _msgSender()) {
            campaigns[_campaignId].batches[_batchId]
                .isMasksaReceviedCourier2 = true;
        }
        if (
            campaigns[_campaignId].batches[_batchId].isMasksReceviedReceviver ==
            true &&
            campaigns[_campaignId].batches[_batchId].isMasksaReceviedCourier2 ==
            true
        ) {
            campaigns[_campaignId].batches[_batchId].stage = BatchStages
                .MasksRceivedByReceiver;

            emit MasksRceivedByReceiver(_campaignId, _batchId);
            stageChange = true;
        }
    }

    //for test
    function getCampaignDetalis(uint256 _campaignId)
        public
        view
        returns (
            address coordinator,
            uint256 totalPLA,
            address[] memory manufacturers,
            address[] memory couriers,
            uint256 lastOfManufactures,
            uint256 lastOfCaouriers
        )
    {
        coordinator = campaigns[_campaignId].coordinator;
        totalPLA = campaigns[_campaignId].totalPLA;
        manufacturers = campaigns[_campaignId].manufacturers.addresses;
        couriers = campaigns[_campaignId].couriers.addresses;
        lastOfManufactures = campaigns[_campaignId]
            .manufacturers
            .addressIndex[campaigns[_campaignId]
            .manufacturers
            .addresses[campaigns[_campaignId].manufacturers.addresses.length -
            1]];
        lastOfCaouriers = campaigns[_campaignId]
            .couriers
            .addressIndex[campaigns[_campaignId]
            .couriers
            .addresses[campaigns[_campaignId].couriers.addresses.length - 1]];
    }

    function getBatchDetails(uint256 _campaignId, uint256 _batchId)
        public
        view
        returns (Batch memory batch)
    {
        batch = campaigns[_campaignId].batches[_batchId];
    }
}
