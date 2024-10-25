import { type Actions, fail, redirect } from '@sveltejs/kit'
import type { PageServerLoad } from './$types'

import prisma from '$lib/server/prisma.js'
import type { Service, Pricing } from '@prisma/client'

import { superValidate } from 'sveltekit-superforms/server'
import { zod } from 'sveltekit-superforms/adapters'
import { z } from "zod"

const serviceSchema = z.object({
    id: z.number(),
    amount: z.number(),
    created: z.date(),
    updated: z.date(),
    description: z.string().min(2),
    owner_id: z.string().min(2),
    price_id: z.nullable(z.number()),
    controller_id: z.string().min(1)
  })
  
export const load: PageServerLoad = async (event) => {
    const session = await event.locals.auth()
    console.log("session: " + JSON.stringify(session, null, 2))
    if (!session?.user?.id) {
      throw redirect(303, '/')
    }

    const service: Service|null = await prisma.service.findUnique({
        where: { id: parseInt(event.params.sid) },
      })

    const form = await superValidate(service, zod(serviceSchema));

    let pricing: Pricing|null = null
    if (service?.price_id) {
      pricing = await prisma.pricing.findUnique({
        where: { id: service?.price_id },
      })
    }
        
    return {session, form, pricing, controller_id: event.params.cid, service_id: event.params.sid}
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

      const form = await superValidate(event, zod(serviceSchema));
      try {
        console.log("update: " + JSON.stringify(form.data,null,2))
        const res = await prisma.service.update({
            where: {
                id: form.data.id
            },
            data: {
                "description": form.data.description,
                "amount": form.data.amount,
            }
        });
        return {form}
      } catch (error) {
        console.log("error: " + JSON.stringify(error,null,2))
        return fail(422, { error: error.message });
      }
    },
  } satisfies Actions;
  