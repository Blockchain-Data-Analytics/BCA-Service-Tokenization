<script lang="ts">
    import { onMount } from 'svelte';
    import { Web3 } from 'web3';

    import { createForm } from "svelte-forms-lib";

    import abi from "../../lib/amoy_token-abi.json";

    const contractAddress = "0x8575aecd20dcd1aa3fc83a0ac29b1f71714f47f3";

    let warning = undefined
    let walletnetwork = undefined
    let networkname : string = "unknown"
    let walletaddr: string | undefined = undefined
    let walletbalance = undefined

    onMount ( () => {
        if (window.ethereum) {
            window.web3 = new Web3(window.ethereum);
        } else {
            warning = "no web3 wallet attached!"
        }
    })

    async function get_wallet_chainid() {
        try {
            window.ethereum.request({ method: 'eth_chainId' }).then(function(v) {
                walletnetwork = v;
                if (walletnetwork === "0x1") { networkname = "ethereum" }
                if (walletnetwork === "0x89") { networkname = "polygon" }
                if (walletnetwork === "0xa4b1") { networkname = "arbitrum" }
                if (walletnetwork === "0xa86a") { networkname = "avalanche" }
                if (walletnetwork === "0x13882") { networkname = "polygon amoy testnet" }
            })
            warning = undefined;
        } catch (error) {
            warning = "error while accessing wallet: " + error;
        }
    }
    function reset_warning() { warning = undefined }

    async function wallet_logout() {
        if (window.web3 && walletaddr !== undefined) {
            await window.ethereum.request({
                "method": "wallet_revokePermissions",
                "params": [
                    {
                    "eth_accounts": { "addr": walletaddr }
                    }
                ]
                });
        }
        walletnetwork = undefined
        networkname = ""
        walletaddr = undefined
        walletbalance = undefined
    }
    async function get_wallet_balance(ev) {
        if (window.web3 && walletaddr !== undefined) {
            ev.target.setAttribute("disabled","disabled")
            walletbalance = await window.web3.eth.getBalance(walletaddr);
            warning = undefined
            ev.target.removeAttribute("disabled")
        } else {
            walletbalance = undefined;
        }
    }
    async function get_wallet_addr(ev) {
        if (window.web3) {
            ev.target.setAttribute("disabled","disabled")
            try {
                // get active network in wallet
                get_wallet_chainid()
                // request user's account address - prompts Metamask to login
                const selectedAccount = await window.ethereum
                    .request({
                        method: "eth_requestAccounts",
                    })
                    .then((accs) => accs[0])
                    .catch(() => {
                        throw Error("Please select an account in your wallet");
                    });

                walletaddr = selectedAccount;
                warning = undefined

            } catch (error) {
                warning = "error while accessing wallet: " + error;
            }
            ev.target.removeAttribute("disabled")
        } else {
            warning = "wallet not found";
        }
    }

    async function mint_tokens(toAddress, amount) {
        if (window.web3 && walletaddr !== undefined) {
            const contract = new window.web3.eth.Contract(abi, contractAddress);
            try {
                await contract.methods.balanceOf(contractAddress).call().then(console.log);
                await contract.methods.name().call().then(console.log);
                await contract.methods.symbol().call().then(console.log);
                await contract.methods.decimals().call().then(console.log);
                // console.log("mint fun: " + (contract.methods.mint));
                // const estimatedGas = await contract.methods.mint(toAddress, amount)
                //     .estimateGas();
                // console.log("estimated gas: " + estimatedGas);
                const receipt = await contract.methods
                    .mint(toAddress, amount)
                    .send({
                        from: walletaddr,
                        gas: 1200000,
                        gasPrice: '10000000000',
                    });
                console.log("Transaction Hash: " + receipt.transactionHash);
            } catch (error) {
                console.error(error);
            }
        }
    }

    const { form, handleChange, handleSubmit } = createForm({
        initialValues: {
            receiver: "0x590Ea4BadDdB5041fe220C0260Eb26060e9c3fB6",  // User1
            amount: "100"
        },
        onSubmit: values => {
            // alert(JSON.stringify(values));
            mint_tokens(values.receiver, values.amount);
        }
        });

</script>

<svelte:head>
        <title>BCA Wallet: minting tokens</title>
        <meta name="description" content="wallet" />
</svelte:head>

<h1>BCA Tokens: minting</h1>

{#if warning !== undefined}
<p>Warning: {warning}</p>
<p><button type="button" on:click={ () => reset_warning() }>reset warning</button></p>
{:else}
<!-- LOGIN SECTION -->
<section class="login-section">
    <p><button type="button" class="login-btn" on:click={ (ev) => get_wallet_addr(ev) }>🔓 Log in with Web3</button></p>
    <span class="instruction">
      Ensure to have an Ethereum based wallet installed i.e MetaMask. Change the network and account in the wallet and 
      click the button again to update the app's state.
    </span>
</section>

<!-- DASHBOARD SECTION -->
<section class="dashboard-section">
    {#if walletnetwork !== undefined && walletaddr !== undefined}
    <h3 class="wallet-status">Wallet available</h3>
    <h4 class="wallet-address-heading">
      Wallet address:
      <span class="typewriter">{networkname}({walletnetwork})</span> / 
      <span class="typewriter">{walletaddr}</span>
    </h4>
    {#if walletbalance !== undefined}
    <h4 class="wallet-balance-heading">
     Balance:
      <span class="wallet-balance">{walletbalance}</span>
    </h4>
    {/if}
    <p><button type="button" on:click={ (ev) => get_wallet_balance(ev) }>refresh balance</button></p>
    <p><button type="button" class="logout-btn" on:click={ () => wallet_logout() }>🔐 Log out</button></p>
    {/if}
</section>

<section class="action">
    {#if walletnetwork !== undefined && walletaddr !== undefined}
    <h3>Minting tokens</h3>
    <form on:submit={handleSubmit}>
        <label for="receiver">receiver</label>
        <input
          id="receiver"
          name="receiver"
          on:change={handleChange}
          bind:value={$form.receiver}
        />    
        <label for="amount">amount</label>
        <input
          id="amount"
          name="amount"
          on:change={handleChange}
          bind:value={$form.amount}
        />
        <button type="submit">Mint</button>
      </form>
    {/if}
</section>
{/if}

