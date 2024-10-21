<script lang="ts">
    import { page } from "$app/stores"
    import { onMount } from 'svelte';
    import { Contract, Web3 } from 'web3';
    import { serviceContractABI, tokenContractABI, tokenContractAddress, contractAddresses  } from "$lib/contracts.js";
    import type { Instance } from '@prisma/client'
    import { WalletInformation } from '$lib/wallet'
    import Wallet from "$lib/components/wallet.svelte"

    export let data

    let wallet = new WalletInformation()

    onMount ( async () => {
        if (window.ethereum) {
            window.web3 = new Web3(window.ethereum);
        }
    })

    $: has_wallet = !!wallet.walletaddr

    const is_provider = $page.data.session.user.role == "Provider"

    const locale = 'en'  // better get this from the browser
    const options: Intl.DateTimeFormatOptions = {
        weekday: undefined,
        year: 'numeric',
        month: 'numeric',
        day: 'numeric',
        hour: '2-digit',
        minute: '2-digit',
        second: '2-digit'
    }
    const date_formatter = new Intl.DateTimeFormat(locale, options)

    let instance: Instance
    function open_subscribe(_instance: Instance) {
        instance = _instance
        document.getElementById('subscribe01').style.display='block'
    }
    let contractdetails : { user_addr: string, day_price: bigint, deposit: bigint, start_time: bigint, end_time: bigint, balance: bigint, subscriber: string} | undefined = undefined
    async function open_details(_instance: Instance) {
        instance = _instance
        contractdetails = await read_contract(instance.contract_addr)
        document.getElementById('check01').style.display='block'
    }

    let ntokens = "1"
    let error_msg = ""

    async function read_contract(contractAddress: string) {
        if (window.web3 && contractAddress && wallet.walletaddr) {

            let contract: Contract<typeof serviceContractABI> = new window.web3.eth.Contract(serviceContractABI, contractAddresses[contractAddress])
            const user_addr: string = await contract.methods.userAddress().call()
            const day_price: bigint = await contract.methods.dayPrice().call()
            const deposit: bigint = await contract.methods.deposit().call()
            const start_time: bigint = await contract.methods.startTime().call()
            const end_time: bigint = await contract.methods.endTime().call()
            const balance: bigint = 0n   //await contract.methods.balanceUser().send({from: wallet.walletaddr}).then(console.log);
            return { user_addr, day_price, deposit, start_time, end_time, balance, subscriber: (user_addr.toLocaleLowerCase() == wallet.walletaddr?.toLocaleLowerCase() ? 'you' : 'anybody') }
        }
        return {}
    }

    async function deposit_tokens(tokens: number, ev: any) {
        console.log(`got ${tokens}`)
        if (window.web3 && instance.contract_addr && wallet.walletaddr) {

            let token: Contract<typeof tokenContractABI> = new window.web3.eth.Contract(tokenContractABI, tokenContractAddress)
            const decimals: bigint = await token.methods.decimals().call()
            console.log(`decimals: ${decimals}`)
            let contract: Contract<typeof serviceContractABI> = new window.web3.eth.Contract(serviceContractABI, contractAddresses[instance.contract_addr])
            const user_addr = await contract.methods.userAddress().call();
            if (user_addr && BigInt(user_addr) != 0n) {
                error_msg = "service already subscribed by a user: " + user_addr
                return
            }
            // approve the token amount
            const one_token: bigint = 10n**(decimals);
            let estimatedGas = await token.methods.approve(contractAddresses[instance.contract_addr], BigInt(tokens) * one_token).estimateGas()
            console.log(`estimated gas: ${estimatedGas}`)
            await token.methods.approve(contractAddresses[instance.contract_addr], BigInt(tokens) * one_token).send({from: wallet.walletaddr}).then(console.log)

            // estimatedGas = await contract.methods.makeDeposit(BigInt(tokens) * one_token).estimateGas()
            // console.log(`estimated gas: ${estimatedGas}`)
            await contract.methods.makeDeposit(BigInt(tokens) * one_token).send({from: wallet.walletaddr}).then(console.log)

        }
    }

    async function cancel_service(instance: Instance, ev: any) {

    }

</script>

