<script lang="ts">
    import { page } from "$app/stores"
    import { serviceManagerAddress } from "$lib/contracts"

    const is_provider = $page.data.session?.user?.role == "Provider"
</script>

<div class="w3-container w3-padding-32">
    <p><a href="/servicemanager">Service Manager</a></p>
    
    {#if $page.data.session && is_provider}
    
    <h2 class="{is_provider ? 'w3-green' : 'w3-gray'}">Service Manager</h2>
    <p>Continue to this system's <a href={"/servicemanager/" + serviceManagerAddress}>Service Manager</a></p>

    {/if}
</div>