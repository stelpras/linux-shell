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
