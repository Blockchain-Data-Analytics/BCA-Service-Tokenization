<script lang="ts">
    import LogEntry from "$lib/components/LogEntry.svelte"

    export let data

</script>

<div class="w3-container w3-padding-32">
{#each data.logentries as logentry}
    <LogEntry card=true id={logentry.id} user={logentry.user} amount={logentry.amount} action={logentry.action} target={logentry.target} txhash={logentry.txhash} created={logentry.created} ></LogEntry>
{/each }
</div>
