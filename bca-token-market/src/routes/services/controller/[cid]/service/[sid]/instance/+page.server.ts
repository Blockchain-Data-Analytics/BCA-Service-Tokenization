import { type Actions, fail, redirect, json } from '@sveltejs/kit'
import type { PageServerLoad } from './$types'

import prisma from '$lib/server/prisma.js'
import type { Instance } from '@prisma/client'

export const load: PageServerLoad = async (event) => {
    const session = await event.locals.auth()
    // console.log("session: " + JSON.stringify(session, null, 2))
    if (!session?.user?.id) {
      throw redirect(303, '/')
    }

    const controller_id = event.params.cid
    const service_id = event.params.sid
    const instances: Instance[] = await prisma.instance.findMany({
        where: {
          "service_id": parseInt(service_id)
        },
      })
  
    return { session, instances, controller_id, service_id }
}

export const actions = {
  new: async (event) => {
    const session = await event.locals.auth()
    if (!session?.user?.id) {
      throw redirect(303, '/')
    }

    if (session?.user?.role !== "Provider") {
      return fail(400, { error: "wrong role" })
    }
    try {
      const service_id = event.params.sid
      const res = await prisma.instance.create({
        data: {
          "service_id": parseInt(service_id),
          "userId": session?.user?.id,
          "description": "add a new description here",
        }
      });
      return {res}
    } catch (error) {
      return fail(422, { error: error.message });
    }
  },
} satisfies Actions;
