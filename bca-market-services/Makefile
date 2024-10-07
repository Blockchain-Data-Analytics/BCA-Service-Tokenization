THRIFT:=thrift
PYTHON:=python3

src/bca_market_services/ttypes.py: idl/Base.thrift
	$(THRIFT) --gen py -out src $<

src/bca_market_services/owner/Owner.py: idl/Owner.thrift
	$(THRIFT) --gen py -out src $<

all: src/bca_market_services/owner/Owner.py src/bca_market_services/ttypes.py

servicemanager: all
	${PYTHON} src/BCAServiceManager/ServiceManager.py

servicecontroller: all
	${PYTHON} src/ServiceProvider/ServiceController.py
