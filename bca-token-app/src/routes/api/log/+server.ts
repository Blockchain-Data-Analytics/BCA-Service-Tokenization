import prisma from "$lib/prisma";
import { json } from "@sveltejs/kit";

import type { RequestHandler } from "./$types";

// inject BigInt serialisation to JSON
(BigInt.prototype as any).toJSON = function () {
  return this.toString();
};

export const POST: RequestHandler = async ({ request }) => {
  const { user, amount, action, target, txhash } = await request.json();
  const logentry = await prisma.adminAudit.create({
    data: {
        user,
        amount,
        action,
        target,
        txhash
    },
  });

  return json(logentry);
};
