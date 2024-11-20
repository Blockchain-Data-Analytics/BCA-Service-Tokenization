<script lang="ts">
    import { page } from "$app/stores"
    import { onMount } from 'svelte'
    import { createForm } from "svelte-forms-lib";
    import { Contract, Web3 } from 'web3'
    import { serviceManagerABI } from "$lib/contracts.js"
    import { WalletInformation, reset_warning, get_wallet_addr, wallet_logout } from '$lib/wallet'

    export let data
    
    let wallet = new WalletInformation()
    
    onMount ( async () => {
        if (window.ethereum) {
            window.web3 = new Web3(window.ethereum);
        } else {
            wallet.warning = "no web3 wallet attached!"
        }
    })

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
    async function read_contract(contractAddress: string) {
        if (window.web3 && wallet.walletaddr && contractAddress) {

            let contract: Contract<typeof serviceManagerABI> = new window.web3.eth.Contract(serviceManagerABI, contractAddress)
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
        if (window.web3 && wallet.walletaddr !== undefined && data !== undefined && data.addr) {
            const contract = new window.web3.eth.Contract(serviceManagerABI, data.addr);
            contract.setConfig({ "defaultNetworkId": wallet.walletnetwork });
            try {
                const gasPrice = await window.web3.eth.getGasPrice();
                let estimatedGas = useGas;
                if (wallet.walletnetwork === "0x89") { // Polygon
                    let estimatedGas = await contract.methods.newController(providerAddress).estimateGas();
                    console.log("estimated gas: " + estimatedGas);
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
            provider: (wallet.walletaddr !== undefined)?wallet.walletaddr:"address",
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
    
    <h2 class="{is_provider ? 'w3-green' : 'w3-gray'}">Service Manager - {data.addr}</h2>

    <section class="login-section">
        {#if wallet.walletaddr == undefined}
        <p><button type="button" class="login-btn" on:click={ (ev) => local_get_wallet_addr(ev) }>🔓 Log in with Web3</button></p>
        <span class="instruction">
          Ensure to have an Ethereum based wallet installed i.e MetaMask. Change the network and account in the wallet and 
          click the button again to update the app's state.
        </span>
        {:else}
        <p><button type="button" class="logout-btn" on:click={ () => local_wallet_logout() }>🔐 Log out</button></p>
        <span>        network: {wallet.walletnetwork} </span>
        <span>        address: {wallet.walletaddr} </span>
        {/if}
    </section>
    
    <button type="button" on:click={() => read_contract(data.addr)}>show</button>

    {#if details !== undefined && wallet.walletaddr !== undefined}
    {#if details.ncontrollers > 0}
    <p>number of controllers: {details.ncontrollers}</p>
    <p>provider address: {details.providerAddress}</p>
    <p>controller address: {details.controllerAddress}</p>
    <p><a href={"/servicecontroller/" + details.controllerAddress}>controller</a></p>
    {:else}
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
    <!-- {#each details.controllers as controller}
        <p>{controller}</p>
    {/each} -->
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