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

import {DssSpell, SpellAction} from "./DEFCON-1.sol";

contract Hevm { function warp(uint) public; }

contract DssSpellTest is DSTest, DSMath {
    // Replace with mainnet spell address to test against live
    address constant MAINNET_SPELL = address(
        0x0ac7bD7Ae9d4eAbe2c50400cd9c1aF349deFf495
    );

    uint256 constant MILLION = 10**6;

    struct CollateralValues {
        uint256 line;
        uint256 duty;
        uint256 pct;
        uint48  tau;
        uint256 liquidations;
    }

    struct SystemValues {
        uint256 expiration;
        mapping (bytes32 => CollateralValues) collaterals;
    }

    SystemValues beforeSpell;
    SystemValues afterSpell;

    Hevm hevm;

    DSPauseAbstract pause =
        DSPauseAbstract(0xbE286431454714F511008713973d3B053A2d38f3);
    DSChiefAbstract chief =
         DSChiefAbstract(0x9eF05f7F6deB616fd37aC3c959a2dDD25A54E4F5);
    VatAbstract vat =
         VatAbstract(0x35D1b3F3D7966A1DFe207aa4514C12a259A0492B);
    CatAbstract cat =
         CatAbstract(0x78F2c2AF65126834c51822F56Be0d7469D7A523E);
    PotAbstract pot =
         PotAbstract(0x197E90f9FAD81970bA7976f33CbD77088E5D7cf7);
    JugAbstract jug =
         JugAbstract(0x19c0976f590D67707E62397C87829d896Dc0f1F1);
    SpotAbstract spot =
         SpotAbstract(0x65C79fcB50Ca1594B025960e539eD7A9a6D434A3);
    MKRAbstract gov =
         MKRAbstract(0x9f8F72aA9304c8B593d555F12eF6589cC3A579A2);
    SaiTubAbstract tub =
         SaiTubAbstract(0x448a5065aeBB8E423F0896E6c5D525C040f59af3);
    FlipAbstract eFlip =
         FlipAbstract(0xd8a04F5412223F513DC55F839574430f5EC15531);
    FlipAbstract bFlip =
         FlipAbstract(0xaA745404d55f88C108A28c86abE7b5A1E7817c07);
    FlipAbstract uFlip =
         FlipAbstract(0xE6ed1d09a19Bd335f051d78D5d22dF3bfF2c28B1);
    FlipAbstract wFlip =
         FlipAbstract(0x3E115d85D4d7253b05fEc9C0bB5b08383C2b0603);
    SaiTopAbstract top =
         SaiTopAbstract(0x9b0ccf7C8994E19F39b2B4CF708e0A7DF65fA8a3);
    EndAbstract end =
         EndAbstract(0xaB14d3CE3F733CACB76eC2AbE7d2fcb00c99F3d5);
    GemAbstract wbtc =
         GemAbstract(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599);
    GemJoinAbstract wJoin =
         GemJoinAbstract(0xBF72Da2Bd84c5170618Fbe5914B0ECA9638d5eb5);
    OsmAbstract wPip =
         OsmAbstract(0xf185d0682d50819263941e5f4EacC763CC5C6C42);
    address flipperMom =
         address(0x9BdDB99625A711bf9bda237044924E34E8570f75);
    address osmMom =
         address(0x76416A4d5190d071bfed309861527431304aA14f);
    address pauseProxy =
         address(0xBE8E3e3618f7474F8cB1d074A26afFef007E98FB);


    DssSpell spell;

    // CHEAT_CODE = 0x7109709ECfa91a80626fF3989D68f67F5b1DD12D
    bytes20 constant CHEAT_CODE =
        bytes20(uint160(uint256(keccak256('hevm cheat code'))));

    // not provided in DSMath
    uint constant RAD = 10 ** 45;
    function rpow(uint x, uint n, uint b) internal pure returns (uint z) {
      assembly {
        switch x case 0 {switch n case 0 {z := b} default {z := 0}}
        default {
          switch mod(n, 2) case 0 { z := b } default { z := x }
          let half := div(b, 2)  // for rounding.
          for { n := div(n, 2) } n { n := div(n,2) } {
            let xx := mul(x, x)
            if iszero(eq(div(xx, x), x)) { revert(0,0) }
            let xxRound := add(xx, half)
            if lt(xxRound, xx) { revert(0,0) }
            x := div(xxRound, b)
            if mod(n,2) {
              let zx := mul(z, x)
              if and(iszero(iszero(x)), iszero(eq(div(zx, x), z))) { revert(0,0) }
              let zxRound := add(zx, half)
              if lt(zxRound, zx) { revert(0,0) }
              z := div(zxRound, b)
            }
          }
        }
      }
    }
    // 10^-5 (tenth of a basis point) as a RAY
    uint256 TOLERANCE = 10 ** 22;

    // expiration time for this DEFCON spell
    uint256 constant public T2020_07_01_1200UTC = 1593604800;

    function setUp() public {
        hevm = Hevm(address(CHEAT_CODE));

        spell = MAINNET_SPELL != address(0) ?
            DssSpell(MAINNET_SPELL) : new DssSpell();

        // beforeSpell is only used to check liquidations
        beforeSpell = SystemValues({
            expiration: T2020_07_01_1200UTC
        });

        afterSpell = SystemValues({
            expiration: T2020_07_01_1200UTC
        });

        bytes32[3] memory ilks = [
            bytes32("ETH-A"),
            bytes32("BAT-A"),
            bytes32("WBTC-A")
        ];

        for(uint i = 0; i < ilks.length; i++) {
            (,,, uint256 line,) = vat.ilks(ilks[i]);
            beforeSpell.collaterals[ilks[i]] = CollateralValues({
                line: line,                            // not tested
                duty: 1000000000000000000000000000,    // not tested
                pct: 0 * 1000,                         // not tested
                tau: 24 hours,                         // not tested
                liquidations: 0
            });
            afterSpell.collaterals[ilks[i]] = CollateralValues({
                line: line,
                duty: 1000000000000000000000000000,
                pct: 0 * 1000,
                tau: 24 hours,
                liquidations: 1
            });
        }

        // USDC-A emergency parameters
        beforeSpell.collaterals["USDC-A"] = CollateralValues({
            line: 40 * MILLION * RAD,                  // not tested
            duty: 1000000012857214317438491659,        // not tested
            pct: 50 * 1000,                            // not tested
            tau: 24 hours,                             // not tested
            liquidations: 0
        });
        afterSpell.collaterals["USDC-A"] = CollateralValues({
            line: 40 * MILLION * RAD,
            duty: 1000000012857214317438491659,
            pct: 50 * 1000,
            tau: 24 hours,
            liquidations: 0
        });
    }

    function vote() private {
        if (chief.hat() != address(spell)) {
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

    function yearlyYield(uint256 duty) public pure returns (uint256) {
        return rpow(duty, (365 * 24 * 60 *60), RAY);
    }

    function expectedRate(uint256 percentValue) public pure returns (uint256) {
        return (100000 + percentValue) * (10 ** 22);
    }

    function diffCalc(
        uint256 expectedRate_,
        uint256 yearlyYield_
    ) public pure returns (uint256) {
        return (expectedRate_ > yearlyYield_) ?
            expectedRate_ - yearlyYield_ : yearlyYield_ - expectedRate_;
    }

    function checkSpellValues(SystemValues storage values) internal {
        // Test description
        string memory description = new SpellAction().description();
        assertTrue(bytes(description).length > 0);
        // DS-Test can't handle strings directly, so cast to a bytes32.
        assertEq(stringToBytes32(spell.description()),
            stringToBytes32(description));

        // Test expiration
        assertEq(spell.expiration(), values.expiration);
    }

    function checkLiquidationValues(
        bytes32 ilk,
        FlipAbstract flip,
        SystemValues storage values
    ) internal {
        assertEq(flip.wards(address(cat)), values.collaterals[ilk].liquidations);
    }

    function checkCollateralValues(
        bytes32 ilk,
        FlipAbstract flip,
        SystemValues storage values
    ) internal {
        (uint duty,)  = jug.ilks(ilk);
        assertEq(duty, values.collaterals[ilk].duty);
        assertTrue(diffCalc(
            expectedRate(values.collaterals[ilk].pct),
            yearlyYield(values.collaterals[ilk].duty)
        ) <= TOLERANCE);

        (,,, uint256 line,) = vat.ilks(ilk);
        assertEq(line, values.collaterals[ilk].line);

        assertEq(uint256(flip.tau()), values.collaterals[ilk].tau);
        checkLiquidationValues(ilk, flip, values);
    }

    function testSpellIsCast() public {
        vote();
        schedule();

        // Liquidation values
        checkLiquidationValues("ETH-A",  eFlip, beforeSpell);
        checkLiquidationValues("BAT-A",  bFlip, beforeSpell);
        checkLiquidationValues("USDC-A", uFlip, beforeSpell);
        checkLiquidationValues("WBTC-A", wFlip, beforeSpell);

        waitAndCast();
        assertTrue(spell.done());

        // General System values
        checkSpellValues(afterSpell);

        // Collateral values
        checkCollateralValues("ETH-A",  eFlip, afterSpell);
        checkCollateralValues("BAT-A",  bFlip, afterSpell);
        checkCollateralValues("USDC-A", uFlip, afterSpell);
        checkCollateralValues("WBTC-A", wFlip, afterSpell);
    }
}
