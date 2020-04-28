pragma solidity ^0.5.12;

import {DSTest}  from "ds-test/test.sol";
import {DSToken} from "ds-token/token.sol";
import "../flop.sol";
import "../vat.sol";


contract Hevm {
    function warp(uint256) public;
}

contract Guy {
    Flopper flop;
    constructor(Flopper flop_) public {
        flop = flop_;
        Vat(address(flop.vat())).hope(address(flop));
        DSToken(address(flop.gem())).approve(address(flop));
    }
    function dent(uint id, uint lot, uint bid) public {
        flop.dent(id, lot, bid);
    }
    function deal(uint id) public {
        flop.deal(id);
    }
    function try_dent(uint id, uint lot, uint bid)
        public returns (bool ok)
    {
        string memory sig = "dent(uint256,uint256,uint256)";
        (ok,) = address(flop).call(abi.encodeWithSignature(sig, id, lot, bid));
    }
    function try_deal(uint id)
        public returns (bool ok)
    {
        string memory sig = "deal(uint256)";
        (ok,) = address(flop).call(abi.encodeWithSignature(sig, id));
    }
    function try_tick(uint id)
        public returns (bool ok)
    {
        string memory sig = "tick(uint256)";
        (ok,) = address(flop).call(abi.encodeWithSignature(sig, id));
    }
}

contract Gal {}

contract Vatish is DSToken('') {
    uint constant ONE = 10 ** 27;
    function move(address src, address dst, uint rad) public {
        super.move(src, dst, rad);
    }
    function hope(address usr) public {
         super.approve(usr);
    }
    function dai(address usr) public view returns (uint) {
         return super.balanceOf(usr);
    }
}

