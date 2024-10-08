<script lang="ts">
    import { onMount } from 'svelte'
    import { Web3 } from 'web3'
    import { page } from "$app/stores"
    import { superForm } from "sveltekit-superforms/client"
    // import SuperDebug from "sveltekit-superforms/client/SuperDebug.svelte"

    export let data
    const { form, errors } = superForm(data.form)

    import { WalletInformation, get_wallet_addr } from '$lib/wallet'
    let wallet = new WalletInformation()

    let has_wallet = false
    onMount ( () => {
        if (window.ethereum) {
            window.web3 = new Web3(window.ethereum);
            has_wallet = true
        } else {
            wallet.warning = "no web3 wallet attached!"
        }
    })

    async function local_get_wallet_addr(ev: MouseEvent) {
        wallet = await get_wallet_addr(wallet, ev);
        if (wallet.walletaddr) {
            $form.address = wallet.walletaddr
        }
    }

</script>

{#if $page.data.session}
<div class="w3-container w3-padding-32">

    <h2>User Preferences</h2>

    <form method="POST" action="?/update">
        <label>
            Polygon address: <input name="address" id="address" autocomplete="off" required bind:value={$form.address}/>
        </label>
        {#if $errors.address}
            <div class="w3-panel w3-red">{$errors.address}</div>
        {/if}
    {#if has_wallet}
        <section class="wallet-section">
            <p><button type="button" class="w3-btn" on:click={ (ev) => local_get_wallet_addr(ev) }>🔓 Log in with Web3</button></p>
            <span class="instruction">
            Ensure to have an Ethereum based wallet installed i.e MetaMask. Change the network and account in the wallet and 
            click the button again to update the app's state.
            </span>
            {#if wallet.warning}
                <p>web3 warning: {wallet.warning}</p>
            {/if}
        </section>
    {/if}
        <p><button type="submit" class="w3-btn w3-blue">save</button></p>
    </form>
</div>
<!-- <div class="w3-container w3-gray">
    <SuperDebug data={form}/>
</div> -->
{/if}

<style>
    #address {
        width: 388px;
    }
</style>