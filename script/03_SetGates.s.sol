// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "./THJScriptBase.sol";
import {Gatekeeper} from "src/Gatekeeper.sol";

contract SetGates is THJScriptBase("gen3") {
    using stdJson for string;

    Gatekeeper private gk;

    function setUp() public {
        gk = Gatekeeper(_readAddress("GATEKEEPER_ADDRESS"));
    }

    function run(string calldata env) public override {
        vm.startBroadcast();
        string memory json = _getConfig(env);

        uint256 bundleId = uint8(json.readUint(".bundleId")); // BundleId has to be less than 255

        // TODO: could be moved into config
        //     function addGate(uint256 bundleId, bytes32 root_, uint32 maxClaimable_, uint8 stageIndex_)
        gk.addGate(bundleId, 0xe49335ad42e05dc5aa1e8693818d134ec2d6ff73f497c0922e0858f247df3f46, 214, 0);
        gk.addGate(bundleId, 0xbde4b24cf08db3f0654c553460aca20cab43b4d1084fa0717f09f7c21b6bf14a, 0, 0);
        gk.addGate(bundleId, 0x38b29dc9dc9ec1e2dee50a690fbfd0bee7f90da444312cbffe368bd1da1ae9c6, 1494, 0);
        gk.addGate(bundleId, 0xfbd52266364adc4aa98a42fdb32b9212f7a31b07711bfcbe13c758d7d094245b, 0, 1);
        gk.addGate(bundleId, 0x7c8d585f39c5b12ca7f08f4b9abdc44d300f9bd6f1ad96798e61cf89bec421db, 0, 1);

        console.log("--- Gates Added");

        vm.stopBroadcast();
    }
}
