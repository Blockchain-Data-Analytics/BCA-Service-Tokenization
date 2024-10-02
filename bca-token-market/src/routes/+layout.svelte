<script lang="ts">
    import { page } from "$app/stores"
</script>

<nav class="w3-top w3-bar w3-black">
    <div class="w3-container w3-padding-16">
    <a href="/">Home</a>
    {#if $page.data.session}
    <a href="/services">Services</a>
    <a href="/users">Users</a>
    <div class="w3-right w3-hide-small">
        <small>{$page.data.session.user?.name ?? "User"}</small>
    </div>
    {/if}
    </div>
</nav>

<div class="w3-container w3-padding-32">
    <p> </p>
<slot></slot>
</div>
        
<footer class="w3-center w3-black w3-panel w3-padding-32">
    <p>Powered by <a href="https://github.com/Blockchain-Data-Analytics" title="BCA Blockchain Analytics" target="_blank" ><img src="/bca_logo.png" alt="BCA Blockchain Analytics" width=24 height=24 /></a> BCA</p>
</footer>