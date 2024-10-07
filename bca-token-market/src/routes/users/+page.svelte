<script lang="ts">
    import { SignOut } from "@auth/sveltekit/components"
    import { page } from "$app/stores"
</script>

<div class="w3-container w3-padding-32">

{#if $page.data.session}

<a href="users/preferences">Preferences</a>
<a href="users/subscriptions">Subscriptions</a>
<a href="users/account">Account</a>

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

{#if $page.data.session.user}
<h2>Your profile information</h2>
<p>id: {$page.data.session.user.id}</p>
<p>name: {$page.data.session.user.name}</p>
<p>email: {$page.data.session.user.email}</p>
<p>image: {$page.data.session.user.image}</p>
<p><small>This session expires: {$page.data.session.expires}</small></p>
{/if}
{/if}

</div>