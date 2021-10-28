// Copyright (C) 2020 Maker Ecosystem Growth Holdings, INC.
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

pragma solidity 0.5.12;

import "ds-math/math.sol";
import "ds-test/test.sol";
import "lib/dss-interfaces/src/Interfaces.sol";

import {DssSpell, SpellAction} from "./DEFCON-2.sol";

contract Hevm {
    function warp(uint256) public;
    function store(address,bytes32,bytes32) public;
}

contract DssSpellTest is DSTest, DSMath {
    // Replace with mainnet spell address to test against live
    address constant MAINNET_SPELL = address(0);

    // Common orders of magnitude needed in spells
    //
    uint256 constant public WAD = 10**18;
    uint256 constant public RAY = 10**27;
    uint256 constant public RAD = 10**45;
    uint256 constant public MLN = 10**6;
    uint256 constant public BLN = 10**9;


    struct CollateralValues {
        uint256 line;
        uint256 duty;
        uint48  tau;
        uint256 liquidations;
    }

    struct SystemValues {
        uint256 dsr;
        uint256 Line;
        uint256 pauseDelay;
        uint256 expiration;
        mapping (bytes32 => CollateralValues) collaterals;
    }

    SystemValues beforeSpell;
    SystemValues afterSpell;

    Hevm hevm;

    DSPauseAbstract pause =
        DSPauseAbstract(0xbE286431454714F511008713973d3B053A2d38f3);
    DSChiefAbstract chief =
        DSChiefAbstract(0x0a3f6849f78076aefaDf113F5BED87720274dDC0);
    VatAbstract vat =
        VatAbstract(0x35D1b3F3D7966A1DFe207aa4514C12a259A0492B);
    CatAbstract cat =
        CatAbstract(0xa5679C04fc3d9d8b0AaB1F0ab83555b301cA70Ea);
    DogAbstract dog =
        DogAbstract(0x135954d155898D42C90D2a57824C690e0c7BEf1B);
    PotAbstract pot =
        PotAbstract(0x197E90f9FAD81970bA7976f33CbD77088E5D7cf7);
    JugAbstract jug =
        JugAbstract(0x19c0976f590D67707E62397C87829d896Dc0f1F1);
    DSTokenAbstract gov =
        DSTokenAbstract(0x9f8F72aA9304c8B593d555F12eF6589cC3A579A2);
    IlkRegistryAbstract registry =
        IlkRegistryAbstract(0x5a464C28D19848f44199D003BeF5ecc87d090F87);

    DssSpell spell;

    // CHEAT_CODE = 0x7109709ECfa91a80626fF3989D68f67F5b1DD12D
    bytes20 constant CHEAT_CODE =
        bytes20(uint160(uint256(keccak256('hevm cheat code'))));

    // expiration time for this DEFCON spell
    uint256 constant public T2022_12_30_1200UTC = 1672401600;

    function setUp() public {
        hevm = Hevm(address(CHEAT_CODE));

        spell = MAINNET_SPELL != address(0) ?
            DssSpell(MAINNET_SPELL) : new DssSpell();

        // beforeSpell is only used to check liquidations
        beforeSpell = SystemValues({
            dsr: pot.dsr(),
            Line: vat.Line(),
            pauseDelay: pause.delay(),
            expiration: T2022_12_30_1200UTC
        });

        uint256 sumlines;
        bytes32[] memory ilks = registry.list();

        for(uint i = 0; i < ilks.length; i++) {
            (,,, uint256 line,) = vat.ilks(ilks[i]);
            (uint256 duty,) = jug.ilks(ilks[i]);

            if (registry.class(ilks[i]) == 2) {

                FlipAbstract flip = FlipAbstract(registry.xlip(ilks[i]));

                beforeSpell.collaterals[ilks[i]] = CollateralValues({
                    line: line,
                    duty: duty,
                    tau: flip.tau(),
                    liquidations: flip.wards(address(cat))
                });

                afterSpell.collaterals[ilks[i]] = CollateralValues({
                    line: line,
                    duty: 1000000000000000000000000000,
                    tau: 24 hours,
                    liquidations: flip.wards(address(cat))
                });
            }


            if (ilks[i] == "USDC-B") {
                // USDC-B emergency parameters
                afterSpell.collaterals["USDC-B"].line =
                    line + (50 * MLN * RAD);
                afterSpell.collaterals["USDC-B"].duty = duty;
            }
            sumlines += line;
        }

        afterSpell = SystemValues({
            dsr: 1000000000000000000000000000,
            Line: sumlines + (50 * MLN * RAD),
            pauseDelay: pause.delay(),
            expiration: T2022_12_30_1200UTC
        });
    }

    function vote() private {
        if (chief.hat() != address(spell)) {
            hevm.store(
                address(gov),
                keccak256(abi.encode(address(this), uint256(1))),
                bytes32(uint256(999999999999 ether))
            );

            gov.approve(address(chief), uint256(-1));
            chief.lock(sub(gov.balanceOf(address(this)), 1 ether));

            assertTrue(!spell.done());

            address[] memory yays = new address[](1);
            yays[0] = address(spell);

            chief.vote(yays);
            chief.lift(address(spell));
        }
        assertEq(chief.hat(), address(spell));
    }

    function waitAndCast() public {
        hevm.warp(now + pause.delay());
        spell.cast();
    }

    function schedule() public {
        spell.schedule();
    }

    function scheduleWaitAndCast() public {
        spell.schedule();
        hevm.warp(now + pause.delay());
        spell.cast();
    }

    function stringToBytes32(
        string memory source
    ) public pure returns (bytes32 result) {
        assembly {
            result := mload(add(source, 32))
        }
    }

    function checkSpellValues(SystemValues storage values) internal {
        // Test description
        assertTrue(bytes(spell.description()).length > 0);

        // Test expiration
        assertEq(spell.expiration(), values.expiration);

        // dsr
        assertEq(pot.dsr(), values.dsr);

        // Line
        assertEq(vat.Line(), values.Line);

        // Pause delay
        assertEq(pause.delay(), values.pauseDelay);
    }

    function checkCollateralValues(
        bytes32 ilk,
        SystemValues storage values
    ) internal {
        if (registry.class(ilk) == 2) {
            FlipAbstract flip = FlipAbstract(registry.xlip(ilk));

            (uint256 duty,) = jug.ilks(ilk);
            assertEq(duty, values.collaterals[ilk].duty);

            (,,, uint256 line,) = vat.ilks(ilk);
            assertEq(line, values.collaterals[ilk].line);

            assertEq(uint256(flip.tau()), values.collaterals[ilk].tau);
            assertEq(flip.wards(address(cat)), values.collaterals[ilk].liquidations);
        }
    }

    function testDEFCON2() public {
        vote();
        schedule();

        // General System values before spell
        checkSpellValues(beforeSpell);

        bytes32[] memory ilks = registry.list();

        for(uint i = 0; i < ilks.length; i++) {
            // Liquidation values
            checkCollateralValues(ilks[i], beforeSpell);
        }

        waitAndCast();
        assertTrue(spell.done());

        // General System values after spell
        checkSpellValues(afterSpell);

        for(uint i = 0; i < ilks.length; i++) {
            // Collateral values
            checkCollateralValues(ilks[i], afterSpell);
        }
    }
}
