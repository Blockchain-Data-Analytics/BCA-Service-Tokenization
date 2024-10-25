
// // local hardhat node - testnet
import deployed_address from "$lib/../../../bca-token-solidity/ignition/deployments/chain-31337/deployed_addresses.json"

// // Amoy - Polygon testnet
// import deployed_address from "$lib/../../../bca-token-solidity/ignition/deployments/chain-80002/deployed_addresses.json"

export const tokenContractAddress: string = deployed_address["BCA_Token#BCAServiceToken"]
export const contractAddresses: Record<string,string> = deployed_address

import abi_token_json from "$lib/bca_token-abi.json"
export const tokenContractABI = abi_token_json["abi"];
import abi_service_json from "$lib/bca_service-abi.json"
export const serviceContractABI = abi_service_json["abi"];
