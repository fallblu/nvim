# One multi-file program: every .cpp in this directory, linked into `main`.
# Copy into an exercise directory, never the top of a repository of
# single-file exercises: the nearest Makefile above a file decides its build.
CXX = g++
CXXFLAGS = -std=c++23 -Wall -Wextra -Wconversion -Wsign-conversion -Wshadow -pedantic-errors -g -O0
# Record each object's headers so editing a header rebuilds what includes it.
CPPFLAGS = -MMD -MP
SANITIZE ?= 1
ifeq ($(SANITIZE),1)
CXXFLAGS += -fsanitize=address,undefined
endif
objects := $(patsubst %.cpp,%.o,$(wildcard *.cpp))

main: $(objects)
	$(CXX) $(CXXFLAGS) -o $@ $^

-include $(objects:.o=.d)

clean:
	rm -f main main.valgrind $(objects) $(objects:.o=.d)

.PHONY: clean
