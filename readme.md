## making a new git repository

First, `cd` into a new directory and initialize the repository:
```
git init
```

The Mirage toolchain generates a lot of files automatically as part of the build process. Since those are site-specific, you do not need or want to share them with others. We can make git ignore them by adding them to the `.gitignore` file:

```bash
cat >.gitignore <<EOF
*.swp
Makefile
_build/
key_gen.ml
log
main.ml
*.xe
*.xl
*.xl.in
*.xml
EOF
```


## introduction
The `mirage-skeleton` repository contained an intimidating amount of repositories.
This repository is an attempt to simplify the process of getting started with Mirage.

The parts we will need to get our first unikernel running are:
- `mirage`: the command-line tool used to generate the require build code and configuration files (think of it like `make`)
  - `mirage configure`: takes switches like `--unix` or `--xen` to specify the *target* of the build.
  - `mirage clean`: deletes generated files (like `make clean`)
- `config.ml`: the `mirage` tool will look for this specially named file in the current directory.

To find the definitions of Mirage types, look into the `~/.opam/*/lib/mirage/` directory.

The Mirage ecosystem makes use of the [functoria](https://mirage.github.io/functoria/Functoria.html) domain-specific language for piecing things together, so if you encounter alien syntax, the documentation for that might serve as a helpful utility. For example, [the documentation for the @-> syntax](https://mirage.github.io/functoria/Functoria.html#VAL%28@-%).

## Job module structure

The compiled unikernel can run a set of "jobs" in parallel using the Lwt lightweight thread module (a library for cooperative concurrency, like Python's "green threads").

Mirage uses OCaml's type system to be able to accomodate parametric compilation (that is, support different backends). Specifically, you need to be familiar with OCaml's "modules" and the concept of "functors".

Each of the unikernel jobs may depend on various Mirage components like the console to provide console input/output (`Mirage_console`), or the read-only key-value store (elegantly named `V1_LWT.KV_RO` **TODO this has been changed in v3**).

To make use of these components in your job, your module needs to be "parameterized over them" - that is, you need to implement the job module as a functor to use these components.

Additionally, each job needs to implement a `start` function which returns an Lwt handle (for more information, find a tutorial on concurrency in OCaml using Lwt TODO).

## Noop.ml: Implementing a no-op job

Example of the type definition of a job module for a Mirage:
```ocaml
module type Job_t =
sig
  val start : unit Lwt.t
end
```

A very basic implementation of a no-op job (`noop.ml`):
```ocaml
module Job =
struct
  val start = Lwt.return_unit
end
```

A `config.ml` for the no-op job:
```ocaml
open Mirage

let my_noop_job =
  foreign "Noop.Job" (Mirage.job)
  (* https://mirage.github.io/functoria/Functoria.html#VALjob *)

let () =
  (* Mirage.register takes a string (the name of your unikernel) and a list of jobs to run concurrently *)
  Mirage.register "mything"
  [ my_noop_job ]
```

Compiling the no-op unikernel:

```bash
mirage configure && make
```

Running the no-op unikernel:

```bash
./mir-mything
```

## Hello_world.ml: Providing output: Hello, World!

Now that we can compile a unikernel, we would like to extend it to print "Hello, World!" to the console. In order to do that we need to make a job that uses the Mirage "console" component.

We make another module to contain this job (`hello_world.ml`):
```ocaml
module type Job_t =
(* note that providing a signature / module type like this is entirely optional *)
functor (Console : Mirage_console.S) ->
sig
  val start : Console.t -> unit Console.io Lwt.t
end

module Job : Job_t =
functor (Console : Mirage_console.S) ->
struct
  let start (my_console : Console.t) =
    Lwt.return (Console.log my_console "Hello, World!")
end   
```

And we need to change `config.ml` to include our job:
```ocaml
open Mirage

let my_noop_job =
  foreign "Noop.Job" (Mirage.job)
  (* https://mirage.github.io/functoria/Functoria.html#VALjob *)

let hello_world =
  foreign "Hello_world.Job" (Mirage.console @-> Mirage.job)
  (* "@->" is Functoria syntax: https://mirage.github.io/functoria/Functoria.html#VAL%28@-%3E%29 *)
  (* Mirage.console: https://mirage.github.io/mirage/Mirage.html#VALconsole *)

let () =
  (* Mirage.register takes a string (the name of your unikernel) and a list of jobs to run concurrently *)
  Mirage.register "mything"
  [ my_noop_job
  ; hello_world $ Mirage.default_console
  (* dollar sign: https://mirage.github.io/functoria/Functoria.html#VAL%28$%29 *)
  ]
```

Example run:
```
root@localhost:~/ocaml/mirage-examples# mirage configure && make
ocamlbuild -use-ocamlfind -pkgs functoria.runtime,mirage-console.unix,mirage-types.lwt,mirage-unix,mirage.runtime -tags "warn(A-4-41-44),debug,bin_annot,strict_sequence,principal,safe_string" -tag-line "<static*.*>: warn(-32-34)" -cflag -g -lflags -g,-linkpkg main.native
Finished, 13 targets (0 cached) in 00:00:00.
ln -nfs _build/main.native mir-mything
root@localhost:~/ocaml/mirage-examples# ./mir-mything 
Hello, World!
root@localhost:~/ocaml/mirage-examples# 
```

## Hello_xyz.ml: Customizing the unikernel with command-line options

Mirage can take command-line options using "keys" (see the [Mirage_key module](https://mirage.github.io/mirage/Mirage_key.html)).

The keys can be specified both at build-time and (when compiling for the `--unix` target) at run-time, using `mirage configure --my-key` at build-time, or invoking it with `./mir-mything --my-key` at run-time.

The keys are registered with Mirage using `Key.create` in `config.ml` and are accessible as a function `Key_gen.<name> : unit -> string` from the job modules (a file called `key_gen.ml` containing the code to enable this is generated by `mirage configure`).

The hello_xyz job looks like this:
```ocaml
module type Job_t =
functor (Console : Mirage_console.S) ->
sig
  val start : Console.t -> unit Console.io Lwt.t
end

module Job : Job_t =
functor (Console : Mirage_console.S) ->
struct
  let start (my_console : Console.t) =
    Lwt.return @@
    Console.log my_console
      ("Hello, " ^ Key_gen.(my_name () ) ^ "!" )
end
```

We need to make some modifications to the `config.ml`, and `mirage configure` used to allows us to have multiple config files in the same directory by using the `-f` switch, but now someone decided it would be a great idea to remove that, so to avoid cluttering the old examples, we create a new directory `hello_xyz` and a `hello_xyz/config.ml`:

```ocaml
open Mirage

let my_hello_xyz =
  let key =
    let doc = Mirage.Key.Arg.info
      ~doc:"Specify a name for the hello_world_xyz job"
      ["name"]
    in
    Mirage.Key.(create "my_name" Arg.(opt string "John Doe" doc) )
  in
  Mirage.foreign
    ~keys:[Mirage.Key.abstract key]
      (* https://mirage.github.io/functoria/Functoria_key.html#VALabstract *)
    "Hello_xyz.Job"
    (Mirage.console @-> Mirage.job)

let () =
  Mirage.register
    "hello_xyz"
    [ my_hello_xyz $ Mirage.default_console
    ]
```

Finally we can compile:

```
cd hello_xyz/
mirage configure
make
```

Running it looks like:
```
root@localhost:~/ocaml/mirage-examples/hello_xyz# ./mir-hello_xyz
Hello, John Doe!
root@localhost:~/ocaml/mirage-example/hello_xyzs# ./mir-hello_xyz --name Jane
Hello, Jane!
```

(* TODO nice example code at https://github.com/Engil/Canopy/blob/master/config.ml#L62 *)

(* TODO section on implement an argument converter: https://mirage.github.io/mirage/Mirage_key.Arg.html
  https://mirage.github.io/mirage/Mirage_runtime.Arg.html
*)

(* TODO Unfortunately I have to venture AFK now, but I hope to continue this log of my adventures with Mirage.
*)

