<script lang="ts">
    import { page } from "$app/stores"
    import { onMount } from 'svelte'
    import { createForm } from "svelte-forms-lib";
    import { Contract, Web3 } from 'web3'
    import { serviceInstanceABI, tokenContractABI } from "$lib/contracts.js"
    import { WalletInformation, reset_warning, get_wallet_addr, wallet_logout } from '$lib/wallet'
    import { number } from "zod";

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

    let details: { dayPrice: number; deposit: number; retracted: number; startTime: number; endTime: number; userAddress: string; providerAddress: string; tokenAddress: string } | undefined = undefined
    async function read_contract(contractAddress: string) {
        if (window.web3 && wallet.walletaddr && contractAddress) {

            let contract: Contract<typeof serviceInstanceABI> = new window.web3.eth.Contract(serviceInstanceABI, contractAddress)
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

    async function withdraw_user(amount: number, useGas: number) {
        if (window.web3 && wallet.walletaddr !== undefined && data !== undefined && data.addr) {
            const contract = new window.web3.eth.Contract(serviceInstanceABI, data.addr);
            contract.setConfig({ "defaultNetworkId": wallet.walletnetwork });
            try {
                const one_token: number = 10**18;
                const gasPrice = await window.web3.eth.getGasPrice();
                let estimatedGas = useGas;
                if (wallet.walletnetwork === "0x89") { // Polygon
                    let estimatedGas = await contract.methods.withdrawUser(BigInt(amount * one_token)).estimateGas();
                    console.log("estimated gas: " + estimatedGas);
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
        if (window.web3 && wallet.walletaddr !== undefined && data !== undefined && data.addr) {
            const contract = new window.web3.eth.Contract(serviceInstanceABI, data.addr);
            contract.setConfig({ "defaultNetworkId": wallet.walletnetwork });
            try {
                const one_token: number = 10**18;
                const gasPrice = await window.web3.eth.getGasPrice();
                let estimatedGas = useGas;
                if (wallet.walletnetwork === "0x89") { // Polygon
                    let estimatedGas = await contract.methods.withdrawProvider(BigInt(amount * one_token)).estimateGas();
                    console.log("estimated gas: " + estimatedGas);
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
        if (window.web3 && wallet.walletaddr !== undefined && data !== undefined && data.addr && details !== undefined && details.tokenAddress) {
            const contract = new window.web3.eth.Contract(serviceInstanceABI, data.addr);
            contract.setConfig({ "defaultNetworkId": wallet.walletnetwork });
            try {
                const gasPrice = await window.web3.eth.getGasPrice()

                let token: Contract<typeof tokenContractABI> = new window.web3.eth.Contract(tokenContractABI, details.tokenAddress)
                const decimals: bigint = await token.methods.decimals().call()
                console.log(`decimals: ${decimals}`)
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
                    console.log(`estimated gas: ${estimatedGas}`)
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
    
    <h2 class="{is_provider ? 'w3-green' : 'w3-gray'}">Service Instance - {data.addr}</h2>

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
    <p>daily price: {details.dayPrice / 10**18}</p>
    <p>user deposit: {details.deposit / 10**18}</p>
    <p>retracted: {details.retracted / 10**18}</p>
    <p>start time: {details.startTime}</p>
    <p>end time: {details.endTime}</p>
    <p>provider address: {details.providerAddress}</p>
    <p>user address: {details.userAddress}</p>
    {/if}

    <section class="withdrawal">
        <h3>Withdrawal from contract</h3>
        <form on:submit={w_handleSubmit}>
            <label for="amount">amount:</label>
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