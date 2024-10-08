<script lang="ts">
    import { page } from "$app/stores"
    import { string } from "zod";

    export let data

    const is_provider = $page.data.session.user.role == "Provider"
</script>

{#if $page.data.session}
<div class="w3-container w3-padding-32">

    <h2 class="{is_provider ? 'w3-green' : 'w3-gray'}">Instances</h2>

    <table class="w3-table w3-striped">
         <tr><th>id</th><th>description</th><th>owner</th></tr>
         {#each data.controllers as controller}
            <tr><td><a href="/services/controller/{controller.id}">{controller.id.substring(0,6)}..{controller.id.substring(controller.id.length - 5)}</a></td><td>{controller.description}</td><td>{controller.owner_id}</td></tr>
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
    {/if}
</div>
{/if}