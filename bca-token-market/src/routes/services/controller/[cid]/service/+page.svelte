<script lang="ts">
    import { page } from "$app/stores"
    import { string } from "zod";

    export let data

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
</script>

{#if $page.data.session}
<div class="w3-container w3-padding-32">

    <p><a href="/services/controller">controllers</a></p>
    <h2 class="{is_provider ? 'w3-green' : 'w3-gray'}">Services</h2>

    <table class="w3-table w3-striped">
         <tr><th>id</th><th>instances</th><th>created</th><th>updated</th><th>amount</th><th>description</th><th>pricing</th><th>owner</th><th>controller</th></tr>
         {#each data.services as service}
            <tr>
                <td><i class="fa fa-edit"></i> <a href="/services/controller/{data.controller_id}/service/{service.id}">{service.id}</a></td>
                <td><i class="fa fa-search"></i> <a href="/services/controller/{data.controller_id}/service/{service.id}/instance">list instances</a></td>
                <td>{date_formatter.format(service.created)}</td>
                <td>{date_formatter.format(service.updated)}</td>
                <td>{service.amount}</td>
                <td>{service.description}</td>
                <td>{service.price_id}</td>
                <td>{service.owner_id}</td>
                <td><i class="fa fa-arrow-right"></i> <a href="/services/controller/{service.controller_id}">{service.controller_id.substring(0,6)}..{service.controller_id.substring(service.controller_id.length - 5)}</a></td>
            </tr>
         {/each}
    </table>
    <div class="w3-container">
        <form method="POST" class="w3-container">
            <input type="hidden" name="action" value="new" />
            {#if is_provider }
            <button type="submit" class="w3-btn w3-blue" formaction="?/new">new</button>
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