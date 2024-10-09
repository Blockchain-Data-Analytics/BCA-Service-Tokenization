from typing import List

import thriftpy2
provider_thrift = thriftpy2.load("../idl/Provider.thrift", module_name="provider_thrift")

# print(provider_thrift.Provider.__dict__)

from DbConnection import db_connection

from thriftpy2.protocol import TCyBinaryProtocolFactory
from thriftpy2.transport import TCyBufferedTransportFactory
from thriftpy2.rpc import make_server

class SProvider(object):
    def list_controllers(self) -> List[int]:
        return [0, 1, 3]

    def get_controller(self, id:int) -> provider_thrift.ControllerData:
        return provider_thrift.ControllerData(12, 44, [1,2,3])


db_connection()

server = make_server(provider_thrift.Provider, SProvider(), '127.0.0.1', 9001)
server.serve()