# Shell Fuzer

CC:Tweaked mining-turtle program for Create Big Cannons. It puts fuzes in shells automatically.

Shells have no inventory that CC can access, but a vanilla hopper can insert a fuze into a placed shell. The turtle places a shell, the hopper drops a fuze in, and the turtle breaks the shell back into an item. Breaking the shell keeps the fuze.

## Layout

```
        [hopper]  <- fill with impact fuzes, pointing DOWN into the shell
[barrel] above the turtle (unfuzed shells)
[turtle] -> [shell spot]
[chest]  below the turtle (fuzed shells)
```

- Barrel **above** the turtle, output **below** it (swap with `INPUT_SIDE` / `OUTPUT_SIDE`)
- The block in front of the turtle must be empty. A hopper sits above it, pointing down
- Use a **mining** turtle (pickaxe). It needs no fuel

## Install

```
wget https://raw.githubusercontent.com/levisnakes/cc-shell-fuzer/main/shell_fuzer.lua startup.lua
```

About 1.3 s per shell. A shell that comes back without a fuze gets retried. After 3 misses in a row, the screen says the hopper is empty.
