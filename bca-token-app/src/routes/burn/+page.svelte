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
            warning = "no web3 wallet attached!"
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

    async function burn_tokens(fromAddress: string, amount: number, useGas: number) {
        if (window.web3 && wallet.walletaddr !== undefined) {
            const contract = new window.web3.eth.Contract(contractABI, contractAddress);
            try {
                const decimals: number = Number(await contract.methods.decimals().call());
                const gasPrice = await window.web3.eth.getGasPrice();
                var estimatedGas = useGas;
                if (wallet.walletnetwork === "0x89") { // Polygon
                    estimatedGas = await contract.methods.setServiceAddress(toAddress).estimateGas();
                    console.log("estimated gas: " + estimatedGas);
                }
                contract.methods.totalSupply().call((err, result) => {
                    if(err){
                        console.error('Error: ', err);
                        // handle the error here
                    } else {
                        console.log("total supply: " + window.web3.utils.fromWei(result, 'BCA1'));
                        // You can add supply now to whatever part
                        // of your page you want it displayed
                    }
                    });

                const receipt = await contract.methods
                    .burn(fromAddress, amount * (10 ** decimals))
                    .send({
                        from: wallet.walletaddr,
                        gas: estimatedGas,
                        gasPrice: gasPrice,
                    });

                await ( log(wallet.walletaddr, amount, "burn_tokens", fromAddress, receipt.transactionHash) )

            } catch (error) {
                console.error(error);
            }
        }
    }

    const { form, handleChange, handleSubmit } = createForm({
        initialValues: {
            address: "0x..",
            amount: "100",
            gas: "75000"
        },
        onSubmit: values => {
            // alert(JSON.stringify(values));
            burn_tokens(values.address, parseInt(values.amount), parseInt(values.gas));
        }
        });

</script>

<svelte:head>
        <title>BCA Wallet: burning tokens</title>
        <meta name="description" content="wallet" />
</svelte:head>

<h1>BCA Tokens: burning</h1>

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
    <h3 class="wallet-status">Wallet selection</h3>
    <h4 class="wallet-address-heading">
      Wallet address:
      <span class="typewriter">{wallet.networkname}({wallet.network})</span> / 
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
    <h3>Burning tokens</h3>
    <form on:submit={handleSubmit}>
        <label for="address">from service address</label>
        <input
          id="address"
          name="address"
          on:change={handleChange}
          bind:value={$form.address}
        />
        <label for="amount">amount</label>
        <input
          id="amount"
          name="amount"
          on:change={handleChange}
          bind:value={$form.amount}
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
        <button type="submit">Burn</button>
      </form>
    {/if}
</section>
{/if}

<style>
    #address {
        width: 348px;
    }
    #amount {
        width: 48px;
    }
    #gas {
        width: 54px;
    }
</style>