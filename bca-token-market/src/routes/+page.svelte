<script lang="ts">
    import { SignIn, SignOut } from "@auth/sveltekit/components"
    import { page } from "$app/stores"
</script>

<div class="w3-container w3-padding-32">

  <h1>BCA Market</h1>
  <div>
    {#if $page.data.session}
      {#if $page.data.session.user?.image}
        <p><img
          src={$page.data.session.user.image}
          class="avatar"
          alt="User Avatar"
          width="40px" height="40px"
        /></p>
      {/if}
      <p><span class="signedInText">
        <p><small>Welcome back</small></p>
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
</div>
