<script lang="ts">
    import { page } from "$app/stores"
    import { Form } from "svelte-forms-lib";
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

    <p><a href="/services/controller">controllers</a>
     - <a href="/services/controller/{data.controller_id}/service">services</a></p>

    <h2 class="{is_provider ? 'w3-green' : 'w3-gray'}">Instances</h2>

    <table class="w3-table w3-striped">
         <tr><th>id</th><th>created</th><th>updated</th><th>description</th><th>service</th><th>user</th></tr>
         {#each data.instances as instance}
            <tr><td><i class="fa fa-edit"></i> <a href="/services/controller/{data.controller_id}/service/{data.service_id}/instance/{instance.id}">{instance.id}</a></td>
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
    {/if}
</div>
{/if}