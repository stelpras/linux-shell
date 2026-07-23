# mysh — A Simple Linux Shell in C++

A custom Unix shell implemented in C++ that supports command execution, I/O redirection, background processes, signal handling, command history, aliases, wildcard expansion, and environment variable substitution — built directly on top of POSIX system calls (`fork`, `execvp`, `dup2`, `kill`, `glob`).

## Features

- **Command execution** — every command is run in a child process via `execvp`, following the standard `fork`/`exec` model.
- **I/O redirection** — `>`, `>>`, `<`, `<<` are implemented using `open` and `dup2` to redirect file descriptors before the command runs.
- **Background processes** — appending `&` (with a preceding space) to a command runs it without blocking the shell, e.g. `./count1 &`.
- **Signal handling** — `Ctrl+C` (`SIGINT`) is caught by the parent and forwarded to the running child process via `kill`; the parent restores default signal behavior once the child exits.
- **Command history** — the last 20 commands are stored in a fixed-size buffer.
  - `history` — lists the last 20 commands
  - `history <n>` — re-executes command number `n` (indexing starts at 0)
- **Aliases** — backed by a `std::map<string, string>`.
  - `createalias <name> "<command>"` — defines an alias
  - `destroyalias <name>` — removes an alias
- **Wildcard expansion** — `*` and `?` patterns are expanded using the POSIX `glob.h` header.
- **Environment variable substitution** — tokens in the form `${VAR}` are replaced with their environment value before execution.
- **Built-in commands** — `cd`, `exit`, `history`, alias management.
- **Multiple commands per line** — commands separated by `;` are parsed and executed sequentially.

## Build & Run

```bash
make        # builds the mysh executable
./mysh      # run the shell
```

or in one step:

```bash
make run
```

To clean build artifacts:

```bash
make clean
```

## Implementation Notes

- **Execution model**: input lines are split on `;`, then on whitespace, to produce a token list. Each token list is checked against built-ins (`cd`, `history`, alias commands, `exit`) before falling back to `execvp` in a forked child.
- **Redirection**: before `execvp` is called in the child, `handleInputRedirection` / `handleOutputRedirection` scan the token list for `<`, `<<`, `>`, `>>`, open the target file with the appropriate flags (`O_TRUNC` vs `O_APPEND` for `>` vs `>>`), and `dup2` the resulting descriptor onto `stdin`/`stdout`.
- **Signals**: the parent stores the active child's PID; on `SIGINT` it forwards the signal to that PID via `kill`. Once the child is reaped, the parent resets its signal handler to `SIG_DFL`.
- **Background jobs**: if the last token before the line terminator is `&`, the shell skips `waitpid` and returns control to the prompt immediately.
- **Wildcards**: each token is passed through `glob()`; if it contains no `*`/`?`, it's passed through unchanged, otherwise it's expanded to the matching filenames.
- **History buffer**: a `std::array<std::string, 20>` with a wraparound index — the 21st command overwrites the first.

## Known Limitations

- **Pipes (`|`) are not implemented.**
- **`Ctrl+Z` (`SIGTSTP`)** is not handled — process suspension is not supported. `Ctrl+C` (`SIGINT`) works and is forwarded to the foreground child.

## Requirements

- Linux (uses POSIX APIs: `fork`, `execvp`, `dup2`, `kill`, `glob`, `chdir`)
- `g++` with C++14 support
