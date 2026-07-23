OBJS = HelperFunctions.o Redirection.o main.o
SOURCE = HelperFunctions.cpp Redirection.cpp main.cpp 
HEADER = HelperFunctions.hpp Redirection.hpp History.hpp Alias.hpp
OUT = mysh
CC = g++ 
FLAGS = -g -O0 -std=c++14

run: $(OUT)
	./$(OUT)

$(OUT): $(OBJS)
	$(CC) -g $(OBJS) -o $@


main.o: main.cpp
	$(CC) $(FLAGS) -c main.cpp


HelperFunctions.o: HelperFunctions.cpp
	$(CC) $(FLAGS) -c HelperFunctions.cpp

Redirection.o: Redirection.cpp
	$(CC) $(FLAGS) -c Redirection.cpp



# clean house
clean:
	rm -f $(OBJS) $(OUT)
	rm -f build.log commands.txt test_mysh_run.log
	rm -rf mysh_test_dir