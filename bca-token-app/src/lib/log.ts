
// create a log entry in the table "AdminAudit"
export async function log(user: string, amount: number, action: string, target: string, txhash: string) {
    const logentry = await (
        await fetch('/api/log', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                user,
                amount,
                action,
                target,
                txhash
            })
        }) ).json()
    console.log("Log entry: " + JSON.stringify(logentry, null, 2))
}