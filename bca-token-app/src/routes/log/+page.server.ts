import prisma from '$lib/prisma.js'
import type { ServerLoadEvent } from '@sveltejs/kit';
import type { PageServerLoad } from './$types';

interface LogEntry {
    id: number;
    user: string;
    amount: bigint;
    action: string;
    target: string;
    txhash: string;
    created: Date;
}

export const load = (async (e: ServerLoadEvent) => {
    const pagesz = 10; //(params ?? params.pagesz) || 10;
    const logentries = await prisma.adminAudit.findMany({
        skip: 0, //(params ?? params.pageno ?? (params.pageno * pagesz)) || 0,
        take: pagesz,
        orderBy: {
            created: 'desc',
        }
    });
    var results : LogEntry[] = [];
    for (const [idx, e] of logentries.entries()) {
        results.push({
            id: e.id,
            user: e.user,
            amount: BigInt(e.amount.toNumber()),
            action: e.action,
            target: e.target,
            txhash: e.txhash,
            created: e.created
        });
    }
    return {
        logentries: results
    };
}) satisfies PageServerLoad;