contract FlopTest is DSTest {
    Hevm hevm;

    Flopper flop;
    Vat     vat;
    DSToken gem;

    address ali;
    address bob;
    address gal;

    function kiss(uint) public pure { }  // arbitrary callback

    function setUp() public {
        hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
        hevm.warp(604411200);

        vat = new Vat();
        gem = new DSToken('');

        flop = new Flopper(address(vat), address(gem));

        ali = address(new Guy(flop));
        bob = address(new Guy(flop));
        gal = address(new Gal());

        vat.hope(address(flop));
        vat.rely(address(flop));
        gem.approve(address(flop));

        vat.suck(address(this), address(this), 1000 ether);

        vat.move(address(this), ali, 200 ether);
        vat.move(address(this), bob, 200 ether);
    }
    function test_kick() public {
        assertEq(vat.dai(address(this)), 600 ether);
        assertEq(gem.balanceOf(address(this)),   0 ether);
        flop.kick({ lot: 200 ether   // or whatever high starting value
                  , gal: gal
                  , bid: 0
                  });
        // no value transferred
        assertEq(vat.dai(address(this)), 600 ether);
        assertEq(gem.balanceOf(address(this)),   0 ether);
    }
    function test_dent() public {
        uint id = flop.kick({ lot: 200 ether   // or whatever high starting value
                            , gal: gal
                            , bid: 10 ether
                            });

        Guy(ali).dent(id, 100 ether, 10 ether);
        // bid taken from bidder
        assertEq(vat.dai(ali), 190 ether);
        // gal receives payment
        assertEq(vat.dai(gal),  10 ether);

        Guy(bob).dent(id, 80 ether, 10 ether);
        // bid taken from bidder
        assertEq(vat.dai(bob), 190 ether);
        // prev bidder refunded
        assertEq(vat.dai(ali), 200 ether);
        // gal receives no more
        assertEq(vat.dai(gal), 10 ether);

        hevm.warp(now + 5 weeks);
        assertEq(gem.totalSupply(),  0 ether);
        gem.setOwner(address(flop));
        Guy(bob).deal(id);
        // gems minted on demand
        assertEq(gem.totalSupply(), 80 ether);
        // bob gets the winnings
        assertEq(gem.balanceOf(bob), 80 ether);
    }
    function test_tick() public {
        // start an auction
        uint id = flop.kick({ lot: 200 ether   // or whatever high starting value
                            , gal: gal
                            , bid: 10 ether
                            });
        // check no tick
        assertTrue(!Guy(ali).try_tick(id));
        // run past the end
        hevm.warp(now + 2 weeks);
        // check not biddable
        assertTrue(!Guy(ali).try_dent(id, 100 ether, 10 ether));
        assertTrue( Guy(ali).try_tick(id));
        // check biddable
        (, uint _lot,,,) = flop.bids(id);
        // tick should increase the lot by pad (50%) and restart the auction
        assertEq(_lot, 300 ether);
        assertTrue( Guy(ali).try_dent(id, 100 ether, 10 ether));
    }
    function test_no_deal_after_end() public {
        // if there are no bids and the auction ends, then it should not
        // be refundable to the creator. Rather, it ticks indefinitely.
        uint id = flop.kick({ lot: 200 ether   // or whatever high starting value
                            , gal: gal
                            , bid: 10 ether
                            });
        assertTrue(!Guy(ali).try_deal(id));
        hevm.warp(now + 2 weeks);
        assertTrue(!Guy(ali).try_deal(id));
        assertTrue( Guy(ali).try_tick(id));
        assertTrue(!Guy(ali).try_deal(id));
    }
    function test_yank() public {
        // yanking the auction should refund the last bidder's dai, credit a
        // corresponding amount of sin to the caller of cage, and delete the auction.
        // in practice, gal == (caller of cage) == (vow address)
        uint id = flop.kick({ lot: 200 ether   // or whatever high starting value
                            , gal: gal
                            , bid: 10 ether
                            });

        // confrim initial state expectations
        assertEq(vat.dai(ali), 200 ether);
        assertEq(vat.dai(bob), 200 ether);
        assertEq(vat.dai(gal), 0);
        assertEq(vat.sin(address(this)), 1000 ether);

        Guy(ali).dent(id, 100 ether, 10 ether);
        Guy(bob).dent(id, 80 ether, 10 ether);

        // confirm the proper state updates have occurred
        assertEq(vat.dai(ali), 200 ether);  // ali's dai balance is unchanged
        assertEq(vat.dai(bob), 190 ether);
        assertEq(vat.dai(gal),  10 ether);
        assertEq(vat.sin(address(this)), 1000 ether);

        flop.cage();
        flop.yank(id);

        // confirm final state
        assertEq(vat.dai(ali), 200 ether);
        assertEq(vat.dai(bob), 200 ether);  // bob's bid has been refunded
        assertEq(vat.dai(gal), 10 ether);
        assertEq(vat.sin(address(this)), 1010 ether);  // sin assigned to caller of cage()
        (uint256 _bid, uint256 _lot, address _guy, uint48 _tic, uint48 _end) = flop.bids(id);
        assertEq(_bid, 0);
        assertEq(_lot, 0);
        assertEq(_guy, address(0));
        assertEq(uint256(_tic), 0);
        assertEq(uint256(_end), 0);
    }
    function test_yank_no_bids() public {
        // with no bidder to refund, yanking the auction should simply create equal
        // amounts of dai (credited to the gal) and sin (credited to the caller of cage)
        // in practice, gal == (caller of cage) == (vow address)
        uint id = flop.kick({ lot: 200 ether   // or whatever high starting value
                            , gal: gal
                            , bid: 10 ether
                            });

        // confrim initial state expectations
        assertEq(vat.dai(ali), 200 ether);
        assertEq(vat.dai(bob), 200 ether);
        assertEq(vat.dai(gal), 0);
        assertEq(vat.sin(address(this)), 1000 ether);

        flop.cage();
        flop.yank(id);

        // confirm final state
        assertEq(vat.dai(ali), 200 ether);
        assertEq(vat.dai(bob), 200 ether);
        assertEq(vat.dai(gal),  10 ether);
        assertEq(vat.sin(address(this)), 1010 ether);  // sin assigned to caller of cage()
        (uint256 _bid, uint256 _lot, address _guy, uint48 _tic, uint48 _end) = flop.bids(id);
        assertEq(_bid, 0);
        assertEq(_lot, 0);
        assertEq(_guy, address(0));
        assertEq(uint256(_tic), 0);
        assertEq(uint256(_end), 0);
    }
}
