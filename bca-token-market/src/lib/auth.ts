import { SvelteKitAuth } from "@auth/sveltekit"
import { PrismaAdapter } from "@auth/prisma-adapter"
import prisma from "$lib/prisma"
import GitHub from "@auth/sveltekit/providers/github"
import Gitlab from "@auth/sveltekit/providers/gitlab"
import Auth0 from "@auth/core/providers/auth0"

export const { handle, signIn, signOut } = SvelteKitAuth({
  debug: true,
  providers: [GitHub, Auth0, Gitlab],
  trustHost: true,
  // sessions are stored in the database
  adapter: PrismaAdapter(prisma),
  // augment session user information
  callbacks: {
    session({ session, user }) {
      session.user.id = user.id
      return session
    },
  }
})
