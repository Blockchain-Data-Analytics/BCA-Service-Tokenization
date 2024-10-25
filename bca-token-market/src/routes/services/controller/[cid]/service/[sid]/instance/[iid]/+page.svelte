<script lang="ts">
    import { onMount } from 'svelte';
    import { Contract, Web3 } from 'web3';
    import { page } from "$app/stores"
    import { superForm } from "sveltekit-superforms/client"
    // import SuperDebug from "sveltekit-superforms/client/SuperDebug.svelte"
    import { serviceContractABI, tokenContractABI, tokenContractAddress, contractAddresses  } from "$lib/contracts.js";
    import { WalletInformation } from '$lib/wallet'
    import Wallet from "$lib/components/wallet.svelte"

    export let data
    const { form, errors } = superForm(data.form)

    let wallet = new WalletInformation()

    onMount ( async () => {
        if (window.ethereum) {
            window.web3 = new Web3(window.ethereum);
            // window.web3 = new Web3('http://127.0.0.1:8545');
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

    let contractdetails : { user_addr: string, day_price: bigint, deposit: bigint, retracted: bigint, start_time: bigint, end_time: bigint, calc_user_balance: bigint, calc_provider_balance: bigint, subscriber: string} | undefined = undefined
    async function read_contract(contractAddress: string) {
        if (window.web3 && contractAddress && wallet.walletaddr) {

            console.log(`reading contract details for ${contractAddress}`)
            const now = Math.floor(new Date().getTime() / 1000)
            let contract: Contract<typeof serviceContractABI> = new window.web3.eth.Contract(serviceContractABI, contractAddresses[contractAddress])
            const user_addr: string = await contract.methods.userAddress().call()
            const day_price: bigint = await contract.methods.dayPrice().call()
            const deposit: bigint = await contract.methods.deposit().call()
            let retracted: bigint = 0n
            if (is_provider) {
                retracted = await contract.methods.retracted().call()
            }
            const start_time: bigint = await contract.methods.startTime().call()
            const end_time: bigint = await contract.methods.endTime().call()
            const decimals: bigint = 18n
            const init_fee: bigint = (10n ** decimals) / 5n   // 0.2 tokens
            let calc_user_balance: bigint = 0n
            let calc_provider_balance: bigint = 0n
            if (start_time > 0n) {
                if (end_time == 0n) {
                    calc_user_balance = deposit - ((BigInt(now) - start_time) * day_price / 24n / 3600n)
                    calc_provider_balance = deposit - calc_user_balance - retracted
                } else {
                    calc_user_balance = deposit - ((end_time - start_time) * day_price / 24n / 3600n)
                    calc_provider_balance = deposit - calc_user_balance - retracted
                }
                if (calc_user_balance < 0n) { calc_user_balance = 0n }
                if (calc_provider_balance < 0n) { calc_provider_balance = 0n }
                if (calc_provider_balance > deposit) { calc_provider_balance = deposit }
            }
            contractdetails = { user_addr, day_price, deposit, retracted, start_time, end_time, calc_user_balance, calc_provider_balance, subscriber: (user_addr.toLocaleLowerCase() == wallet.walletaddr?.toLocaleLowerCase() ? 'you' : 'anybody') }
        } else {
            contractdetails = undefined
        }
    }

    // inject BigInt serialisation to JSON
    (BigInt.prototype as any).toJSON = function () {
        return this.toString();
    };

    let contractevents = undefined   //: { event: string, blockNumber: string, blockHash: string, transactionHash: string, address: string, returnValues: Record<string,string>, topics: string[] }[] | undefined = undefined
    async function list_events(contractAddress: string) {
        if (window.web3 && contractAddress && wallet.walletaddr) {
            let contract: Contract<typeof serviceContractABI> = new window.web3.eth.Contract(serviceContractABI, contractAddresses[contractAddress])    
            contract.getPastEvents('ALLEVENTS', { fromBlock: 0, toBlock: 'latest'}).then(function (events) {
                if (events.length) {
                    contractevents = events
                    // console.log(JSON.stringify(events,null,2))
                }
            })
        } else {
            contractevents = undefined
        }
    }

    let transactiondetails = undefined   //: { event: string, blockNumber: string, blockHash: string, transactionHash: string, address: string, returnValues: Record<string,string>, topics: string[] }[] | undefined = undefined
    async function list_transactions(contractAddress: string) {
        if (window.web3 && contractAddress && wallet.walletaddr) {
            window.web3.eth.getBlockNumber()
                .then((bn) => console.log(`latest block number: ${bn}`));
            // let token: Contract<typeof tokenContractABI> = new window.web3.eth.Contract(tokenContractABI, tokenContractAddress)
        } else {
            transactiondetails = undefined
        }
    }

    async function get_transaction(txhash: string) {
        if (window.web3 && txhash) {
            window.web3.eth.getTransaction(txhash).then((tx) => console.log(JSON.stringify(tx,null,2)))
            }
        }

    let withdraw_amt: number = 0.0
    async function call_user_balance(contractAddress: string) {
        if (window.web3 && contractAddress && wallet.walletaddr) {
            let contract: Contract<typeof serviceContractABI> = new window.web3.eth.Contract(serviceContractABI, contractAddresses[contractAddress])
            const gasPrice = await window.web3.eth.getGasPrice()
            contract.methods.balanceUser()
                .call({
                    from: wallet.walletaddr,
                    gas: "65000", 
                    gasPrice
                }).then((v) => { if (v) { withdraw_amt = Number(v) / 10**18 } })
        }    
    }
    async function call_user_withdraw(contractAddress: string) {
        if (window.web3 && contractAddress && withdraw_amt > 0 && wallet.walletaddr) {
            let contract: Contract<typeof serviceContractABI> = new window.web3.eth.Contract(serviceContractABI, contractAddresses[contractAddress])
            const gasPrice = await window.web3.eth.getGasPrice()
            const amount: bigint = BigInt(withdraw_amt * 10**18)
            contract.methods.withdrawUser(amount)
                .send({
                    from: wallet.walletaddr,
                    gas: "65000", 
                    gasPrice
                }).then(console.log)
        }
    }

    async function get_block_time(blockHash: string): bigint {
        if (window.web3 && blockHash) {
            console.log(`get_block_time ${blockHash}`)
            const bdata = await window.web3.eth.getBlock(blockHash, false)
            if (bdata && bdata.timestamp) {
                console.log(`block data: ${JSON.stringify(bdata,null,2)}`)
                return BigInt(bdata.timestamp)
            }
            return null
        }
        return null
    }
</script>

{#if $page.data.session}
<span id="details"></span>

<div class="w3-container w3-padding-32">

    <div class="w3-bar">
        <a class="w3-btn w3-small" href="/services/controller/{data.controller_id}">controller</a>
        <a class="w3-btn w3-small" href="/services/controller/{data.controller_id}/service">services</a>
        <a class="w3-btn w3-small" href="/services/controller/{data.controller_id}/service/{data.service_id}/instance">instances</a>
        <a class="w3-btn w3-small" href="#"><Wallet bind:wallet={wallet} /></a>
    </div>

    <h2 class="{is_provider ? 'w3-green' : 'w3-gray'}">Service</h2>

    <h3>Details</h3>
    
    <div class="w3-bar w3-theme">
        <a href="#details" class="w3-bar-item w3-button w3-hover-white">Details</a>
        <a href="#contract" class="w3-bar-item w3-button {has_wallet ? "w3-hover-white" : 'w3-disabled'}">Contract</a>
        <a href="#events" class="w3-bar-item w3-button {has_wallet ? "w3-hover-white" : 'w3-disabled'}">Events</a>
        <a href="#transactions" class="w3-bar-item w3-button {has_wallet ? "w3-hover-white" : 'w3-disabled'}">Transactions</a>
    </div>

    <form method="POST" class="w3-container">
        <label>
            id:
            <input name="id" id="id" autocomplete="off" class="w3-input" readonly bind:value={$form.id}/>
        </label>
        <label>
            provider:
            <input name="userId" id="userId" autocomplete="off" class="w3-input" readonly bind:value={$form.userId}/>
            {$page.data.session.user?.id == $form.userId ? "(you)" : ""}
        </label>
        <label>
            description:
            <input name="description" id="description" autocomplete="off" class="w3-input" required bind:value={$form.description}/>
        </label>
        {#if $errors.description}
            <div class="w3-panel w3-red">{$errors.description}</div>
        {/if}
        <label>
            created:
            <input name="created" id="created" autocomplete="off" class="w3-input" readonly  bind:value={$form.created}/>
        </label>
        <label>
            updated:
            <input name="updated" id="updated" autocomplete="off" class="w3-input" readonly  bind:value={$form.updated}/>
        </label>
        <label>
            service:
            <input name="service_id" id="service" autocomplete="off" class="w3-input" readonly  bind:value={$form.service_id}/>
        </label>
        <label>
            contract:
            <input name="contract_addr" id="contract_addr" autocomplete="off" class="w3-input" readonly  bind:value={$form.contract_addr}/>
        </label>
        <p>{#if is_provider}<button type="submit" class="w3-btn w3-blue" formaction="?/update">save</button>{/if}</p>
    </form>

    <p><br/></p>
    <p><br/></p>
    <p><br/></p>
    <p><br/></p>
    <p><br/></p>
    <p><br/></p>
    <p><br/></p>
    <p><br/></p>
    <p id="contract"><br/></p>
    <p><br/></p>

    <h3>Contract</h3>
    
    <div class="w3-bar w3-theme">
        <a href="#details" class="w3-bar-item w3-button w3-hover-white">Details</a>
        <a href="#contract" class="w3-bar-item w3-button {has_wallet ? "w3-hover-white" : 'w3-disabled'}">Contract</a>
        <a href="#events" class="w3-bar-item w3-button {has_wallet ? "w3-hover-white" : 'w3-disabled'}">Events</a>
        <a href="#transactions" class="w3-bar-item w3-button {has_wallet ? "w3-hover-white" : 'w3-disabled'}">Transactions</a>
    </div>

    <div>
        <p><button type="button" class="{has_wallet ? "w3-theme" : 'w3-disabled'}" on:click={() => has_wallet && $form.contract_addr && read_contract($form.contract_addr)}><i class="fa fa-refresh"></i></button></p>

        <table class="w3-table w3-bordered">
        {#if contractdetails}
            <tr><td>User:</td><td>{contractdetails.user_addr}</td></tr>
            <tr><td>Who:</td><td>{contractdetails.subscriber}</td></tr>
            <!-- <tr><td>Start time:</td><td>{date_formatter.format(1000 * contractdetails.start_time)} {contractdetails.start_time}</td></tr> -->
            <tr><td>Start time:</td><td>{date_formatter.format(Number(contractdetails.start_time * 1000n))}</td></tr>
            <tr><td>End time:</td><td>{contractdetails.end_time > 0n ? date_formatter.format(Number(contractdetails.end_time * 1000n)) : ''} 
                {#if contractdetails.start_time > 0n && contractdetails.end_time == 0n}
                <button type="button" class="w3-btn w3-theme w3-bordered" on:click={() => call_stop()}>call contract stop()</button>
                {/if}
                </td></tr>
            {#if contractdetails.end_time == 0n}
            <tr><td>Calc. end time:</td><td>{date_formatter.format(Number(contractdetails.start_time * 1000n + (contractdetails.deposit * 1000n * 24n * 3600n / contractdetails.day_price)))}</td></tr>
            {/if}
            <tr><td>Price / 24h:</td><td>{Number(contractdetails.day_price) / 10**18} tokens</td></tr>
            <tr><td>Deposit:</td><td>{Number(contractdetails.deposit) / 10**18} tokens</td></tr>
            {#if is_provider}
            <tr><td>Calc. provider balance:</td><td>{Number(contractdetails.calc_provider_balance) / 10**18}</td></tr>
            {:else}
            <tr><td>Calc. provider balance:</td><td>{Number(contractdetails.calc_provider_balance) / 10**18}</td></tr>
            <tr><td>Calc. user balance:</td><td>{Number(contractdetails.calc_user_balance) / 10**18} 
                {#if contractdetails.calc_user_balance > 0n}
                <p><button type="button" class="w3-btn w3-theme" on:click={() => has_wallet && $form.contract_addr && call_user_withdraw($form.contract_addr)}>withdraw</button>
                   <input type="number" id="withdraw_amt" bind:value={withdraw_amt} width=89>from contract</p>
                <p><button type="button" class="w3-btn w3-theme w3-border" on:click={() => has_wallet && $form.contract_addr && call_user_balance($form.contract_addr)}>call contract user_balance()</button></p>
                {/if}
                </td></tr>
            {/if}
        {/if}
        </table>
    </div>
    <p><br/></p>
    <p><br/></p>
    <p><br/></p>
    <p><br/></p>
    <p><br/></p>
    <p><br/></p>
    <p><br/></p>
    <p><br/></p>
    <p><br/></p>
    <p><br/></p>
    <p><br/></p>
    <p><br/></p>
    <p id="events"><br/></p>
    <p><br/></p>

    <h3>Events</h3>
    
    <div class="w3-bar w3-theme">
        <a href="#details" class="w3-bar-item w3-button w3-hover-white">Details</a>
        <a href="#contract" class="w3-bar-item w3-button {has_wallet ? "w3-hover-white" : 'w3-disabled'}">Contract</a>
        <a href="#events" class="w3-bar-item w3-button {has_wallet ? "w3-hover-white" : 'w3-disabled'}">Events</a>
        <a href="#transactions" class="w3-bar-item w3-button {has_wallet ? "w3-hover-white" : 'w3-disabled'}">Transactions</a>
    </div>

    <div>
        <p><button type="button" class="{has_wallet ? "w3-theme" : 'w3-disabled'}" on:click={() => has_wallet && $form.contract_addr && list_events($form.contract_addr)}><i class="fa fa-refresh"></i></button></p>

        {#if contractevents && contractevents.length}
        {#each contractevents as cev}
            <h4>{cev.event ? cev.event : "some event"}</h4>
            <table class="w3-table w3-bordered">
                <tr><td>Timestamp:</td><td>
                    {#await get_block_time(cev.blockHash) then timestamp}
                    {date_formatter.format(Number(timestamp * 1000n))}
                    {:catch}
                    <i class="fa fa-thumbs-down"></i> error
                    {/await}
                    </td></tr>
                <tr><td>Block:</td><td>#{cev.blockNumber ? cev.blockNumber : "#?"} {cev.blockHash ? cev.blockHash : "0x.."}</td></tr>
                <tr><td>Transaction:</td><td>
                    {#if cev.transactionHash}
                    <button type="button" class="w3-btn" on:click={() => has_wallet && get_transaction(cev.transactionHash)}>{cev.transactionHash}</button>
                    {:else}
                    "no transaction info"
                    {/if}
                    </td></tr>
                <tr><td>Address:</td><td>{cev.address ? cev.address : "0x.."}</td></tr>
                <tr><td>Topics:</td><td>{cev.topics ? JSON.stringify(cev.topics,null,2) : "[ ]"}</td></tr>
                <tr><td>Values:</td><td>{cev.returnValues ? JSON.stringify(cev.returnValues,null,2) : "{ }"}</td></tr>
            </table>
        {/each}
        {/if}
    </div>
    <p><br/></p>
    <p><br/></p>
    <p><br/></p>
    <p><br/></p>
    <p><br/></p>
    <p><br/></p>
    <p><br/></p>
    <p><br/></p>
    <p><br/></p>
    <p><br/></p>
    <p><br/></p>
    <p><br/></p>
    <p id="transactions"><br/></p>
    <p><br/></p>

    <h3>Transactions</h3>
    
    <div class="w3-bar w3-theme">
        <a href="#details" class="w3-bar-item w3-button w3-hover-white">Details</a>
        <a href="#contract" class="w3-bar-item w3-button {has_wallet ? "w3-hover-white" : 'w3-disabled'}">Contract</a>
        <a href="#events" class="w3-bar-item w3-button {has_wallet ? "w3-hover-white" : 'w3-disabled'}">Events</a>
        <a href="#transactions" class="w3-bar-item w3-button {has_wallet ? "w3-hover-white" : 'w3-disabled'}">Transactions</a>
    </div>

    <div>
        <p><button type="button" class="{has_wallet ? "w3-theme" : 'w3-disabled'}" on:click={() => has_wallet && $form.contract_addr && list_transactions($form.contract_addr)}><i class="fa fa-refresh"></i></button></p>

        <!-- {#if transactiondetails && transactiondetails.length}
        {#each transactiondetails as tx}
            <h4>{cev.event ? cev.event : "some event"}</h4>
            <table class="w3-table w3-bordered">
                <tr><td>Timestamp:</td><td>{cev.blockHash ? get_block_time(cev.blockHash).then(v => v?.timestamp) : ""}</td></tr>
                <tr><td>Block:</td><td>#{cev.blockNumber ? cev.blockNumber : "#?"} {cev.blockHash ? cev.blockHash : "0x.."}</td></tr>
                <tr><td>Transaction:</td><td>{cev.transactionHash ? cev.transactionHash : "0x.."}</td></tr>
                <tr><td>Address:</td><td>{cev.address ? cev.address : "0x.."}</td></tr>
                <tr><td>Topics:</td><td>{cev.topics ? JSON.stringify(cev.topics,null,2) : "[ ]"}</td></tr>
                <tr><td>Values:</td><td>{cev.returnValues ? JSON.stringify(cev.returnValues,null,2) : "{ }"}</td></tr>
            </table>
        {/each}
        {/if} -->
    </div>
    <p><br/></p>
    <p><br/></p>
    <p><br/></p>
    <p><br/></p>
    <p><br/></p>
    <p><br/></p>
    <p><br/></p>
    <p><br/></p>

</div>
<!-- <div class="w3-container w3-gray">
    <SuperDebug data={form}/>
</div> -->
{/if}