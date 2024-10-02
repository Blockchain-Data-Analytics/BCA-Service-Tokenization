import { SvelteKitAuth } from "@auth/sveltekit"
import GitHub from "@auth/sveltekit/providers/github"
// import Gitlab from "@auth/sveltekit/providers/gitlab"
// import Passkey from "@auth/sveltekit/providers/passkey"
 
export const { handle, signIn, signOut } = SvelteKitAuth({
  debug: true,
  providers: [GitHub],
})
