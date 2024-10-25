<script lang="ts">
    import { onMount } from 'svelte';
    import { Web3 } from 'web3';

    import { createForm } from "svelte-forms-lib";

    import { contractAddress, contractABI } from "$lib/contract"
    import { log } from "$lib/log"

    import { WalletInformation, reset_warning, get_wallet_addr, get_wallet_balance, wallet_logout } from '$lib/wallet'

    let wallet = new WalletInformation()

    onMount ( () => {
        if (window.ethereum) {
            window.web3 = new Web3(window.ethereum);
        } else {
            wallet.warning = "no web3 wallet attached!"
        }
    })

    async function local_get_wallet_addr(ev) {
        wallet = await get_wallet_addr(wallet, ev);
    }
    async function local_get_wallet_balance(ev) {
        wallet = await get_wallet_balance(wallet, ev);
    }
    async function local_wallet_logout() {
        wallet = await wallet_logout(wallet)
    }
    function local_reset_warning() {
        reset_warning(wallet);
    }

    async function setServiceAccount(toAddress: string, useGas: number) {
        if (window.web3 && wallet.walletaddr !== undefined) {
            const contract = new window.web3.eth.Contract(contractABI, contractAddress);
            contract.setConfig({ "defaultNetworkId": wallet.walletnetwork });
            try {
                // await contract.methods.balanceOf(contractAddress).call().then(console.log);
                // await contract.methods.name().call().then(console.log);
                // await contract.methods.symbol().call().then(console.log);
                // await contract.methods.decimals().call().then(console.log);
                const gasPrice = await window.web3.eth.getGasPrice();
                let estimatedGas = useGas;
                if (wallet.walletnetwork === "0x89") { // Polygon
                    estimatedGas = await contract.methods.setServiceAddress(toAddress).estimateGas();
                    console.log("estimated gas: " + estimatedGas);
                }
                const receipt = await contract.methods
                    .setServiceAddress(toAddress)
                    .send({
                        from: wallet.walletaddr,
                        gas: estimatedGas,
                        gasPrice: gasPrice,
                    });

                await ( log(wallet.walletaddr, 0, "setServiceAccount", toAddress, receipt.transactionHash) )

            } catch (error) {
                console.error(error);
            }
        }
    }

    const { form, handleChange, handleSubmit } = createForm({
        initialValues: {
            address: "0x590Ea4B.. guessed ..26060e9c3fB6",
            gas: "45000"
        },
        onSubmit: values => {
            // alert(JSON.stringify(values));
            setServiceAccount(values.address, parseInt(values.gas));
        }
        });

</script>

<svelte:head>
        <title>BCA Wallet: minting tokens</title>
        <meta name="description" content="wallet" />
</svelte:head>

<div class="w3-container w3-padding-32">

<h1>BCA Tokens: administration - Danger Zone !!</h1>

{#if wallet.warning !== undefined}
<p>Warning: {wallet.warning}</p>
<p><button type="button" on:click={ () => local_reset_warning() }>reset warning</button></p>
{:else}
<!-- LOGIN SECTION -->
<section class="login-section">
    <p><button type="button" class="login-btn" on:click={ (ev) => local_get_wallet_addr(ev) }>🔓 Log in with Web3</button></p>
    <span class="instruction">
      Ensure to have an Ethereum based wallet installed i.e MetaMask. Change the network and account in the wallet and 
      click the button again to update the app's state.
    </span>
</section>

<!-- DASHBOARD SECTION -->
<section class="dashboard-section">
    {#if wallet.walletnetwork !== undefined && wallet.walletaddr !== undefined}
    <h3 class="wallet-status">Wallet available</h3>
    <h4 class="wallet-address-heading">
      Wallet address:
      <span class="typewriter">{wallet.networkname}({wallet.walletnetwork})</span> / 
      <span class="typewriter">{wallet.walletaddr}</span>
    </h4>
    {#if wallet.walletbalance !== undefined}
    <h4 class="wallet-balance-heading">
     Balance:
      <span class="wallet-balance">{wallet.walletbalance}</span>
    </h4>
    {/if}
    <p><button type="button" on:click={ (ev) => local_get_wallet_balance(ev) }>refresh balance</button></p>
    <p><button type="button" class="logout-btn" on:click={ () => local_wallet_logout() }>🔐 Log out</button></p>
    {/if}
</section>

<section class="action">
    {#if wallet.walletnetwork !== undefined && wallet.walletaddr !== undefined}
    <h3>Change Service Account</h3>
    <form on:submit={handleSubmit}>
        <label for="address">address</label>
        <input
          id="address"
          name="address"
          on:change={handleChange}
          bind:value={$form.address}
        />
        {#if wallet.walletnetwork !== "0x89" }
        <label for="address">gas:</label>
        <input
          id="gas"
          name="gas"
          on:change={handleChange}
          bind:value={$form.gas}
        />
        {/if}
        <button type="submit">Set Service Address</button>
      </form>
    {/if}
</section>
{/if}
</div>

<style>
    #address {
        width: 348px;
    }
    #gas {
        width: 54px;
    }
</style>