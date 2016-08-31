.PHONY: all test check-env clean distclean

PROJECT=atf

#Please setup QMAKE enviroment variable
#QMAKE=/home/arv/Qt/5.4/gcc/bin/qmake

SOURCES= lua_interpreter.cc \
	main.cc \
	marshal.cc \
	network.cc \
	qtdynamic.cc \
	qtlua.cc \
	qdatetime.cc \
	timers.cc

all: interp modules/libxml.so

interp: $(PROJECT).mk $(SOURCES)
	ln -sf `g++ -print-file-name=libgcc.a`
	ln -sf `g++ -print-file-name=libstdc+.a`
	make -f $<

modules/libxml.so: lua_xml.cc
	$(CXX) $(CXXFLAGS) -shared -std=c++11 $< -o modules/libxml.so -g -I/usr/include/libxml2 -llua5.2 -lxml2 -fPIC

clean:
	rm -f $(PROJECT).mk
	rm -f *.o moc_*.cpp *.aux *.log *.so *.a
	rm -f modules/*.so modules/*.o
	-make -C test clean
	rm -f test/*.so* test/*.o test/Makefile 
	rm -f test/out/*.out

distclean: clean
	rm -f	interp libqttest.so
	-make -C test distclean

test/Makefile: test/test.pro check-env
	$(QMAKE) $< -o $@

libqttest.so: $(SOURCES) test/Makefile
	make -C test
	ln -sf test/libqttest.so.1.0.0 libqttest.so

test: run_tests.sh
	./run_tests.sh

run_tests.sh: interp libqttest.so test/testbase.lua modules/libxml.so \
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
