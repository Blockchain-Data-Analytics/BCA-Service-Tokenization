<script lang="ts">
    export let id: number
    export let user: string
    export let amount: number
    export let action: string
    export let target: string
    export let txhash: string
    export let created: string
    export let card: boolean = true;
</script>
{#if card}
<div class="w3-card w3-padding-16">
    <table class="w3-table w3-bordered">
    <tr><td><label for="log-id">id</label></td><td><span class="log-value" id="log-id">{id}</span></td></tr>
    <tr><td><label for="log-user">user</label></td><td><span class="log-value" id="log-user">{user}</span></td></tr>
    <tr><td><label for="log-amount">amount</label></td><td><span class="log-value" id="log-amount">{amount}</span></td></tr>
    <tr><td><label for="log-action">action</label></td><td><span class="log-value" id="log-action">{action}</span></td></tr>
    <tr><td><label for="log-target">target</label></td><td><span class="log-value" id="log-target">{target}</span></td></tr>
    <tr><td><label for="log-txhash">txhash</label></td><td><span class="log-value" id="log-txhash">{txhash}</span></td></tr>
    <tr><td><label for="log-created">created</label></td><td><span class="log-value" id="log-created">{created}</span></td></tr>
    </table>
</div>
{:else}
    <table border=0 class="log-value">
        <tr>
            <td>{id}</td>
            <td>{user}</td>
            <td>{amount}</td>
            <td>{action}</td>
            <td>{target}</td>
            <td>{txhash}</td>
            <td>{created}</td>
        </tr>
    </table>
{/if}