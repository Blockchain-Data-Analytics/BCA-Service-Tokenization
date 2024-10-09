import { type Actions, fail, redirect } from '@sveltejs/kit'
import type { PageServerLoad } from './$types'

import prisma from '$lib/server/prisma.js'
import type { Preference } from '@prisma/client'

import { superValidate } from 'sveltekit-superforms/server'
import { zod } from 'sveltekit-superforms/adapters'
import { z } from "zod"

const addrSchema = z.object({
  address: z.string().min(31)
})

// return value is available as variable "data" in page
export const load: PageServerLoad = async (event) => {
  const session = await event.locals.auth()
  if (!session?.user?.id) {
    throw redirect(303, '/')
  }
 
  const preference: Preference = await prisma.preference.findUnique({
    where: { userId: session?.user?.id },
  })

  let userPrefs = { address: 'unknown' }
  if (preference) {
    const ps = JSON.parse(preference.prefs)
    if (ps && ps["poly_addr"]) {
        userPrefs = { address: ps["poly_addr"] }
    }
  }
  
  const form = await superValidate(userPrefs, zod(addrSchema));

  return { form }
};

// return value is available as variable "form" in page
export const actions = {
  update: async (event) => {
    const session = await event.locals.auth()
    // console.log("session: " + JSON.stringify(session,null,2))
    if (!session?.user?.id) {
      throw redirect(303, '/')
    }

    const form = await superValidate(event, zod(addrSchema));
    if (!form.valid) {
      return fail(400, { form })
    }
    try {
      const userId: string = session?.userId
      const addr: string = form.data.address
      if (userId && addr) {
        const preferences = JSON.stringify({ "poly_addr": addr }, null, 2)
        const prefs = await prisma.preference.upsert({
          where: { userId },
          update: { prefs: preferences },
          create: { userId, prefs: preferences }
        });
        return { form }
      } else {
        console.log("something null")
        return fail(400, { description: "missing values", error: 'nulls' })
      }
    } catch (error) {
      return fail(422, { error: error.message });
    }
  },
} satisfies Actions;
