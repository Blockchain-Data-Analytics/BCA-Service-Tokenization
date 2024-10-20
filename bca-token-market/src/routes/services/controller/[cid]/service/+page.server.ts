import { type Actions, fail, redirect, json } from '@sveltejs/kit'
import type { PageServerLoad } from './$types'

import prisma from '$lib/server/prisma.js'
import type { Service } from '@prisma/client'

export const load: PageServerLoad = async (event) => {
    const session = await event.locals.auth()
    // console.log("session: " + JSON.stringify(session, null, 2))
    if (!session?.user?.id) {
      throw redirect(303, '/')
    }

    const controller_id = event.params.cid
    let services: Service[]
    if (session?.user?.role == "Provider") {
      services = await prisma.service.findMany({
        where: {
          owner_id: session.user.id,
          controller_id
        },
      })
    } else {
      services = await prisma.service.findMany({
        where: {
          controller_id
        },
      })
    }
    const locale = 'en';
    const options: Intl.DateTimeFormatOptions = {
      weekday: undefined,
      year: 'numeric',
      month: 'numeric',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
      second: '2-digit',

    };
    const formatter = new Intl.DateTimeFormat(locale, options);
    services.map((val: Service, index: number) => {
      const formattedDate = formatter.format(val.created);
      // console.log(` idx: ${index}  value: ${val.created} new: ${formattedDate} type: ${typeof(val.created)}`)
    })
    return { session, services, controller_id  }
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
      const res = await prisma.service.create({
        data: {
          "owner_id": session?.user?.id,
          "controller_id": event.params.cid,
          "description": "add a new description here",
          "amount": 0,
        }
      });
      // console.log("new controller: " + JSON.stringify(res,null,2))
      return {res}
    } catch (error) {
      return fail(422, { error: error.message });
    }
  },
} satisfies Actions;