{#if $page.data.session}
<div class="w3-container w3-padding-32">

    <div class="w3-bar">
            <a class="w3-btn w3-small" href="/services/controller">controllers</a>
            <a class="w3-btn w3-small" href="/services/controller/{data.controller_id}/service">services</a>
            <a class="w3-btn w3-small" href="#"><Wallet bind:wallet={wallet} /></a>
    </div>
    <h2 class="{is_provider ? 'w3-green' : 'w3-gray'}">Instances</h2>

    <table class="w3-table w3-striped">
         <tr><th>id</th><th>created</th><th>updated</th><th>description</th><th>service</th><th>user</th></tr>
         {#each data.instances as instance}
            <tr>
            {#if is_provider }
                <td><i class="fa fa-edit"></i> <a href="/services/controller/{data.controller_id}/service/{data.service_id}/instance/{instance.id}">{instance.id}</a></td>
            {:else}
                <td>{instance.id}
                    <button type="button" class="w3-button {has_wallet ? "w3-blue" : 'w3-disabled'}" on:click={() => has_wallet && open_subscribe(instance)}>subscribe</button>
                    <button type="button" class="w3-button {has_wallet ? "w3-blue" : 'w3-disabled'}" on:click={() => has_wallet && open_details(instance)}>details</button></td>
            {/if}
                <td>{date_formatter.format(instance.created)}</td>
                <td>{date_formatter.format(instance.updated)}</td>
                <td>{instance.description}</td>
                <td><i class="fa fa-arrow-right"></i> <a href="/services/controller/{data.controller_id}/service/{instance.service_id}">{instance.service_id}</a></td>
                <td>{instance.userId}</td></tr>
         {/each}
    </table>
    <div class="w3-container">
        <form method="POST" action="?/new" class="w3-container">
            <input type="hidden" name="action" value="new" />
            {#if is_provider }
            <button type="submit" class="w3-btn w3-blue">new</button>
            {/if}
        </form>
    </div>
    {#if data.error}
    <div class="w3-panel w3-gray">
        <p>error: {data.error}</p>
    </div>
    {:else}
    <div id="subscribe01" class="w3-modal w3-animate-opacity">
        <div class="w3-modal-content w3-card-4">
          <header class="w3-container w3-green"> 
            <button type="button" on:click={() => document.getElementById('subscribe01').style.display='none'}
              class="w3-button w3-large w3-display-topright">&times;</button>
            <h2>Subscribe to service</h2>
          </header>
          <div class="w3-container">
            <p>Indicate the number of tokens you want to allocate for the service:</p>
            <p>{JSON.stringify(instance,null,2)}</p>
            <p><input type="number" width="28" bind:value={ntokens} min="1" max="999">
            <button type="button" on:click={ev => deposit_tokens(ntokens, ev)}>deposit</button>
            </p>
          </div>
          <footer class="w3-container w3-green">
            {#if error_msg != ""}
            <p>Error: {error_msg}</p>
            {:else}
            <p>these tokens will fund the service.</p>
            {/if}
          </footer>
        </div>
      </div>    
    <div id="check01" class="w3-modal w3-animate-opacity">
        <div class="w3-modal-content w3-card-4">
          <header class="w3-container w3-green"> 
            <button type="button" on:click={() => document.getElementById('check01').style.display='none'}
              class="w3-button w3-large w3-display-topright">&times;</button>
            <h2>Details of subscribed service</h2>
          </header>
          <div class="w3-container">
            {#if contractdetails}
            <table class="w3-table w3-bordered">
            <tr><td>User:</td><td>{contractdetails.user_addr}</td></tr>
            <tr><td>Who:</td><td>{contractdetails.subscriber}</td></tr>
            <!-- <tr><td>Start time:</td><td>{date_formatter.format(1000 * contractdetails.start_time)} {contractdetails.start_time}</td></tr> -->
            <tr><td>Start time:</td><td>{date_formatter.format(Number(contractdetails.start_time * 1000n))}</td></tr>
            <tr><td>End time:</td><td>{contractdetails.end_time > 0n ? date_formatter.format(Number(contractdetails.end_time * 1000n)) : ''}</td></tr>
            {#if contractdetails.end_time == 0n}
            <tr><td>Calc. end time:</td><td>{date_formatter.format(Number(contractdetails.start_time * 1000n + (contractdetails.deposit * 1000n * 24n * 3600n / contractdetails.day_price)))}</td></tr>
            {/if}
            <tr><td>Price / 24h:</td><td>{contractdetails.day_price}</td></tr>
            <tr><td>Deposit:</td><td>{contractdetails.deposit}</td></tr>
            <tr><td>Balance:</td><td>{contractdetails.balance}</td></tr>
            </table>
            {#if contractdetails.subscriber == 'you'}<p><button type="button" class="w3-button w3-right" on:click={ev => cancel_service(instance, ev)}>cancel</button></p>{/if}
            {/if}
          </div>
          <footer class="w3-container w3-green">
            {#if error_msg != ""}
            <p>Error: {error_msg}</p>
            {:else}
            <p>You have already subscribed to this service.</p>
            {/if}
          </footer>
        </div>
      </div>    
    {/if}
</div>
{/if}