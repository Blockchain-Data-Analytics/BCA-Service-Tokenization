<script lang="ts">
    import { onMount } from 'svelte';
    import { Web3 } from 'web3';

    import { createForm } from "svelte-forms-lib";

    // import abi from "../../lib/amoy_token-abi.json";
    import abi_json from "../../../lib/bca_token-abi.json";
    const abi = abi_json.abi;

    const contractAddress = "0x5fbdb2315678afecb367f032d93f642f64180aa3";

    let warning = undefined
    let walletnetwork = undefined
    let networkname : string = "unknown"
    let walletaddr: string | undefined = undefined
    let walletbalance = undefined

    onMount ( () => {
        if (window.ethereum) {
            window.web3 = new Web3(window.ethereum);
        } else {
            warning = "no web3 wallet attached!"
        }
    })

    async function get_wallet_chainid() {
        try {
            window.ethereum.request({ method: 'eth_chainId' }).then(function(v) {
                walletnetwork = v;
                if (walletnetwork === "0x1") { networkname = "ethereum" } else
                if (walletnetwork === "0x89") { networkname = "polygon" } else
                if (walletnetwork === "0xa4b1") { networkname = "arbitrum" } else
                if (walletnetwork === "0xa86a") { networkname = "avalanche" } else
                if (walletnetwork === "0x13882") { networkname = "polygon amoy testnet" } else
                networkname = "unknown or local"
            })
            warning = undefined;
        } catch (error) {
            warning = "error while accessing wallet: " + error;
        }
    }
    function reset_warning() { warning = undefined }

    async function wallet_logout() {
        if (window.web3 && walletaddr !== undefined) {
            await window.ethereum.request({
                "method": "wallet_revokePermissions",
                "params": [
                    {
                    "eth_accounts": { "addr": walletaddr }
                    }
                ]
                });
        }
        walletnetwork = undefined
        networkname = ""
        walletaddr = undefined
        walletbalance = undefined
    }
    async function get_wallet_balance(ev) {
        if (window.web3 && walletaddr !== undefined) {
            ev.target.setAttribute("disabled","disabled")
            walletbalance = await window.web3.eth.getBalance(walletaddr);
            warning = undefined
            ev.target.removeAttribute("disabled")
        } else {
            walletbalance = undefined;
        }
    }
    async function get_wallet_addr(ev) {
        if (window.web3) {
            ev.target.setAttribute("disabled","disabled")
            try {
                // get active network in wallet
                get_wallet_chainid()
                // request user's account address - prompts Metamask to login
                const selectedAccount = await window.ethereum
                    .request({
                        method: "eth_requestAccounts",
                    })
                    .then((accs) => accs[0])
                    .catch(() => {
                        throw Error("Please select an account in your wallet");
                    });

                walletaddr = selectedAccount;
                warning = undefined

            } catch (error) {
                warning = "error while accessing wallet: " + error;
            }
            ev.target.removeAttribute("disabled")
        } else {
            warning = "wallet not found";
        }
    }

    async function setServiceAccount(toAddress) {
        if (window.web3 && walletaddr !== undefined) {
            const contract = new window.web3.eth.Contract(abi, contractAddress);
            contract.setConfig({ "defaultNetworkId": walletnetwork });
            try {
                // await contract.methods.balanceOf(contractAddress).call().then(console.log);
                // await contract.methods.name().call().then(console.log);
                // await contract.methods.symbol().call().then(console.log);
                // await contract.methods.decimals().call().then(console.log);
                const gasPrice = await window.web3.eth.getGasPrice();
                const estimatedGas = await contract.methods.setServiceAccount(toAddress)
                    .estimateGas();
                console.log("estimated gas: " + estimatedGas);
                const receipt = await contract.methods
                    .setServiceAccount(toAddress)
                    .send({
                        from: walletaddr,
                        gas: estimatedGas,
                        gasPrice: gasPrice,
                    });
                console.log("Transaction Hash: " + receipt.transactionHash);
            } catch (error) {
                console.error(error);
            }
        }
    }

    const { form, handleChange, handleSubmit } = createForm({
        initialValues: {
            address: "0x590Ea4B.. guessed ..26060e9c3fB6"
        },
        onSubmit: values => {
            // alert(JSON.stringify(values));
            setServiceAccount(values.address);
        }
        });

</script>

<svelte:head>
        <title>BCA Wallet: minting tokens</title>
        <meta name="description" content="wallet" />
</svelte:head>

<h1>BCA Tokens: administration - Danger Zone !!</h1>

{#if warning !== undefined}
<p>Warning: {warning}</p>
<p><button type="button" on:click={ () => reset_warning() }>reset warning</button></p>
{:else}
<!-- LOGIN SECTION -->
<section class="login-section">
    <p><button type="button" class="login-btn" on:click={ (ev) => get_wallet_addr(ev) }>🔓 Log in with Web3</button></p>
    <span class="instruction">
      Ensure to have an Ethereum based wallet installed i.e MetaMask. Change the network and account in the wallet and 
      click the button again to update the app's state.
    </span>
</section>

<!-- DASHBOARD SECTION -->
<section class="dashboard-section">
    {#if walletnetwork !== undefined && walletaddr !== undefined}
    <h3 class="wallet-status">Wallet available</h3>
    <h4 class="wallet-address-heading">
      Wallet address:
      <span class="typewriter">{networkname}({walletnetwork})</span> / 
      <span class="typewriter">{walletaddr}</span>
    </h4>
    {#if walletbalance !== undefined}
    <h4 class="wallet-balance-heading">
     Balance:
      <span class="wallet-balance">{walletbalance}</span>
    </h4>
    {/if}
    <p><button type="button" on:click={ (ev) => get_wallet_balance(ev) }>refresh balance</button></p>
    <p><button type="button" class="logout-btn" on:click={ () => wallet_logout() }>🔐 Log out</button></p>
    {/if}
</section>

<section class="action">
    {#if walletnetwork !== undefined && walletaddr !== undefined}
    <h3>Change Service Account</h3>
    <form on:submit={handleSubmit}>
        <label for="address">address</label>
        <input
          id="address"
          name="address"
          on:change={handleChange}
          bind:value={$form.address}
        />    
        <button type="submit">Set Service Address</button>
      </form>
    {/if}
</section>
{/if}

