// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import "../src/UniswapV2ERC20.sol";

contract UniswapV2ERC20Harness is UniswapV2ERC20 {
    // 暴露所有需要测试的internal函数
    function mint(address to, uint value) public {
        _mint(to, value);
    }

    function burn(address from, uint value) public {
        _burn(from, value);
    }

    function callTransfer(address from, address to, uint value) public {
        _transfer(from, to, value);
    }

    function callApprove(address owner, address spender, uint value) public {
        _approve(owner, spender, value);
    }
}

contract UniswapV2ERC20Test is Test {
    UniswapV2ERC20Harness token; // 改为使用Harness合约
    address alice = vm.addr(1);
    address bob = vm.addr(2);
    address carol = vm.addr(3);
    
    function setUp() public {
        token = new UniswapV2ERC20Harness(); // 实例化Harness合约
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

    // 测试铸币功能（通过Harness）
    function test_Mint() public {
        token.mint(alice, 100); // 改为调用Harness的public方法

        assertEq(token.totalSupply(), 100);
        assertEq(token.balanceOf(alice), 100);
    }

    // 测试销毁功能（通过Harness）
    function test_Burn() public {
        token.mint(alice, 100); // 使用Harness方法
        
        token.burn(alice, 40); // 使用Harness方法

        assertEq(token.totalSupply(), 60);
        assertEq(token.balanceOf(alice), 60);
    }

    // 测试转账功能
    function test_Transfer() public {
        token.mint(alice, 100);
        
        vm.prank(alice);
        token.transfer(bob, 50);

        assertEq(token.balanceOf(alice), 50);
        assertEq(token.balanceOf(bob), 50);
    }

    // 测试授权转账
    function test_TransferFrom() public {
        token.mint(alice, 100);
        vm.prank(alice);
        token.approve(bob, 60);

        vm.prank(bob);
        token.transferFrom(alice, carol, 50);

        assertEq(token.allowance(alice, bob), 10);
        assertEq(token.balanceOf(carol), 50);
    }

    // 测试无限授权
    function test_InfiniteApproval() public {
        token.mint(alice, 100);
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

    // 测试边界条件（通过Harness）
    function testFuzz_EdgeCases(address to, uint256 amount) public {
        vm.assume(to != address(0));
        vm.assume(amount < type(uint256).max);

        // 使用Harness方法
        token.mint(to, type(uint256).max);
        assertEq(token.balanceOf(to), type(uint256).max);

        token.burn(to, type(uint256).max);
        assertEq(token.balanceOf(to), 0);
    }

    // 测试异常情况
    function test_Revert_TransferInsufficientBalance() public {
        token.mint(alice, 100);
        
        vm.prank(alice);
        vm.expectRevert();
        token.transfer(bob, 101);
    }

    function test_Revert_ExpiredPermit() public {
        uint expiredDeadline = block.timestamp - 1;
        
        vm.expectRevert("UniswapV2: EXPIRED");
        token.permit(alice, bob, 100, expiredDeadline, 0, 0, 0);
    }

    // 新增：测试直接转账函数
    function test_InternalTransfer() public {
        token.mint(address(this), 100);
        token.callTransfer(address(this), bob, 70); // 测试internal _transfer
        
        assertEq(token.balanceOf(bob), 70);
    }

    // 新增：测试直接授权函数
    function test_InternalApprove() public {
        token.callApprove(address(this), bob, 500); // 测试internal _approve
        
        assertEq(token.allowance(address(this), bob), 500);
    }
}