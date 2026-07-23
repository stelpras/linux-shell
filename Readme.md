System Programming

Stylianos Prasianakis

# mysh — A Simple Linux Shell in C++

This is a Unix shell I built in C++ from scratch, sitting directly on top of POSIX system calls like fork, execvp, dup2, kill and glob. It runs commands, handles input/output redirection, supports background processes, catches signals, keeps a command history, lets you define aliases, expands wildcards, and substitutes environment variables.

## What it can do

Every command you type eventually gets run through execvp inside a forked child process, which is the standard fork/exec model most shells use under the hood.

Redirection works for all four operators, `>`, `>>`, `<` and `<<`. These are implemented with open and dup2, redirecting file descriptors before the command actually runs.

You can run something in the background by adding `&` after it, as long as there's a space before it, like `./count1 &`. The shell won't wait for it to finish and gives you the prompt back right away.

Ctrl+C sends SIGINT, which the parent process catches and forwards to whichever child is currently running, using kill. Once the child exits, signal handling goes back to default.

The last 20 commands get stored in a history buffer. Typing `history` lists them, and `history <n>` re-runs whichever command is at that number — numbering starts at 0.

Aliases are backed by a map. `createalias <name> "<command>"` sets one up, and `destroyalias <name>` removes it.

Wildcards (`*` and `?`) get expanded using glob.h.

Environment variables written as `${VAR}` get replaced with their actual value before the command runs.

There are also a few built-ins: `cd`, `exit`, `history`, and the alias commands. And you can put more than one command on a line separated by `;`, they'll run one after another.

## Build and run

```
make
./mysh
```

Or do both at once:

```
make run
```

To clean up the build:

```
make clean
```

## How it's actually implemented

Each line typed in gets split first on `;`, then on whitespace, giving a list of tokens. That token list gets checked against the built-ins (cd, history, alias commands, exit) before falling back to execvp in a forked child if it's none of those.

Redirection is handled right before execvp gets called in the child. The functions handleInputRedirection and handleOutputRedirection scan the tokens for `<`, `<<`, `>` and `>>`, open the target file with the right flags (O_TRUNC for `>`, O_APPEND for `>>`), and dup2 the resulting file descriptor onto stdin or stdout.

For signals, the parent just keeps track of the active child's PID. When SIGINT comes in, it gets forwarded to that PID with kill. Once the child has been reaped, the parent resets its signal handler back to SIG_DFL.

Background jobs are detected by checking if the last token before the line ends is `&`. If so, the shell skips waitpid entirely and just returns control to the prompt.

Wildcard expansion runs every token through glob(). If there's no `*` or `?` in it, it just passes through unchanged, otherwise it gets expanded into the matching filenames.

History is just a fixed-size array of 20 strings with a wraparound index, so the 21st command overwrites the first one.

## What doesn't work yet

Pipes aren't implemented at all.

Ctrl+Z, which sends SIGTSTP, isn't handled either, so there's no process suspension. Ctrl+C does work though, and gets forwarded properly to whatever's running in the foreground.

## Requirements

Needs Linux, since it relies on POSIX APIs (fork, execvp, dup2, kill, glob, chdir), and g++ with C++14 support.

## Testing

There's a test script, test_mysh.sh, that builds the shell and feeds it a sequence of commands through stdin, the same way you'd type them at the prompt, then checks the output against what it should be. It also checks the actual files the shell should have created or modified on disk, not just what got printed. Run it with:

```
chmod +x test_mysh.sh
./test_mysh.sh
```

It runs from inside the project folder and creates its own subfolder to work in, so it won't touch anything else you have lying around.

Signal handling is the one thing it doesn't cover automatically, since piping commands through stdin isn't really the same as pressing Ctrl+C in an interactive terminal, and I'd rather not fake it. If you want to check that part yourself, run `sleep 30` inside mysh and press Ctrl+C, it should kill the sleep and give you the prompt back right away.

### The test scenario, worked by hand

I ran this whole sequence against the actual compiled shell to make sure the outputs below are correct and not just what I assumed would happen. Along the way I ran into an actual bug in the history feature, which is documented at the end of this section.

Before starting the shell, an environment variable is set so there's something to substitute later:

```
export NAME=World
```

Then, once mysh is running:

`cd sub` moves into a subfolder, and `cd ..` moves back out. Nothing gets printed either way, but the prompt itself changes to reflect the current directory.

`echo Hello ${NAME}` gets substituted before it runs, so what actually executes is `echo Hello World`, and it prints `Hello World`.

`echo line1 > file1.txt` doesn't print anything, it just creates file1.txt containing `line1`. Running `cat file1.txt` afterwards confirms that by printing `line1`.

`echo line2 >> file1.txt` appends instead of overwriting, so file1.txt now has both lines, and `cat file1.txt` prints `line1` followed by `line2`.

`wc -l < file1.txt` reads the file as input instead of taking a filename argument, and prints `2`, since there are two lines in it.

After creating three files with `touch alpha.txt beta.txt gamma.txt`, running `echo *.txt` expands the wildcard and prints `alpha.txt beta.txt file1.txt gamma.txt` — file1.txt shows up too since it also matches `*.txt`, and glob returns everything in alphabetical order.

`createalias hello "echo Hi from alias"` sets up an alias, and typing `hello` afterwards runs it, printing `Hi from alias`. Once you run `destroyalias hello` and try `hello` again, it fails with `Error: command: hello not found.`, since it's back to being treated as a regular, nonexistent command.

`echo first ; echo second ; echo third` runs all three as separate commands on the same line, printing `first`, `second` and `third` on their own lines.

`sleep 2 &` runs in the background, so the very next command, `echo done-after-bg`, prints immediately instead of waiting two seconds for the sleep to finish.

At this point, running `history` lists every command typed so far, numbered starting from 0.

Running `history 2` re-executes whatever command was stored at index 2, which in this sequence was `echo Hello ${NAME}`, so it prints `Hello World` again.

### A quirk `history <n>` has

Re-running a history entry that contains an environment variable actually corrupts that entry afterwards. The code substitutes the variable directly into the stored history string in place, and then tokenizes that same string with strtok, which replaces the spaces with null characters rather than leaving them alone. So after running `history 2` above, if you dump the history again, index 2 no longer reads as `echo Hello ${NAME}` — the spaces have been silently replaced with null bytes, which usually just shows up as the words running together or as odd invisible characters depending on your terminal. It still works the first time you re-run it, the corruption only shows up afterwards if you look at the history again or try to re-run that same entry a second time.

This isn't something the test script tries to work around, it's left as-is since the point of the test is to show what the shell actually does, not to paper over it.
