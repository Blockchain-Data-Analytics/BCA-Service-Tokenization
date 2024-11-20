#!/bin/sh

SRCPATH="../bca-token-solidity/artifacts/contracts"
cp -v ${SRCPATH}/BCA_Service.sol/BCAService.json src/lib/bca_service-abi.json
cp -v ${SRCPATH}/BCA_ServiceInstance.sol/BCAServiceInstance.json src/lib/bca_serviceinstance-abi.json
cp -v ${SRCPATH}/BCA_ServiceController.sol/BCAServiceController.json src/lib/bca_servicecontroller-abi.json

SRCPATH="../bca-token-solidity/ignition/deployments/chain-31337/artifacts"
cp -v ${SRCPATH}/BCA_Token#BCAServiceToken.json src/lib/bca_token-abi.json
cp -v ${SRCPATH}/BCA_ServiceManager#BCAServiceManager.json src/lib/bca_servicemanager-abi.json
