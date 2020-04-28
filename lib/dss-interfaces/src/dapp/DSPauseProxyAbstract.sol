pragma solidity ^0.5.12;

// https://github.com/dapphub/ds-pause
contract DSPauseProxyAbstract {
    function owner() public view returns (address);
    function exec(address, bytes memory) public returns (bytes memory);
}
