<script lang="ts">
    import { page } from "$app/stores"
    import { onMount } from 'svelte'
    import { createForm } from "svelte-forms-lib";
    import { Contract, Web3 } from 'web3'
    import { mk_chainviewer_url, serviceManagerABI, shorten_address } from "$lib/contracts.js"
    import { WalletInformation, reset_warning, get_wallet_addr, wallet_logout } from '$lib/wallet'

    export let data
    
    let wallet = new WalletInformation()
    
    onMount ( async () => {
        if (window.ethereum) {
            window.web3 = new Web3(window.ethereum);
            await local_get_wallet_addr({target: undefined})
            if (wallet.walletaddr && data && data.addr) {
                await read_contract()
            }
        } else {
            wallet.warning = "no web3 wallet attached!"
        }
    })

    $: has_wallet = !!wallet.walletaddr

    const is_provider = $page.data.session?.user?.role == "Provider"

    async function local_get_wallet_addr(ev) {
        wallet = await get_wallet_addr(wallet, ev);
    }
    async function local_wallet_logout() {
        wallet = await wallet_logout(wallet)
    }
    function local_reset_warning() {
        reset_warning(wallet);
    }

    let details: { ncontrollers: number; providerAddress: string; controllerAddress: string; } | undefined = undefined
    async function read_contract() {
        if (window.web3 && has_wallet && data && data.addr) {

            let contract: Contract<typeof serviceManagerABI> = new window.web3.eth.Contract(serviceManagerABI, data.addr)
            const ncontrollers: number = await contract.methods.countServiceControllers().call()
            let providerAddress: string = ""
            let controllerAddress: string = ""
            if (ncontrollers > 0) {
                providerAddress = wallet.walletaddr
                controllerAddress = await contract.methods.getControllerAddress(wallet.walletaddr).call()
            }
            details = { ncontrollers, providerAddress, controllerAddress }
        } else {
            details = undefined
        }
    }

    async function create_controller(providerAddress: string, useGas: number) {
        if (window.web3 && has_wallet && data !== undefined && data.addr) {
            const contract = new window.web3.eth.Contract(serviceManagerABI, data.addr);
            contract.setConfig({ "defaultNetworkId": wallet.walletnetwork });
            try {
                const gasPrice = await window.web3.eth.getGasPrice();
                let estimatedGas = useGas;
                if (wallet.walletnetwork === "0x89") { // Polygon
                    estimatedGas = await contract.methods.newController(providerAddress).estimateGas();
                    // console.log("estimated gas: " + estimatedGas);
                }
                const receipt = await contract.methods
                    .newController(providerAddress)
                    .send({
                        from: wallet.walletaddr,
                        gas: estimatedGas,
                        gasPrice: gasPrice,
                    });

                console.log("tx newController: " + JSON.stringify(receipt,null,2))

            } catch (error) {
                console.error(error);
            }
        }
    }

    const { form, handleChange, handleSubmit } = createForm({
        initialValues: {
            provider: has_wallet?wallet.walletaddr:"address",
            gas: "1450000"
        },
        onSubmit: values => {
            create_controller(values.provider, parseInt(values.gas));
        }
        });

</script>

<div class="w3-container w3-padding-32">
    <p><a href="/servicemanager">Service Manager</a></p>
    
    {#if $page.data.session && is_provider}
    
    <h2 class="{is_provider ? 'w3-green' : 'w3-gray'}">Service Manager - {shorten_address(data.addr)}</h2>

    <section class="login-section">
        {#if !has_wallet}
        <p><button type="button" class="login-btn" on:click={ (ev) => local_get_wallet_addr(ev) }>🔓 Log in with Web3</button></p>
        <span class="instruction">
          Ensure to have an Ethereum based wallet installed i.e MetaMask. Change the network and account in the wallet and 
          click the button again to update the app's state.
        </span>
        {:else}
        <p>connected to
        <span> network: {wallet.walletnetwork} </span>
        <span> with address: {wallet.walletaddr} </span>
        <button type="button" class="logout-btn" on:click={ () => local_wallet_logout() }>🔐 Log out</button></p>
        {/if}
    </section>
    
    <p><button type="button" class="{has_wallet ? "w3-theme" : 'w3-disabled'}" on:click={() => has_wallet && read_contract()}><i class="fa fa-refresh"></i></button></p>

    {#if details !== undefined && has_wallet}
    <p>service manager address: {@html mk_chainviewer_url(data.addr, wallet.walletnetwork)}</p>
    {#if details.ncontrollers > 0}
    <!-- <p>number of controllers: {details.ncontrollers}</p> -->
    <p>provider address: {@html mk_chainviewer_url(details.providerAddress, wallet.walletnetwork)}</p>
    <p>provider's controller: <a href={"/servicecontroller/" + details.controllerAddress}>{shorten_address(details.controllerAddress)}</a></p>
    {:else if is_provider}
    <section class="action">
        <h3>Create controller</h3>
        <form on:submit={handleSubmit}>
            <label for="provider">provider</label>
            <input
              id="provider"
              name="provider"
              on:change={handleChange}
              bind:value={$form.provider}
            />
            {#if wallet.walletnetwork !== "0x89" }
            <label for="gas">gas:</label>
            <input
              id="gas"
              name="gas"
              on:change={handleChange}
              bind:value={$form.gas}
            />
            {/if}
            <button type="submit">Create</button>
          </form>
    </section>    
    {/if}
    {/if}

    {/if}
</div>

<style>
    #provider {
        width: 388px;
    }
    #gas {
        width: 84px;
    }
</style>