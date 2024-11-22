<script lang="ts">
    import { onMount } from 'svelte';
    import { SignIn, SignOut } from "@auth/sveltekit/components"
    import { page } from "$app/stores"
    import { get_wallet_addr, reset_warning, wallet_logout, WalletInformation } from '$lib/wallet'
    import Wallet from "$lib/components/wallet.svelte"
    import { mk_chainviewer_url, serviceManagerAddress } from '$lib/contracts';
    import Page from './servicemanager/+page.svelte';
    import Web3 from 'web3';

    let wallet = new WalletInformation()

    onMount ( async () => {
        if (window.ethereum) {
            window.web3 = new Web3(window.ethereum);
            local_get_wallet_addr({target: undefined})
        }
    })

    $: has_wallet = !!wallet.walletaddr

    async function local_get_wallet_addr(ev) {
        wallet = await get_wallet_addr(wallet, ev);
    }
    async function local_wallet_logout() {
        wallet = await wallet_logout(wallet)
    }
    function local_reset_warning() {
        reset_warning(wallet);
    }
</script>

<div class="w3-container w3-padding-32">

  <h1>BCA Market</h1>
  <div>
    {#if $page.data.session}
      {#if $page.data.session.user?.image}
        <p><img
          src={$page.data.session.user.image}
          class="avatar"
          alt="User Avatar"
          width="40px" height="40px"
        /></p>
      {/if}
      <p><span class="signedInText">
        <p><small>Welcome back</small></p>
        <p><strong>{$page.data.session.user?.name ?? "User"}</strong>
        {$page.data.session.user?.email ?? "Email"}</p>
      </span></p>
      {#if has_wallet}
      <p>Wallet: <button type="button" class="w3-btn w3-blue w3-tooltip" on:click={ev => local_wallet_logout()}><i class="w3-large fa fa-sign-out"></i> <span class="w3-text"> disconnect wallet</span></button></p>
      {#if wallet && wallet.walletaddr}
      <p>Address: {@html mk_chainviewer_url(wallet.walletaddr, wallet.walletnetwork)}</p>
      {/if}
      <p>Continue to this system's <a href={"/servicemanager/" + serviceManagerAddress}>Service Manager</a></p>
      {:else}
      <p>Wallet: <button type="button" class="w3-btn w3-blue w3-tooltip" on:click={ev => local_get_wallet_addr(ev)}><i class="w3-large fa fa-sign-in"></i> <span class="w3-text"> connect wallet</span></button></p>
      {/if}
    {:else}
      <p><span class="notSignedInText">You are not signed in</span></p>
      <p><SignIn>
        <div slot="submitButton" class="w3-button buttonPrimary">Sign in</div>
      </SignIn></p>
    {/if}
  </div>
</div>
