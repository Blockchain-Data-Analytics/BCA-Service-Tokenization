
include "Base.thrift"

namespace py bca_market_services

struct OwnerData {
    1: required i32 id,
    2: string name,
    3: string email,
}

service Owner {
    OwnerData find_owner(1:i32 id) throws (1: Base.NotFound e)
}