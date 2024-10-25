import { type Actions, fail, redirect } from '@sveltejs/kit'
import type { PageServerLoad } from './$types'

import prisma from '$lib/server/prisma.js'
import type { Instance } from '@prisma/client'

import { superValidate } from 'sveltekit-superforms/server'
import { zod } from 'sveltekit-superforms/adapters'
import { z } from "zod"

const instanceSchema = z.object({
    id: z.number(),
    created: z.date(),
    updated: z.date(),
    description: z.string().min(2),
    userId: z.string().min(2),
    service_id: z.number(),
    contract_addr: z.nullable(z.string()),
  })
  
export const load: PageServerLoad = async (event) => {
    const session = await event.locals.auth()
    console.log("session: " + JSON.stringify(session, null, 2))
    if (!session?.user?.id) {
      throw redirect(303, '/')
    }

    const instance: Instance|null = await prisma.instance.findUnique({
        where: { id: parseInt(event.params.iid) },
      })

    const form = await superValidate(instance, zod(instanceSchema));
        
    return {session, form, controller_id: event.params.cid, service_id: event.params.sid}
}

export const actions = {
    update: async (event) => {
      const session = await event.locals.auth()
      if (!session?.user?.id) {
        throw redirect(303, '/')
      }
      if (session?.user?.role !== "Provider") {
        return fail(400, { error: "wrong role" })
      }

      const form = await superValidate(event, zod(instanceSchema));
      try {
        // console.log("update: " + JSON.stringify(form.data,null,2))
        const res = await prisma.instance.update({
            where: {
                id: form.data.id
            },
            data: {
                "description": form.data.description,
            }
        });
        return {form}
      } catch (error) {
        console.log("error: " + JSON.stringify(error,null,2))
        return fail(422, { error: error.message });
      }
    },
  } satisfies Actions;
  