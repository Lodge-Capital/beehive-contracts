// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

contract MockERC20 {
  string public name = "MockToken";
  string public symbol = "MCK";
  uint8 public decimals = 18;
  uint public totalSupply;
  mapping(address => uint) public balanceOf;
  mapping(address => mapping(address => uint)) public allowance;

  event Transfer(address indexed from, address indexed to, uint value);
  event Approval(address indexed owner, address indexed spender, uint value);

  function mint(address to, uint amount) external {
    totalSupply += amount;
    balanceOf[to] += amount;
    emit Transfer(address(0), to, amount);
  }

  function approve(address spender, uint amount) external returns (bool) {
    allowance[msg.sender][spender] = amount;
    emit Approval(msg.sender, spender, amount);
    return true;
  }

  function transfer(address to, uint amount) external returns (bool) {
    require(balanceOf[msg.sender] >= amount, "insufficient");
    balanceOf[msg.sender] -= amount;
    balanceOf[to] += amount;
    emit Transfer(msg.sender, to, amount);
    return true;
  }

  function transferFrom(address from, address to, uint amount) external returns (bool) {
    require(balanceOf[from] >= amount, "insufficient");
    require(allowance[from][msg.sender] >= amount, "no allowance");
    allowance[from][msg.sender] -= amount;
    balanceOf[from] -= amount;
    balanceOf[to] += amount;
    emit Transfer(from, to, amount);
    return true;
  }
}