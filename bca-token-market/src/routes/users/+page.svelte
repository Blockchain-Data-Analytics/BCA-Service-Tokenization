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
<h3>profile information</h3>
<table class="w3-table w3-bordered">
<tr><td>id:</td><td>{$page.data.session.user.id}</td></tr>
<tr><td>name:</td><td>{$page.data.session.user.name}</td></tr>
<tr><td>email:</td><td>{$page.data.session.user.email}</td></tr>
<tr><td>role:</td><td>{$page.data.session.user.role}</td></tr>
<tr><td>image:</td><td>{$page.data.session.user.image}</td></tr>
<tr><td>session expires:</td><td>{$page.data.session.expires}</td></tr>
</table>
{/if}
{/if}

</div>