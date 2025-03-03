// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/UniswapV2ERC20.sol";

contract UniswapV2ERC20Test is Test {
    UniswapV2ERC20 token;
    address alice = vm.addr(1);
    address bob = vm.addr(2);
    address carol = vm.addr(3);
    
    function setUp() public {
        token = new UniswapV2ERC20();
    }

    // 测试构造函数初始化
    function test_Constructor() public {
        bytes32 domainSeparator = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes("Uniswap V2")),
                keccak256(bytes("1")),
                block.chainid,
                address(token)
            )
        );
        assertEq(token.DOMAIN_SEPARATOR(), domainSeparator);
    }

    // 测试铸币功能
    function test_Mint() public {
        vm.prank(alice);
        token._mint(alice, 100);

        assertEq(token.totalSupply(), 100);
        assertEq(token.balanceOf(alice), 100);
    }

    // 测试销毁功能
    function test_Burn() public {
        token._mint(alice, 100);
        
        vm.prank(alice);
        token._burn(alice, 40);

        assertEq(token.totalSupply(), 60);
        assertEq(token.balanceOf(alice), 60);
    }

    // 测试转账功能
    function test_Transfer() public {
        token._mint(alice, 100);
        
        vm.prank(alice);
        token.transfer(bob, 50);

        assertEq(token.balanceOf(alice), 50);
        assertEq(token.balanceOf(bob), 50);
    }

    // 测试授权转账
    function test_TransferFrom() public {
        token._mint(alice, 100);
        vm.prank(alice);
        token.approve(bob, 60);

        vm.prank(bob);
        token.transferFrom(alice, carol, 50);

        assertEq(token.allowance(alice, bob), 10);
        assertEq(token.balanceOf(carol), 50);
    }

    // 测试无限授权
    function test_InfiniteApproval() public {
        token._mint(alice, 100);
        vm.prank(alice);
        token.approve(bob, type(uint).max);

        vm.prank(bob);
        token.transferFrom(alice, carol, 80);

        assertEq(token.allowance(alice, bob), type(uint).max);
    }

    // 测试许可签名
    function test_Permit() public {
        uint privateKey = 0x1234;
        address owner = vm.addr(privateKey);
        uint value = 1000;
        uint deadline = block.timestamp + 1 days;

        // 生成签名
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            privateKey,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    token.DOMAIN_SEPARATOR(),
                    keccak256(
                        abi.encode(
                            token.PERMIT_TYPEHASH(),
                            owner,
                            bob,
                            value,
                            token.nonces(owner),
                            deadline
                        )
                    )
                )
            )
        );

        // 执行许可
        token.permit(owner, bob, value, deadline, v, r, s);

        assertEq(token.allowance(owner, bob), value);
        assertEq(token.nonces(owner), 1);
    }

    // 测试边界条件
    function testFuzz_EdgeCases(address to, uint256 amount) public {
        vm.assume(to != address(0));
        vm.assume(amount < type(uint256).max);

        // 测试最大铸币
        token._mint(to, type(uint256).max);
        assertEq(token.balanceOf(to), type(uint256).max);

        // 测试销毁全部
        token._burn(to, type(uint256).max);
        assertEq(token.balanceOf(to), 0);
    }

    // 测试异常情况
    function test_Revert_TransferInsufficientBalance() public {
        token._mint(alice, 100);
        
        vm.prank(alice);
        vm.expectRevert();
        token.transfer(bob, 101);
    }

    function test_Revert_ExpiredPermit() public {
        uint expiredDeadline = block.timestamp - 1;
        
        vm.expectRevert("UniswapV2: EXPIRED");
        token.permit(alice, bob, 100, expiredDeadline, 0, 0, 0);
    }
}