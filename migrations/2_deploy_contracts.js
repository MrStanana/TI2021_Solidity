const Lease = artifacts.require('Lease');

module.exports = (deployer) => deployer.deploy(Lease, '0x0000000000000000000000000000000000000000000000000000000000000000', 100, 10, 3 * 60, 5, 10);
