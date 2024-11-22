
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

// token constants
export const token_symbol: string = 'BCA1'
export const token_decimals: number = 18

// calculations
export function calculate_user_balance(deposit: number, startTime: number, dayPrice: number) {
    if (startTime <= 0) { return deposit }
    const now = new Date().getTime()
    const deltaMilsecs = now - startTime * 1000
    return Math.max(0, deposit - (dayPrice * deltaMilsecs / 24 / 3600 / 1000))
}
export function calculate_provider_balance(deposit: number, retracted: number, startTime: number, dayPrice: number) {
    if (startTime <= 0) { return deposit }
    const now = new Date().getTime()
    const deltaMilsecs = now - startTime * 1000
    return Math.max(0, Math.min(deposit, dayPrice * deltaMilsecs / 24 / 3600 / 1000) - retracted)
}

// chain viewer url
export function mk_chainviewer_url(address: string, network: string|undefined): string {
    if (network === "0x89") {
        return `<span class=\"w3-tooltip\"><a href=\"https://polygonscan.com/address/${address}\">${address}</a> <span class=\"w3-text w3-tag\"> on Polygon network: ${network} </span></span>`
    } else if (network === "0x80002") {
        return `<span class=\"w3-tooltip\"><a href=\"https://amoy.polygonscan.com/address/${address}\">${address}</a> <span class=\"w3-text w3-tag\"> on Polygon's Amoy network: ${network} </span></span>`
    } else {
        return `<span class=\"w3-tooltip\">${address} <span class=\"w3-text w3-tag\"> on network: ${network} </span></span>`
    }
}

// utilities
export function shorten_address(address: string, len: number = 6) {
    return address.substring(0,len) + ".." + address.substring(address.length - len + 1)
}
