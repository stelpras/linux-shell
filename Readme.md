Simple linux shell (mysh)

Compile:
make

Run: 
./mysh

Compile and run:
make run

Shell functionality:

Pipes are not working.
Signals:
control-Z is not working. Control-c works(It will transfer the signal to the chid process) 

General Shell functionality:

Each command that is given will be eventually be executed by the execvp function(https://linux.die.net/man/3/execvp).
This function is always called by a child process, by using the fork command.

Line processing:

Split the line by using the delim ;
Split again by using the delim " " (Space)
Check if the command is an allias/cd/history/exit/clear/etc....
If it is none of the above then it executed by the execvp as described above.

Redirections: 
All redirections are working > >> < <<. Also working with the provided examples

They are created by using the linux functions open(https://man7.org/linux/man-pages/man2/open.2.html) and dup2(https://man7.org/linux/man-pages/man2/dup.2.html).
Based if we have output or input redirection we create a file descriptor and then we duplicate/copy that descriptor to the stdout/in.

Signals:
When we fork the child process we have its ID.
So when the parent process receives the SIGINT(control-c) it will forward it to the child process using the linux kill function(https://man7.org/linux/man-pages/man1/kill.1.html).
Of course when the parent process terminates(either waits for child or not), it restore the signal behavior to its default.

Background process:
Background process are working with the examples you provided.
As we said above everything is executed by a child process.
When we have a background process, then the parent process does not wait for the child to finish and the terminal is returned to the user.
Keep in my mind & must has a space after the executable. For example ./count1 &;

Wildcards:
Wildcards are working with the tests you provided.
They are implemented by using the linux header, glob.h

History:
History is working with the tests you provided.
Internally it is implemented by using an array of 20 positions.

history -> It shows the last 20 commands
history + number -> Executes the (number) command 
History count starts with 0

Allias:
Alias are working correctly with the tests u provided.
Internally is implented using a map.
Key is the actual alias and value is the command of the alias.

Custom commands:

exit -> closes the shell
cd .. -> cd to the directory using the chdir function(https://man7.org/linux/man-pages/man2/chdir.2.html).

Enviromental variables:
My shell can search for enviromental variables when they start like this (${....}) and will replace them with their value.

(I kept some cout just for debug reasons)

