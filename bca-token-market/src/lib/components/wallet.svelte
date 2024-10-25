<script lang="ts">
    // import { onMount } from 'svelte';
    // import { Web3 } from 'web3';
    import { WalletInformation, get_wallet_addr, wallet_logout } from '$lib/wallet'

    export let wallet = new WalletInformation()

    // onMount ( async () => {
    //     if (window.ethereum && ! window.web3) {
    //         window.web3 = new Web3(window.ethereum);
    //     }
    // })

    async function login_wallet(ev) {
        wallet = await get_wallet_addr(wallet, ev)
    }
    async function logout_wallet() {
        wallet = await wallet_logout(wallet)
    }
</script>

<div class="">
    {#if wallet.walletaddr}
    <div class="w3-dropdown-hover">
        <button class="w3-btn w3-small" id="address">{wallet.walletaddr.substring(0,6)}..{wallet.walletaddr.substring(wallet.walletaddr.length - 5)}</button>
        <div class="w3-dropdown-content w3-bar-block w3-border">
          <a href="#" class="w3-bar-item w3-button w3-small">{wallet.walletaddr}</a>
          <a href="#" class="w3-bar-item w3-button">network: {wallet.networkname ? wallet.networkname : '' } {wallet.walletnetwork}</a>
        </div>
    </div> 
    <button type="button" class="w3-btn" on:click={() => logout_wallet()}><i class="w3-tooltip fa fa-sign-out"> <span class="w3-text">disconnect wallet</span></i></button>
    {:else}
    <button type="button" class="w3-btn" on:click={ev => login_wallet(ev)}><i class="w3-tooltip fa fa-sign-in"> <span class="w3-text">connect wallet</span></i></button>
    {/if}
</div>

<style>

</style>