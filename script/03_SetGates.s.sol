// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "./THJScriptBase.sol";
import {Gatekeeper} from "src/Gatekeeper.sol";

contract SetGates is THJScriptBase {
    using stdJson for string;

    uint8 private BUNDLE_ID = 0;

    Gatekeeper private gk;

    function setUp() public {
        gk = Gatekeeper(_readAddress("GATEKEEPER_ADDRESS"));
    }

    function run(string calldata env) public override {
        vm.startBroadcast();

        // TODO: could be moved into config
        //     function addGate(uint256 bundleId, bytes32 root_, uint32 maxClaimable_, uint8 stageIndex_)
        gk.addGate(BUNDLE_ID, 0xe49335ad42e05dc5aa1e8693818d134ec2d6ff73f497c0922e0858f247df3f46, 214, 0);
        gk.addGate(BUNDLE_ID, 0xbde4b24cf08db3f0654c553460aca20cab43b4d1084fa0717f09f7c21b6bf14a, 0, 0);
        gk.addGate(BUNDLE_ID, 0x17b3523db7dc9742b6cd362fbc2072d548b3c2228ac4307924a50bc8d1c2d7ba, 1494, 0);
        gk.addGate(BUNDLE_ID, 0xfbd52266364adc4aa98a42fdb32b9212f7a31b07711bfcbe13c758d7d094245b, 0, 1);
        gk.addGate(BUNDLE_ID, 0x7c8d585f39c5b12ca7f08f4b9abdc44d300f9bd6f1ad96798e61cf89bec421db, 0, 1);

        console.log("--- Gates Added");

        vm.stopBroadcast();
    }
}
