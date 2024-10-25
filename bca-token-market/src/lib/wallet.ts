
export class WalletInformation {
    warning: string | undefined
    walletnetwork: string | undefined
    networkname: string | undefined
    walletaddr: string | undefined
}

export async function get_wallet_chainid(wallet: WalletInformation): Promise<WalletInformation> {
    try {
        window.ethereum.request({ method: 'eth_chainId' }).then(function(v: string) {
            wallet.walletnetwork = v;
            if (wallet.walletnetwork === "0x1") { wallet.networkname = "ethereum" }
            if (wallet.walletnetwork === "0x89") { wallet.networkname = "polygon" }
            if (wallet.walletnetwork === "0xa4b1") { wallet.networkname = "arbitrum" }
            if (wallet.walletnetwork === "0xa86a") { wallet.networkname = "avalanche" }
            if (wallet.walletnetwork === "0x7a69") { wallet.networkname = "local" }
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
    return wallet
}

export async function get_wallet_addr(wallet: WalletInformation, ev: any): Promise<WalletInformation> {
    if (window.web3) {
        if (ev.target) { ev.target.setAttribute("disabled","disabled") }
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
        if (ev.target) { ev.target.removeAttribute("disabled") }
    } else {
        console.log("wallet not found")
        wallet.warning = "wallet not found"
    }
    return wallet;
}