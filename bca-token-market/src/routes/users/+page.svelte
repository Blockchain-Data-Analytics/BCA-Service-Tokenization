<script lang="ts">
    import { SignIn, SignOut } from "@auth/sveltekit/components"
    import { page } from "$app/stores"
</script>

<div class="w3-container w3-padding-32">

{#if $page.data.session}

<a href="./preferences">Preferences</a>
<a href="./subscriptions">Subscriptions</a>

{#if $page.data.session.user?.image}
<p><img
  src={$page.data.session.user.image}
  class="avatar"
  alt="User Avatar"
  width="20%"
/></p>
{/if}
<p><span class="signedInText">
<p><small>Signed in as</small></p>
<p><strong>{$page.data.session.user?.name ?? "User"}</strong>
{$page.data.session.user?.email ?? "Email"}</p>
</span></p>
<SignOut>
<div slot="submitButton" class="w3-button buttonPrimary">Sign out</div>
</SignOut>

{:else}
    <p><span class="notSignedInText">You are not signed in</span></p>
    <p><SignIn>
        <div slot="submitButton" class="w3-button buttonPrimary">Sign in</div>
    </SignIn></p>
{/if}

</div>