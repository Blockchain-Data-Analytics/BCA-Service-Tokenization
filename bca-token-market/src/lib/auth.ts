import { SvelteKitAuth } from "@auth/sveltekit"
import GitHub from "@auth/sveltekit/providers/github"
import Gitlab from "@auth/sveltekit/providers/gitlab"
import Auth0 from "@auth/core/providers/auth0"

export const { handle, signIn, signOut } = SvelteKitAuth({
  debug: true,
  providers: [GitHub, Auth0, Gitlab],
  trustHost: true,
})
