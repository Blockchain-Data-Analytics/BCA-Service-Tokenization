<script lang="ts">
    import { page } from "$app/stores"
</script>

{#if $page.data.session}

<div class="w3-container w3-padding-32">

    <h2>User Account</h2>

    <div>
    <h3>Debits</h3>
    
    ...
    </div>
    <div>
    <h3>Credits</h3>
    
    ...
    </div>
    
</div>
{/if}
