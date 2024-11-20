<script lang="ts">
    import { page } from "$app/stores"
    import { onMount } from 'svelte'
    import { createForm } from "svelte-forms-lib";
    import { Contract, Web3 } from 'web3'
    import { serviceABI } from "$lib/contracts.js"
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

    let details: { maxinstances: number; ninstances: number; instanceAddresses: string[]; } | undefined = undefined
    async function read_contract(contractAddress: string) {
        if (window.web3 && wallet.walletaddr && contractAddress) {

            let contract: Contract<typeof serviceABI> = new window.web3.eth.Contract(serviceABI, contractAddress)
            const maxinstances: number = Number(await contract.methods.maxInstances().call())
            const ninstances: number = Number(await contract.methods.countServiceInstances().call())
            let instanceAddresses: string[] = []
            for (let i = 0; i < ninstances; i++) {
                instanceAddresses[i] = await contract.methods.deployedInstances(i).call()
            }
            details = { maxinstances, ninstances, instanceAddresses }
        } else {
            details = undefined
        }
    }

    // inject BigInt serialisation to JSON
    (BigInt.prototype as any).toJSON = function () {
        return this.toString();
    };

    async function create_instance(userAddress: string, useGas: number) {
        if (window.web3 && wallet.walletaddr !== undefined && data !== undefined && data.addr) {
            const contract = new window.web3.eth.Contract(serviceABI, data.addr);
            contract.setConfig({ "defaultNetworkId": wallet.walletnetwork });
            try {
                const gasPrice = await window.web3.eth.getGasPrice();
                let estimatedGas = useGas;
                if (wallet.walletnetwork === "0x89") { // Polygon
                    estimatedGas = await contract.methods.newInstance(userAddress).estimateGas();
                    console.log("estimated gas: " + estimatedGas);
                }    
                const receipt = await contract.methods
                    .newInstance(userAddress)
                    .send({
                        from: wallet.walletaddr,    
                        gas: estimatedGas,
                        gasPrice: gasPrice,
                    });

                console.log("tx newInstance: " + JSON.stringify(receipt,null,2))    

            } catch (error) {
                console.error(error);
            }    
        }    
    }    

    const { form, handleChange, handleSubmit } = createForm({
        initialValues: {
            useraddress: "user address",
            gas: 1450000
        },
        onSubmit: values => {
            create_instance(values.useraddress, values.gas);
        }
        });

</script>

<div class="w3-container w3-padding-32">
    <p><a href="/service">Service</a></p>
    
    {#if $page.data.session && is_provider}
    
    <h2 class="{is_provider ? 'w3-green' : 'w3-gray'}">Service - {data.addr}</h2>

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

    <p>number of instances: {details.ninstances}</p>
    <p>max instances: {details.maxinstances}</p>
    <p>available instances: {details.maxinstances - details.ninstances} ({(details.maxinstances - details.ninstances) * 100 / details.maxinstances}%)</p>
    {#each details.instanceAddresses as instanceAddress,idx}
        <p><a href={"/serviceinstance/" + instanceAddress}>instance {idx}</a> @ {instanceAddress}</p>
    {/each}

    <section class="action">
        <h3>Create instance</h3>
        <form on:submit={handleSubmit}>
            <label for="useraddress">user address:</label>
            <input
              id="useraddress"
              name="useraddress"
              on:change={handleChange}
              bind:value={$form.useraddress}
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
</div>

<style>
    #useraddress {
        width: 388px;
    }
    #gas {
        width: 84px;
    }
</style>