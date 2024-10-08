import { type Actions, fail, redirect, json } from '@sveltejs/kit'
import type { PageServerLoad } from './$types'

import prisma from '$lib/server/prisma.js'
import type { Controller } from '@prisma/client'

export const load: PageServerLoad = async (event) => {
    const session = await event.locals.auth()
    // console.log("session: " + JSON.stringify(session, null, 2))
    if (!session?.user?.id) {
      throw redirect(303, '/')
    }

    const controllers: Controller[] = await prisma.controller.findMany({
        where: { owner_id: session.user.id },
      })
        
    return { session, controllers }
}

export const actions = {
  new: async (event) => {
    const session = await event.locals.auth()
    if (!session?.user?.id) {
      throw redirect(303, '/')
    }

    // const form = await event.request.formData();
    if (session?.user?.role !== "Provider") {
      return fail(400, { error: "wrong role" })
    }
    try {
      const res = await prisma.controller.create({
        data: {
          "owner_id": session?.user?.id,
          "description": "add a new description here"
        }
      });
      // console.log("new controller: " + JSON.stringify(res,null,2))
      return {res}
    } catch (error) {
      return fail(422, { error: error.message });
    }
  },
} satisfies Actions;
