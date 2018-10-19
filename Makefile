.PHONY: all test check-env clean distclean

PROJECT=atf

#Please setup QMAKE enviroment variable
#QMAKE=/home/arv/Qt/5.4/gcc/bin/qmake

SOURCES= src/lua_interpreter.cc \
	src/main.cc \
	src/marshal.cc \
	src/network.cc \
	src/qtdynamic.cc \
	src/qtlua.cc \
	src/qdatetime.cc \
	src/timers.cc

all: interp modules/libxml.so modules/libmq.so modules/libluaopenssl.so

interp: $(PROJECT).mk $(SOURCES)
	make -f $<
	rm -f moc_*.cpp moc_*.h .qmake.stash

modules/libxml.so: src/lua_xml.cc
	$(CXX) $(CXXFLAGS) -shared -std=c++11 $< -o modules/libxml.so -g -I/usr/include/libxml2 -llua5.2 -lxml2 -fPIC

modules/libmq.so:
	cd ./modules/luamq/; make
	cp -f ./modules/luamq/src/mq.so ./modules/libmq.so
	rm -f ./modules/luamq/src/mq.so ./modules/luamq/src/lua-mq.o

modules/libluaopenssl.so: src/lua_openssl.cc
	$(CXX) $(CXXFLAGS) -shared -std=c++11 $< -o modules/libluaopenssl.so -g -I/usr/include/openssl -llua5.2 -lssl -lcrypto -fPIC

clean:
	rm -f $(PROJECT).mk
	rm -f *.o moc_*.cpp *.aux *.log *.so *.a
	rm -f modules/*.so modules/.obj/*.o
	-make -C test clean
	rm -f test/*.so* test/.obj/*.o test/Makefile
	rm -f test/out/*.out

distclean: clean
	rm -f	bin/interp libqttest.so
	-make -C test distclean

test/Makefile: test/test.pro check-env
	$(QMAKE) $< -o $@

libqttest.so: $(SOURCES) test/Makefile
	make -C test
	ln -sf test/libqttest.so.1.0.0 libqttest.so

test: run_tests.sh
	./test/run_tests.sh

run_tests.sh: bin/interp libqttest.so test/testbase.lua modules/libxml.so \
	test/dynamic.lua test/connect.lua test/network.lua \
	test/reportTest.lua test/SDLLogTest.lua

$(PROJECT).mk: $(SOURCES) $(PROJECT).pro check-env
	$(QMAKE) $(PROJECT).pro -o $@

check-env:
ifndef QMAKE
	$(error Set QMAKE system environment with command: \
	export QMAKE={full_path_to_qmake_v5.3} . \
	Searching hint: locate -b '\qmake')
else
	$(info using QMAKE=$(QMAKE))
endif
