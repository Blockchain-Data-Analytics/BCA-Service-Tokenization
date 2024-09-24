import { contractAddress, contractABI } from "$lib/contract"


export class WalletInformation {
    warning: string | undefined
    walletnetwork: string | undefined
    networkname: string | undefined
    walletaddr: string | undefined
    walletbalance: number | undefined    
}

export async function get_wallet_chainid(wallet: WalletInformation): Promise<WalletInformation> {
    try {
        window.ethereum.request({ method: 'eth_chainId' }).then(function(v: string) {
            wallet.walletnetwork = v;
            if (wallet.walletnetwork === "0x1") { wallet.networkname = "ethereum" }
            if (wallet.walletnetwork === "0x89") { wallet.networkname = "polygon" }
            if (wallet.walletnetwork === "0xa4b1") { wallet.networkname = "arbitrum" }
            if (wallet.walletnetwork === "0xa86a") { wallet.networkname = "avalanche" }
            if (wallet.walletnetwork === "0x13882") { wallet.networkname = "polygon amoy testnet" }
        })
        wallet.warning = undefined;
    } catch (error) {
        wallet.warning = "error while accessing wallet: " + error;
    }
    return wallet
}

export function reset_warning(wallet: WalletInformation) {
    wallet.warning = undefined
}

export async function wallet_logout(wallet: WalletInformation): Promise<WalletInformation> {
    if (window.web3 && wallet.walletaddr !== undefined) {
        await window.ethereum.request({
            "method": "wallet_revokePermissions",
            "params": [
                {
                "eth_accounts": { "addr": wallet.walletaddr }
                }
            ]
            });
    }
    wallet.walletnetwork = undefined
    wallet.networkname = ""
    wallet.walletaddr = undefined
    wallet.walletbalance = undefined
    return wallet
}

export async function get_wallet_balance(wallet: WalletInformation, ev: any): Promise<WalletInformation> {
    if (window.web3 && wallet.walletaddr !== undefined) {
        ev.target.setAttribute("disabled","disabled")
        const contract = new window.web3.eth.Contract(contractABI, contractAddress);
        const decimals: number = Number(await contract.methods.decimals().call());
        // await contract.methods.decimals().call().then(console.log);
                // const decimals = await contract.methods.decimals().call();
        // const decimals = 10;
        console.log("decimals = " + decimals)
        wallet.walletbalance = Number(await window.web3.eth.getBalance(wallet.walletaddr));
        if (!!wallet.walletbalance) { wallet.walletbalance = wallet.walletbalance / (10 ** decimals) }
        wallet.warning = undefined
        ev.target.removeAttribute("disabled")
    } else {
        wallet.walletbalance = undefined;
    }
    return wallet
}

export async function get_wallet_addr(wallet: WalletInformation, ev: any): Promise<WalletInformation> {
    if (window.web3) {
        ev.target.setAttribute("disabled","disabled")
        try {
            // get active network in wallet
            wallet = await get_wallet_chainid(wallet)
            // request user's account address - prompts Metamask to login
            const selectedAccount = await window.ethereum
                .request({
                    method: "eth_requestAccounts",
                })
                .then((accs: {}[]) => accs[0])
                .catch(() => {
                    throw Error("Please select an account in your wallet");
                });

            wallet.walletaddr = selectedAccount;
            wallet.warning = undefined
            console.log("address: " + wallet.walletaddr)
            console.log("network: " + wallet.walletnetwork)

        } catch (error) {
            wallet.warning = "error while accessing wallet: " + error;
        }
        ev.target.removeAttribute("disabled")
    } else {
        console.log("wallet not found")
        wallet.warning = "wallet not found"
    }
    return wallet;
}