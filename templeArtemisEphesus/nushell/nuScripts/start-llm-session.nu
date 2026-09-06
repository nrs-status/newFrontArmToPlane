# Bootstrap a new LLM session repo at the given path and launch pi
#
# Nushell analog of the fish `start-llm-session` script.

# Usage: start-llm-session <path>
def start-llm-session [
    session_dir: string  # path at which to bootstrap the new LLM session repo
] {
    sesh mkdir $session_dir -c (
        "git init && wt switch -c run0 && nvim instructions.txt && git add instructions.txt && git commit -m instructions && pi 'Read and execute instructions.txt'"
    )
}
