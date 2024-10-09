<script lang="ts">
    import { page } from "$app/stores"
    import { superForm } from "sveltekit-superforms/client"
    // import SuperDebug from "sveltekit-superforms/client/SuperDebug.svelte"

    export let data
    const { form, errors } = superForm(data.form)

    const is_provider = $page.data.session.user.role == "Provider"
</script>

{#if $page.data.session}
<div class="w3-container w3-padding-32">

    <p><a href="/services/controller/{data.controller_id}">controller</a>
     - <a href="/services/controller/{data.controller_id}/service">services</a>
     - <a href="/services/controller/{data.controller_id}/service/{data.service_id}/instance">instances</a></p>
    <h2 class="{is_provider ? 'w3-green' : 'w3-gray'}">Service</h2>

    <form method="POST" class="w3-container">
        <label>
            id:
            <input name="id" id="id" autocomplete="off" class="w3-input" readonly bind:value={$form.id}/>
        </label>
        <label>
            user:
            <input name="userId" id="userId" autocomplete="off" class="w3-input" readonly bind:value={$form.userId}/>
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
        <p>{#if is_provider}<button type="submit" class="w3-btn w3-blue" formaction="?/update">save</button>{/if}</p>
    </form>
</div>
<!-- <div class="w3-container w3-gray">
    <SuperDebug data={form}/>
</div> -->
{/if}