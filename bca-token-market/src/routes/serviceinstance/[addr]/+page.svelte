<script lang="ts">
    import { page } from "$app/stores"
    import { onMount } from 'svelte'
    import { createForm } from "svelte-forms-lib";
    import { Contract, Web3 } from 'web3'
    import { serviceInstanceABI, tokenContractABI, token_symbol, token_decimals, calculate_user_balance, calculate_provider_balance, mk_chainviewer_url } from "$lib/contracts.js"
    import { WalletInformation, reset_warning, get_wallet_addr, wallet_logout } from '$lib/wallet'
    import { number } from "zod";

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

    let details: { dayPrice: number; deposit: number; retracted: number; startTime: number; endTime: number; userAddress: string; providerAddress: string; tokenAddress: string } | undefined = undefined
    async function read_contract() {
        if (window.web3 && has_wallet && data && data.addr) {

            let contract: Contract<typeof serviceInstanceABI> = new window.web3.eth.Contract(serviceInstanceABI, data.addr)
            const dayPrice: number = Number(await contract.methods.dayPrice().call())
            const deposit: number = Number(await contract.methods.deposit().call())
            const retracted: number = Number(await contract.methods.retracted().call())
            const startTime: number = Number(await contract.methods.startTime().call())
            const endTime: number = Number(await contract.methods.endTime().call())
            const userAddress: string = await contract.methods.userAddress().call()
            const providerAddress: string = await contract.methods.providerAddress().call()
            const tokenAddress: string = await contract.methods.tokToken().call()
            details = { dayPrice, deposit, retracted, startTime, endTime, userAddress, providerAddress, tokenAddress }
        } else {
            details = undefined
        }
    }

    // inject BigInt serialisation to JSON
    (BigInt.prototype as any).toJSON = function () {
        return this.toString();
    };

    let contractevents = undefined   //: { event: string, blockNumber: string, blockHash: string, transactionHash: string, address: string, returnValues: Record<string,string>, topics: string[] }[] | undefined = undefined
    async function list_events() {
        if (window.web3 && has_wallet && data !== undefined && data.addr) {
            let contract: Contract<typeof serviceInstanceABI> = new window.web3.eth.Contract(serviceInstanceABI, data.addr)    
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
    async function get_transaction(txhash: string) {
        if (window.web3 && txhash) {
            window.web3.eth.getTransaction(txhash).then((tx) => console.log(JSON.stringify(tx,null,2)))
        }
    }
    async function get_block_time(blockHash: string): Promise<bigint> {
        if (window.web3 && blockHash) {
            // console.log(`get_block_time ${blockHash}`)
            const bdata = await window.web3.eth.getBlock(blockHash, false)
            if (bdata && bdata.timestamp) {
                // console.log(`block data: ${JSON.stringify(bdata,null,2)}`)
                return BigInt(bdata.timestamp)
            }
            return 0n
        }
        return 0n
    }
    async function withdraw_user(amount: number, useGas: number) {
        if (window.web3 && has_wallet && data !== undefined && data.addr) {
            const contract = new window.web3.eth.Contract(serviceInstanceABI, data.addr);
            contract.setConfig({ "defaultNetworkId": wallet.walletnetwork });
            try {
                const one_token: number = 10**(token_decimals);
                const gasPrice = await window.web3.eth.getGasPrice();
                let estimatedGas = useGas;
                if (wallet.walletnetwork === "0x89") { // Polygon
                    estimatedGas = await contract.methods.withdrawUser(BigInt(amount * one_token)).estimateGas();
                    // console.log("estimated gas: " + estimatedGas);
                }
                const receipt = await contract.methods
                    .withdrawUser(BigInt(amount * one_token))
                    .send({
                        from: wallet.walletaddr,
                        gas: estimatedGas,
                        gasPrice: gasPrice,
                    });

                console.log("tx withdrawProvider: " + JSON.stringify(receipt,null,2))

            } catch (error) {
                console.error(error);
            }
        }
    }
    async function withdraw_provider(amount: number, useGas: number) {
        if (window.web3 && has_wallet && data !== undefined && data.addr) {
            const contract = new window.web3.eth.Contract(serviceInstanceABI, data.addr);
            contract.setConfig({ "defaultNetworkId": wallet.walletnetwork });
            try {
                const one_token: number = 10**(token_decimals);
                const gasPrice = await window.web3.eth.getGasPrice();
                let estimatedGas = useGas;
                if (wallet.walletnetwork === "0x89") { // Polygon
                    estimatedGas = await contract.methods.withdrawProvider(BigInt(amount * one_token)).estimateGas();
                    // console.log("estimated gas: " + estimatedGas);
                }
                const receipt = await contract.methods
                    .withdrawProvider(BigInt(amount * one_token))
                    .send({
                        from: wallet.walletaddr,
                        gas: estimatedGas,
                        gasPrice: gasPrice,
                    });

                console.log("tx withdrawProvider: " + JSON.stringify(receipt,null,2))

            } catch (error) {
                console.error(error);
            }
        }
    }
    async function deposit_user(amount: number, useGas: number) {
        if (window.web3 && has_wallet && data !== undefined && data.addr && details !== undefined && details.tokenAddress) {
            const contract = new window.web3.eth.Contract(serviceInstanceABI, data.addr);
            contract.setConfig({ "defaultNetworkId": wallet.walletnetwork });
            try {
                const gasPrice = await window.web3.eth.getGasPrice()

                let token: Contract<typeof tokenContractABI> = new window.web3.eth.Contract(tokenContractABI, details.tokenAddress)
                const decimals: bigint = await token.methods.decimals().call()
                // console.log(`decimals: ${decimals}`)
                let contract: Contract<typeof serviceInstanceABI> = new window.web3.eth.Contract(serviceInstanceABI, data.addr)
                const user_addr = await contract.methods.userAddress().call()

                // approve the token amount
                const one_token: number = 10**Number(decimals);
                let estimatedGas = useGas;
                token.methods.approve(data.addr, BigInt(amount * one_token))
                .send({
                        from: wallet.walletaddr,
                        gas: estimatedGas.toString(),
                        gasPrice: gasPrice
                     })
                    .then(v => console.log(JSON.stringify(v, null, 2)))
                
                if (wallet.walletnetwork === "0x89") { // Polygon
                    estimatedGas = Number(await token.methods.makeDeposit(BigInt(amount * one_token)).estimateGas())
                    // console.log(`estimated gas: ${estimatedGas}`)
                }
                contract.methods
                    .makeDeposit(BigInt(amount * one_token))
                    .send({
                        from: wallet.walletaddr,
                        gas: estimatedGas.toString(),
                        gasPrice: gasPrice
                     })
                    .then(v => console.log(JSON.stringify(v, null, 2)))
            } catch (error) {
                console.error(error);
            }
        }
    }
    const form1 = createForm({
        initialValues: {
            amount: 0.6789,
            gas: 85000
        },
        onSubmit: values => {
            if (is_provider) {
                withdraw_provider(values.amount, values.gas);
            } else {
                withdraw_user(values.amount, values.gas);
            }
        }
        });
    const wform = form1.form
    const w_handleChange = form1.handleChange
    const w_handleSubmit = form1.handleSubmit

    const form2 = createForm({
        initialValues: {
            amount: 1.4321,
            gas: 250000
        },
        onSubmit: values => {
            if (!is_provider) {
                deposit_user(values.amount, values.gas);
            }
        }
        });
    const dform = form2.form
    const d_handleChange = form2.handleChange
    const d_handleSubmit = form2.handleSubmit

</script>

<div class="w3-container w3-padding-32">
    {#if $page.data.session}
    <p><span id="details"></span></p>
    <p>&nbsp;</p>

    <h2 class="{is_provider ? 'w3-green' : 'w3-gray'}">Service Instance</h2>

    <h3>Details</h3>
    
    <div class="w3-bar w3-theme">
        <a href="#details" class="w3-bar-item w3-button w3-hover-white">Details</a>
        <a href="#contract" class="w3-bar-item w3-button {has_wallet ? "w3-hover-white" : 'w3-disabled'}">Contract</a>
        <a href="#events" class="w3-bar-item w3-button {has_wallet ? "w3-hover-white" : 'w3-disabled'}">Events</a>
        <a href="#transactions" class="w3-bar-item w3-button {has_wallet ? "w3-hover-white" : 'w3-disabled'}">Transactions</a>
    </div>

    <section class="addr-section">
        <ul>
            <li>Contract address: {@html mk_chainviewer_url(data.addr, wallet.walletnetwork) }</li>
        </ul>
    </section>

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
    <p><br/></p>
    <p><br/></p>
    <p><br/></p>
    <span id="contract"></span>
    <p>&nbsp;</p>
    
    <h2 class="{is_provider ? 'w3-green' : 'w3-gray'}">Service Instance</h2>

    <h3>Contract</h3>
    
    <div class="w3-bar w3-theme">
        <a href="#details" class="w3-bar-item w3-button w3-hover-white">Details</a>
        <a href="#contract" class="w3-bar-item w3-button {has_wallet ? "w3-hover-white" : 'w3-disabled'}">Contract</a>
        <a href="#events" class="w3-bar-item w3-button {has_wallet ? "w3-hover-white" : 'w3-disabled'}">Events</a>
        <a href="#transactions" class="w3-bar-item w3-button {has_wallet ? "w3-hover-white" : 'w3-disabled'}">Transactions</a>
    </div>

    <div>
    <p><button type="button" class="{has_wallet ? "w3-theme" : 'w3-disabled'}" on:click={() => has_wallet && read_contract()}><i class="fa fa-refresh"></i></button></p>

    {#if details !== undefined && has_wallet}
    <ul>
    <li>instance address: {@html mk_chainviewer_url(data.addr, wallet.walletnetwork)}</li>
    <li>daily price: {details.dayPrice / 10**(token_decimals)} {token_symbol}</li>
    <li>user deposit: {details.deposit / 10**(token_decimals)} {token_symbol}</li>
    <li>retracted: {details.retracted / 10**(token_decimals)} {token_symbol}</li>
    <li>start time: { details.startTime > 0 ? new Date(details.startTime * 1000).toISOString() : '' }</li>
    <li>end time: {details.endTime > 0 ? new Date(details.endTime * 1000).toISOString() : (details.startTime > 0 ? "(" + new Date(details.startTime * 1000 + (details.deposit * 1000 * 24 * 3600 / details.dayPrice)).toISOString() + ") estimated" : '') }</li>
    <li>provider address: {@html mk_chainviewer_url(details.providerAddress, wallet.walletnetwork)}</li>
    <li>user address: {@html mk_chainviewer_url(details.userAddress, wallet.walletnetwork)}</li>
    <li>estimated user balance: { calculate_user_balance(details.deposit, details.startTime, details.dayPrice) / 10**(token_decimals)}  {token_symbol}</li>
    <li>estimated provider balance: { calculate_provider_balance(details.deposit, details.retracted, details.startTime, details.dayPrice) / 10**(token_decimals)}  {token_symbol}</li>
    </ul>
    {/if}

    <section class="withdrawal">
        <h3>Withdrawal from contract</h3>
        <form on:submit={w_handleSubmit}>
            <label for="amount">amount {token_symbol}:</label>
            <input
              id="amount"
              name="amount"
              on:change={w_handleChange}
              bind:value={$wform.amount}
            />
            {#if wallet.walletnetwork !== "0x89" }
            <label for="gas">gas:</label>
            <input
              id="gas"
              name="gas"
              on:change={w_handleChange}
              bind:value={$wform.gas}
            />
            {/if}
            <button type="submit">Withdraw</button>
          </form>
    </section>
    {#if ! is_provider}
    <section class="deposit">
        <h3>Deposit to contract</h3>
        <form on:submit={d_handleSubmit}>
            <label for="amount">amount:</label>
            <input
              id="amount"
              name="amount"
              on:change={d_handleChange}
              bind:value={$dform.amount}
            />
            {#if wallet.walletnetwork !== "0x89" }
            <label for="gas">gas:</label>
            <input
              id="gas"
              name="gas"
              on:change={d_handleChange}
              bind:value={$dform.gas}
            />
            {/if}
            <button type="submit">Deposit</button>
          </form>
    </section>
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
    <p><br/></p>
    <p><br/></p>
    <p><br/></p>
    <span id="events"></span>
    <p>&nbsp;</p>
    
    <h2 class="{is_provider ? 'w3-green' : 'w3-gray'}">Service Instance</h2>
    <h3>Events</h3>
    
    <div class="w3-bar w3-theme">
        <a href="#details" class="w3-bar-item w3-button w3-hover-white">Details</a>
        <a href="#contract" class="w3-bar-item w3-button {has_wallet ? "w3-hover-white" : 'w3-disabled'}">Contract</a>
        <a href="#events" class="w3-bar-item w3-button {has_wallet ? "w3-hover-white" : 'w3-disabled'}">Events</a>
        <a href="#transactions" class="w3-bar-item w3-button {has_wallet ? "w3-hover-white" : 'w3-disabled'}">Transactions</a>
    </div>

    <div>
        <p><button type="button" class="{has_wallet ? "w3-theme" : 'w3-disabled'}" on:click={() => has_wallet && list_events()}><i class="fa fa-refresh"></i></button></p>

        {#if contractevents && contractevents.length}
        {#each contractevents as cev}
            <h4>{cev.event ? cev.event : "some event"}</h4>
            <table class="w3-table w3-bordered">
                <tr><td>Timestamp:</td><td>
                    {#await get_block_time(cev.blockHash) then timestamp}
                    {new Date(Number(timestamp * 1000n)).toISOString()}
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
        {/if}    </div>

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
    <p><br/></p>
    <p><br/></p>
    <p><br/></p>
    <span id="transactions"></span>
    <p>&nbsp;</p>
    
    <h2 class="{is_provider ? 'w3-green' : 'w3-gray'}">Service Instance</h2>
    <h3>Transactions</h3>
    
    <div class="w3-bar w3-theme">
        <a href="#details" class="w3-bar-item w3-button w3-hover-white">Details</a>
        <a href="#contract" class="w3-bar-item w3-button {has_wallet ? "w3-hover-white" : 'w3-disabled'}">Contract</a>
        <a href="#events" class="w3-bar-item w3-button {has_wallet ? "w3-hover-white" : 'w3-disabled'}">Events</a>
        <a href="#transactions" class="w3-bar-item w3-button {has_wallet ? "w3-hover-white" : 'w3-disabled'}">Transactions</a>
    </div>

    <div>
        <p><br/></p>
        <p><br/></p>
        <p><br/></p>
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
    <p><br/></p>
    <p><br/></p>

    {/if}
</div>

<style>
    #amount {
        width: 108px;
    }
    #gas {
        width: 84px;
    }
</style>