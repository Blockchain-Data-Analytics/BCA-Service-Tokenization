include "Base.thrift"
include "Owner.thrift"

namespace py bca_market_services

struct ControllerData {
    1: required i32 id,
    2: i32 owner,
    3: list<i32> serviceids,
    4: string description,
}

struct ServiceData {
    1: required i32 id,
    2: string name,
    3: i32 pricingid,
    4: string description,
}

typedef i16 hours
struct PricingData {
    1: required i32 id,
    2: string description,
    3: hours period,
    4: i32 setupFee,
    5: i32 tickFee,
}

struct InstanceData {
    1: required i32 id,
    2: i32 serviceid,
    3: i32 userid,
    4: i32 credentialid,
}

enum Protocol { TCP = 1, UDP = 2 }
struct CredentialData {
    1: required i32 id,
    2: string address,
    3: i8 port,
    4: Protocol protocol
    5: string username
    6: string password
    7: string pubkey

}

service ServiceController {
    list<i32>     list_services()
    ServiceData   get_service(1:i32 id) throws (1: Base.NotFound e)
    list<i32>     list_pricings()
    PricingData   get_pricing(1:i32 id) throws (1: Base.NotFound e)
    list<i32>     list_instances(1:i32 userid)
    InstanceData  get_instance(1:i32 id) throws (1: Base.NotFound e)
}

service Provider extends Owner.Owner {
    list<i32>       list_controllers()
    ControllerData  get_controller(1:i32 id) throws (1: Base.NotFound e)
}
