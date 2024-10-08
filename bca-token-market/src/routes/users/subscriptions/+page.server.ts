import { redirect } from '@sveltejs/kit';
import type { PageServerLoad } from './$types';

import prisma from '$lib/server/prisma.js'
import type { Instance, Service } from '@prisma/client'

export const load: PageServerLoad = async (event) => {
  const session = await event.locals.auth()
 
  if (!session?.user?.id) {
    throw redirect(303, '/')
  }
 
  const instances = await prisma.instance.findMany({
    where: { userId: session?.user?.id },
    relationLoadStrategy: 'join', // or 'query'
    include: {
      service: true,
    },
  })

  console.log("instances: " + JSON.stringify(instances,null,2))
  return { instances }
  };
