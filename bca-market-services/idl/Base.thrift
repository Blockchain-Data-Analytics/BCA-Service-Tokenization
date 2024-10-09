namespace py bca_market_services

exception InvalidOperation {
    1: i32 noSuchOp,
    2: string reason
}

exception NotFound {
    1: i32 noSuchId,
    2: string reason
}
