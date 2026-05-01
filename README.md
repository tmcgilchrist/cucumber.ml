# Cucumber.ml

This implements the core Cucumber feature file language, Gherkin, and
associated library for specifying the execution of those scenarios for
the OCaml programming language.

**Features:**
- **Pure OCaml Gherkin parser**
- **C Gherkin parser**
- **Pluggable parser architecture** - use pure OCaml or bring your own parser
- OCaml 5.x effect handlers for ergonomic step definitions
- PPX support for automatic step registration
- Seamless async runtime integration (Eio, Lwt) via effect composition
- Three API styles: Classic, PPX Attributes, and PPX + Effects

## Documentation

- [Effect Handlers and Async Integration](docs/effects-and-async.md) - Comprehensive guide to using OCaml 5.x effects with Cucumber.ml and async runtimes
- [Parser Architecture](doc/parser.md) - Understanding the pluggable parser system
- [Examples](examples/) - Working examples demonstrating different API styles


## Building

This project uses [Dune](https://github.com/ocaml/dune) as its build
system.  To build the Cucumber library run:

```bash
dune build
```