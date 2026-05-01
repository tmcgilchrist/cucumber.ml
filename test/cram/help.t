Test the --help=plain output contains expected sections and flags

  $ camels --help=plain
  NAME
         cucumber - Cucumber BDD test runner for OCaml
  
  SYNOPSIS
         cucumber [OPTION]… [FILE]…
  
  DESCRIPTION
         Cucumber.ml is a Behavior-Driven Development (BDD) test runner for
         OCaml. It executes feature files written in the Gherkin language.
  
  FILTERING OPTIONS
         Control which scenarios are executed:
  
         -n, --name=REGEX
             Filter scenarios by name using a regular expression
  
         -t, --tags=TAGEXPR
             Filter scenarios using tag expressions (@tag to include, ~@tag to
             exclude)
  
         -i, --input=GLOB
             Glob pattern for feature files (default: *.feature)
  
  EXECUTION OPTIONS
         Control how scenarios are executed:
  
         -c, --concurrency=INT
             Number of concurrent scenarios (default: 1)
  
         --fail-fast
             Stop running tests after first failure
  
         --retry=INT
             Number of retry attempts for failed scenarios
  
         --retry-after=DURATION
             Delay between retry attempts (e.g., '10s', '1m')
  
         --retry-tag-filter=TAGEXPR
             Filter which scenarios get retried using tag expressions
  
  OUTPUT OPTIONS
         Control output formatting and verbosity:
  
         -v, --verbose
             Increase verbosity (can be repeated: -v, -vv, -vvv)
  
         --color=WHEN
             Console output color policy: auto, always, or never (default:
             auto)
  
  ARGUMENTS
         FILE
             Feature files or glob patterns to run
  
  OPTIONS
         -c INT, --concurrency=INT (absent=1)
             Number of concurrent scenarios (default: 1)
  
         --color=WHEN (absent=auto)
             Console output color policy: auto, always, or never (default:
             auto)
  
         --fail-fast
             Stop running tests after first failure
  
         -i GLOB, --input=GLOB (absent=*.feature)
             Glob pattern for feature files (default: *.feature)
  
         -n REGEX, --name=REGEX
             Filter scenarios by name using regex
  
         --retry=INT (absent=0)
             Number of retry attempts for failed scenarios
  
         --retry-after=DURATION
             Delay between retry attempts (e.g., '10s', '1m')
  
         --retry-tag-filter=TAGEXPR
             Filter which scenarios get retried using tag expressions
  
         -t TAGEXPR, --tags=TAGEXPR
             Filter scenarios using tag expressions. Use @tag to include and
             ~@tag to exclude. Multiple tags can be separated by spaces.
  
         -v, --verbose
             Increase verbosity (can be repeated: -v, -vv, -vvv)
  
  COMMON OPTIONS
         --help[=FMT] (default=auto)
             Show this help in format FMT. The value FMT must be one of auto,
             pager, groff or plain. With auto, the format is pager or plain
             whenever the TERM env var is dumb or undefined.
  
         --version
             Show version information.
  
  EXIT STATUS
         cucumber exits with:
  
         0   on success.
  
         123 on indiscriminate errors reported on standard error.
  
         124 on command line parsing errors.
  
         125 on unexpected internal errors (bugs).
  
  BUGS
         Report bugs at https://github.com/cucumber/cucumber.ml/issues
  
