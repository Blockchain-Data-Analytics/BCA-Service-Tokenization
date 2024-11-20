
// // local hardhat node - testnet
import deployed_address from "$lib/../../../bca-token-solidity/ignition/deployments/chain-31337/deployed_addresses.json"
// import abi_token_json from "$lib/../../../bca-token-solidity/ignition/deployments/chain-31337/artifacts/BCA_Token#BCAServiceToken.json"
// import abi_servicemanager_json from "$lib/../../../bca-token-solidity/ignition/deployments/chain-31337/artifacts/BCA_ServiceManager#BCAServiceManager.json"

// // Amoy - Polygon testnet 
// import deployed_address from "$lib/../../../bca-token-solidity/ignition/deployments/chain-80002/deployed_addresses.json"

export const tokenContractAddress: string = deployed_address["BCA_Token#BCAServiceToken"]
export const serviceManagerAddress: string = deployed_address["BCA_ServiceManager#BCAServiceManager"]
export const contractAddresses: Record<string,string> = deployed_address

import abi_token_json from "$lib/bca_token-abi.json"
export const tokenContractABI = abi_token_json["abi"];
import abi_servicemanager_json from "$lib/bca_servicemanager-abi.json"
export const serviceManagerABI = abi_servicemanager_json["abi"];
import abi_servicecontroller_json from "$lib/bca_servicecontroller-abi.json"
export const serviceControllerABI = abi_servicecontroller_json["abi"];
import abi_service_json from "$lib/bca_service-abi.json"
export const serviceABI = abi_service_json["abi"];
import abi_serviceinstance_json from "$lib/bca_serviceinstance-abi.json"
export const serviceInstanceABI = abi_serviceinstance_json["abi"];
