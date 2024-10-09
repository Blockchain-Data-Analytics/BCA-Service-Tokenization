import { type Actions, fail, redirect, json } from '@sveltejs/kit'
import type { PageServerLoad } from './$types'

import prisma from '$lib/server/prisma.js'
import type { Controller } from '@prisma/client'

import { superValidate } from 'sveltekit-superforms/server'
import { zod } from 'sveltekit-superforms/adapters'
import { z } from "zod"

const controllerSchema = z.object({
    id: z.string().min(1),
    description: z.string().min(2),
    owner_id: z.string().min(2)
  })
  
export const load: PageServerLoad = async (event) => {
    const session = await event.locals.auth()
    console.log("session: " + JSON.stringify(session, null, 2))
    if (!session?.user?.id) {
      throw redirect(303, '/')
    }

    const controller: Controller|null = await prisma.controller.findUnique({
        where: { id: event.params.cid },
      })

    const form = await superValidate(controller, zod(controllerSchema));
        
    return {session, form, controller_id: event.params.cid}
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

      const form = await superValidate(event, zod(controllerSchema));
      try {
        console.log("update: " + JSON.stringify(form.data,null,2))
        const res = await prisma.controller.update({
            where: {
                id: form.data.id
            },
            data: {
                "description": form.data.description
            }
        });
        return {form}
      } catch (error) {
        console.log("error: " + JSON.stringify(error,null,2))
        return fail(422, { error: error.message });
      }
    },
  } satisfies Actions;
  