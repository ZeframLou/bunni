pragma solidity ^0.8.6;

import "ds-test/test.sol";

import "./Bugsbuni.sol";

contract BugsbuniTest is DSTest {
    Bugsbuni bugsbuni;

    function setUp() public {
        bugsbuni = new Bugsbuni();
    }

    function testFail_basic_sanity() public {
        assertTrue(false);
    }

    function test_basic_sanity() public {
        assertTrue(true);
    }
}
