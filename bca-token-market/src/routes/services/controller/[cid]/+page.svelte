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

    <p><a href="/services/controller">controllers</a></p>
    <h2 class="{is_provider ? 'w3-green' : 'w3-gray'}">Controller</h2>

    <form method="POST" class="w3-container">
        <label>
            id:
            <input name="id" id="id" autocomplete="off" class="w3-input" readonly bind:value={$form.id}/>
        </label>
        <label>
            description:
            <input name="description" id="description" autocomplete="off" class="w3-input" required bind:value={$form.description}/>
        </label>
        {#if $errors.description}
            <div class="w3-panel w3-red">{$errors.description}</div>
        {/if}
        <label>
            owner:
            <input name="owner_id" id="owner" autocomplete="off" class="w3-input" readonly  bind:value={$form.owner_id}/>
        </label>
        <p>{#if is_provider}<button type="submit" class="w3-btn w3-blue" formaction="?/update">save</button>{/if}</p>
    </form>
</div>
<!-- <div class="w3-container w3-gray">
    <SuperDebug data={form}/>
</div> -->
{/if}