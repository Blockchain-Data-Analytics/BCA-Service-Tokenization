import thriftpy2

provider_thrift = thriftpy2.load("../idl/Provider.thrift", module_name="provider_thrift")

from thriftpy2.rpc import make_client

client = make_client(provider_thrift.Provider, '127.0.0.1', 9001)
print(client.list_controllers())
print(client.get_controller(0))
