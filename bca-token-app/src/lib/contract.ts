
// // local hardhat node - testnet
// // import deployed_address from "$lib/../../../bca-token-solidity/ignition/deployments/chain-31337/deployed_addresses.json"

// // Amoy - Polygon testnet
import deployed_address from "$lib/../../../bca-token-solidity/ignition/deployments/chain-80002/deployed_addresses.json"

export const contractAddress: string = deployed_address["BCA_Token#BCAServiceToken"]

// // local hardhat node - testnet
// // import abi_json from "$lib/bca_token-abi.json"

// // Amoy - Polygon testnet
import abi_json from "$lib/bca_token-abi.json"

export const contractABI = abi_json["abi"];
